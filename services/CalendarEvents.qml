pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// ICS event feeds. Reads ~/.config/quickshell/calendar.json
// ({"feeds": [{"url": "https://…", "color": "#rrggbb"}, …]}),
// fetches each feed with curl via Process (one per feed, in parallel),
// parses the RFC 5545 subset those feeds need, and answers day queries.
//
// Recurrences are expanded lazily: only the months a view actually asks
// for are materialized into the day index, so a big calendar costs one
// month of work instead of two years of work per refresh.
//
// A failed fetch keeps the slot's previous text — stale beats empty.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/calendar.json"
    property var feeds: []
    readonly property bool feedsConfigured: feeds.length > 0
    property int refreshMinutes: 15
    property double lastRefresh: 0

    // Feed slots that could not be read on the last wave, so the dashboard
    // can say so instead of silently showing stale data.
    property var fetchFailures: []

    // "y-m-d" (local date) -> occurrences, sorted all-day first then by start.
    // Arrays are stored sorted and handed out by reference so a view binding
    // on them is not invalidated by a bare refresh.
    property var dayMap: ({})

    // Bases with an RRULE plus the overrides belonging to them.
    property var _series: []
    // "y-m" months already expanded into dayMap.
    property var _months: ({})

    // Last good text per feed slot; kept until a fetch succeeds again.
    property var _texts: []

    // Bumped per fetch wave so a completion from a killed wave is dropped.
    property int _generation: 0
    property string _configSig: ""
    property double _waveAt: 0
    // Fingerprint of the feed text the current index was built from, so a
    // refresh that lands identical bytes does not disturb the day arrays.
    property string _indexSig: ""

    FileView {
        id: configFile
        path: root.configPath

        // The `loaded` signal fires on every successful load — the
        // `loaded` *property* stays true across path swaps, so an
        // onLoadedChanged handler would never re-fire.
        onLoaded: root.refresh()
    }

    // One curl Process per feed, all fetching in parallel. curl handles
    // http(s) and file:// natively (webcal:// is rewritten by _fetchUrl),
    // and its hard timeouts keep a blackholed route from hanging forever
    // the way an XHR connect could.
    Instantiator {
        id: feedFetcher
        model: root.feeds

        delegate: Process {
            id: feedProc
            required property int index
            required property var modelData

            // Captured before the process starts; a completion whose
            // generation no longer matches belongs to a wave we replaced.
            property int _gen: root._generation
            property int _code: -1
            property bool _ended: false
            property bool _textDone: false
            // Set once this delegate has reported either way, so a late
            // signal cannot report twice.
            property bool _settled: false

            command: ["curl", "-fsSL", "--connect-timeout", "5", "--max-time", "15", "--retry", "2", "--", root._fetchUrl(modelData.url)]
            running: true

            // exited and streamFinished can arrive in either order; only
            // report once both landed so the exit code and the full stdout
            // are known together.
            function _finish() {
                if (_ended && _textDone && !_settled) {
                    _settled = true;
                    if (_code === 0)
                        root._complete(index, feedOut.text, _gen);
                    else
                        root._fail(index, "curl exited " + _code + ": " + feedErr.text.trim(), _gen);
                }
            }

            onExited: (exitCode) => {
                _code = exitCode;
                _ended = true;
                _finish();
            }

            stdout: StdioCollector {
                id: feedOut
                onStreamFinished: {
                    feedProc._textDone = true;
                    feedProc._finish();
                }
            }

            stderr: StdioCollector {
                id: feedErr
            }
        }
    }

    Timer {
        interval: root.refreshMinutes * 60 * 1000
        repeat: true
        running: root.feeds.length > 0
        onTriggered: root.refresh()
    }

    // Backstop for a fetch that never reports. Process emits no `exited` when
    // the binary is missing, and a broken pipe can leave streamFinished
    // unfired, so without this a dead feed would be indistinguishable from a
    // slow one. curl is capped well below the grace period.
    Timer {
        interval: 10000
        repeat: true
        running: root.feeds.length > 0
        onTriggered: root._sweep()
    }

    // -------------------------------------------------------------------
    // Config
    // -------------------------------------------------------------------

    // Re-reads calendar.json and applies it only when the feed list actually
    // changed. Returns true when `feeds` was replaced, which means the
    // Instantiator has already built this wave's delegates.
    function _applyConfig() {
        let list = [];
        try {
            const content = configFile.text();
            if (content && content.trim().length > 0) {
                const cfg = JSON.parse(content);
                // Accepts {"feeds": [url, …]} (legacy) and
                // {"feeds": [{"url": …, "color": …}, …]}.
                list = (cfg.feeds || []).map(function (f) {
                    if (typeof f === "string")
                        return { url: f, color: "" };
                    return {
                        url: (f && f.url) || "",
                        color: root._normColor(f && f.color)
                    };
                }).filter(function (f) {
                    return f.url.length > 0;
                });
            }
        } catch (e) {
            console.warn("CalendarEvents: invalid calendar.json:", e);
        }

        const sig = JSON.stringify(list);
        if (sig === _configSig)
            return false;

        _configSig = sig;
        // Bumped before `feeds` so the delegates created by the model change
        // already belong to the new generation.
        _generation++;
        _waveAt = Date.now();
        feeds = list;
        // A different feed list invalidates every slot, so events from a
        // removed or edited feed cannot linger.
        _texts = new Array(feeds.length).fill(null);
        return true;
    }

    // Validates a user-supplied color (hex or CSS3 name); invalid input
    // comes back as an invalid fully-transparent color from Qt.color().
    function _normColor(v) {
        if (typeof v !== "string" || v.trim().length === 0)
            return "";
        try {
            if (Qt.color(v.trim()).a === 0)
                return "";
            return v.trim();
        } catch (e) {
            return "";
        }
    }

    function refresh() {
        lastRefresh = Date.now();
        fetchFailures = [];

        // Re-read the config on every cycle so an edited URL is picked up
        // without a restart. FileView does not watch the file, so this poll
        // is the only thing that notices.
        if (_applyConfig()) {
            // Assigning `feeds` built fresh delegates with the new command
            // bindings; leave them running instead of waving twice.
            _invalidate();
            return;
        }

        if (feeds.length === 0) {
            _invalidate();
            return;
        }

        // Same feeds: tearing the delegates down and letting them recreate
        // starts a fresh curl per slot. `_texts` is left alone, so each slot
        // keeps serving its previous text until its own fetch lands.
        _generation++;
        _waveAt = Date.now();
        feedFetcher.active = false;
        feedFetcher.active = true;
    }

    // Cheap hook for dashboard-open: skip if fetched within the last 5 min.
    function refreshIfStale() {
        if (!feedsConfigured)
            return;
        if (Date.now() - lastRefresh > 5 * 60 * 1000)
            refresh();
    }

    function _complete(idx, text, gen) {
        if (gen !== _generation)
            return;
        _texts[idx] = text;
        fetchFailures = fetchFailures.filter(function (i) {
            return i !== idx;
        });
        _rebuild(_texts);
    }

    function _fail(idx, why, gen) {
        if (gen !== _generation)
            return;
        if (fetchFailures.indexOf(idx) < 0) {
            fetchFailures = fetchFailures.concat([idx]);
            console.warn("CalendarEvents: feed " + idx + " failed:", why);
        }
    }

    // Flags any slot that is still empty well after its wave started.
    function _sweep() {
        if (Date.now() - _waveAt < 40000)
            return;
        for (let i = 0; i < feeds.length; i++) {
            if (!_texts[i])
                _fail(i, "no response within 40s", _generation);
        }
    }

    // curl rejects the webcal scheme outright; file:// URLs pass through
    // with percent-encoding decoded to a literal path.
    function _fetchUrl(url) {
        if (url.startsWith("webcal://"))
            return "https://" + url.slice(8);
        if (url.startsWith("file://")) {
            try {
                return decodeURIComponent(url);
            } catch (e) {
                console.warn("CalendarEvents: bad file URL", url);
                return url;
            }
        }
        return url;
    }

    function _invalidate() {
        _series = [];
        _months = ({});
        _indexSig = "";
        dayMap = ({});
    }

    // Event time in the user's locale. QLocale's own short time format is
    // used so the AM/PM designator (or its absence) follows the locale
    // instead of being hardcoded; anything unexpected falls back to a
    // readable fixed format.
    function formatTime(ms) {
        const fmt = _timeFormat();
        return Qt.locale().toString(new Date(ms), fmt);
    }

    function _timeFormat() {
        const cached = _fmtTime;
        if (cached !== "")
            return cached;
        let f = "";
        try {
            f = Qt.locale().timeFormat(Locale.ShortFormat);
        } catch (e) {
            f = "";
        }
        _fmtTime = (typeof f === "string" && f.length > 0) ? f : "h:mm AP";
        return _fmtTime;
    }

    // -------------------------------------------------------------------
    // Queries
    // -------------------------------------------------------------------

    function hasEvents(date) {
        _ensureRange(date, date);
        const arr = dayMap[_key(date)];
        return !!arr && arr.length > 0;
    }

    // Returns the stored array itself: it is built sorted and never mutated
    // afterwards, so a model binding on it survives unrelated refreshes.
    function eventsForDay(date) {
        _ensureRange(date, date);
        return dayMap[_key(date)] || [];
    }

    function ensureMonth(y, m) {
        _ensureRange(new Date(y, m, 1), new Date(y, m + 1, 1));
    }

    function _key(d) {
        const x = _asDate(d);
        return x.getFullYear() + "-" + x.getMonth() + "-" + x.getDate();
    }

    function _asDate(v) {
        return v instanceof Date ? v : new Date(v);
    }

    // What the bar chip shows: an ongoing timed event, then an ongoing
    // all-day one, then the rest of today, then the next week. Ongoing beats
    // upcoming so a week-old all-day event cannot push a meeting off the bar,
    // and every branch produces a label so the chip is never a bare dot.
    function nextEvent(now) {
        const base = _asDate(now);
        _ensureRange(base, new Date(base.getFullYear(), base.getMonth(), base.getDate() + 8));

        let ongoingTimed = null;
        let ongoingAllDay = null;
        let todayUpcoming = null;
        let soonUpcoming = null;

        for (let d = 0; d <= 7; d++) {
            const day = new Date(base.getFullYear(), base.getMonth(), base.getDate() + d);
            const arr = dayMap[_key(day)];
            if (!arr)
                continue;
            for (let i = 0; i < arr.length; i++) {
                const ev = arr[i];
                if (ev.start <= now && ev.end > now) {
                    if (ev.allDay) {
                        if (!ongoingAllDay || ev.start < ongoingAllDay.start)
                            ongoingAllDay = ev;
                    } else if (!ongoingTimed || ev.start < ongoingTimed.start) {
                        ongoingTimed = ev;
                    }
                } else if (ev.start > now) {
                    if (d === 0) {
                        if (!todayUpcoming || ev.start < todayUpcoming.start)
                            todayUpcoming = ev;
                    } else if (!soonUpcoming || ev.start < soonUpcoming.start) {
                        soonUpcoming = ev;
                    }
                }
            }
        }

        return ongoingTimed || ongoingAllDay || todayUpcoming || soonUpcoming || null;
    }

    // -------------------------------------------------------------------
    // Lazy expansion
    // -------------------------------------------------------------------

    function _cmpOcc(a, b) {
        if (a.allDay !== b.allDay)
            return a.allDay ? -1 : 1;
        if (a.start !== b.start)
            return a.start - b.start;
        return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0);
    }

    // Materializes one month (plus enough lookback to catch events that
    // started earlier and run into it) and merges it into dayMap.
    function _ensureMonth(y, m) {
        const key = y + "-" + m;
        if (_months[key])
            return false;
        _months[key] = true;

        const from = new Date(y, m, 1);
        const to = new Date(y, m + 1, 1);
        const fromMs = from.getTime();
        const toMs = to.getTime();
        const added = ({});

        for (let i = 0; i < _series.length; i++) {
            const s = _series[i];
            const ev = s.ev;
            // An occurrence that began before the month still shows on its
            // first days, so rewind by the event's own length.
            const rewind = Math.min(366, Math.ceil((ev.end - ev.start) / 86400000) + 1);
            const winFrom = fromMs - rewind * 86400000;

            const occs = _expand(ev, s.skip, winFrom, toMs);
            for (let j = 0; j < occs.length; j++)
                _addOcc(added, occs[j]);

            for (let j = 0; j < s.overrides.length; j++) {
                const ov = s.overrides[j];
                if (ov.start < toMs && ov.end > winFrom)
                    _addOcc(added, ov);
            }
        }

        _merge(added);
        return true;
    }

    function _ensureRange(from, to) {
        const a = _asDate(from);
        const b = _asDate(to);
        let y = a.getFullYear();
        let m = a.getMonth();
        const endY = b.getFullYear();
        const endM = b.getMonth();
        // A stale cache would grow forever as the user pages through months.
        if (_monthCount() > 240) {
            _months = ({});
            dayMap = ({});
        }
        let guard = 0;
        while ((y < endY || (y === endY && m <= endM)) && guard++ < 240) {
            _ensureMonth(y, m);
            m++;
            if (m > 11) {
                m = 0;
                y++;
            }
        }
    }

    function _monthCount() {
        let n = 0;
        for (const k in _months)
            n++;
        return n;
    }

    // One write to dayMap per expansion, so a view binding settles after a
    // single extra evaluation instead of one per day touched.
    function _merge(added) {
        let any = false;
        for (const k in added) {
            any = true;
            break;
        }
        if (!any)
            return;
        const next = ({});
        for (const k in dayMap)
            next[k] = dayMap[k];
        for (const k in added) {
            const prev = next[k];
            const cur = prev ? prev.slice() : [];
            // Adjacent months are expanded with a rewind so an event that
            // began earlier still shows, which means the same occurrence can
            // arrive twice. One instance per series per instant.
            const seen = Object.create(null);
            for (const e of cur)
                seen[e.uid + "|" + e.start] = true;
            for (const occ of added[k]) {
                const id = occ.uid + "|" + occ.start;
                if (!(id in seen)) {
                    seen[id] = true;
                    cur.push(occ);
                }
            }
            cur.sort(_cmpOcc);
            next[k] = cur;
        }
        dayMap = next;
    }

    // Places one occurrence on every local day it covers. All-day DTEND is
    // exclusive per RFC 5545, hence the -1.
    function _addOcc(index, occ) {
        const startD = new Date(occ.start);
        const endD = new Date(occ.end - 1);
        const cursor = new Date(startD.getFullYear(), startD.getMonth(), startD.getDate());
        const last = new Date(endD.getFullYear(), endD.getMonth(), endD.getDate());
        const maxSpan = occ.allDay ? 366 : 31;
        let guard = 0;
        while (cursor.getTime() <= last.getTime() && guard++ < maxSpan) {
            const k = cursor.getFullYear() + "-" + cursor.getMonth() + "-" + cursor.getDate();
            if (!(k in index))
                index[k] = [];
            index[k].push(occ);
            cursor.setDate(cursor.getDate() + 1);
        }
    }

    // -------------------------------------------------------------------
    // Index construction
    // -------------------------------------------------------------------

    function _rebuild(texts) {
        // Nothing to do if the feeds said exactly what they said last time;
        // rebuilding would hand every view fresh arrays for no reason.
        const sig = texts.join(" ");
        if (sig === _indexSig)
            return;
        _indexSig = sig;

        const parsed = [];
        for (let i = 0; i < texts.length; i++) {
            if (!texts[i])
                continue;
            const cal = _parseVEvents(texts[i]);
            const cfgColor = feeds[i] ? feeds[i].color : "";
            const calColor = _normColor(cal.color);
            for (let j = 0; j < cal.events.length; j++) {
                const ev = cal.events[j];
                // Precedence: config color > VEVENT COLOR > VCALENDAR COLOR.
                ev.color = cfgColor || ev.color || calColor;
                // A feed is free to omit UID; without a unique key every such
                // event would collapse onto the first one.
                if (!ev.uid)
                    ev.uid = "anonymous-" + parsed.length;
                parsed.push(ev);
            }
        }

        const bases = ({});
        const instances = [];
        for (let i = 0; i < parsed.length; i++) {
            const ev = parsed[i];
            if (ev.recurrenceId !== null) {
                instances.push(ev);
                continue;
            }
            // First base per UID wins (the same calendar in more than one feed).
            if (!(ev.uid in bases))
                bases[ev.uid] = { ev: ev, skip: [], overrides: [] };
        }

        // Instances need the base resolved first, and their RECURRENCE-ID is
        // the *original* slot: that is what the base expansion has to
        // suppress, since a reschedule moves DTSTART somewhere else.
        for (let i = 0; i < instances.length; i++) {
            const ev = instances[i];
            const s = bases[ev.uid];
            if (!s || !s.ev)
                continue;
            if (s.skip.indexOf(ev.recurrenceId) < 0)
                s.skip.push(ev.recurrenceId);
            if (ev.status === "CANCELLED")
                continue;
            if (s.overrides.some(function (o) { return o.recurrenceId === ev.recurrenceId; }))
                continue;
            // A partial instance is still the replacement for its slot.
            if (ev.title === "(untitled)")
                ev.title = s.ev.title;
            if (!ev.color)
                ev.color = s.ev.color;
            s.overrides.push(ev);
        }

        const series = [];
        for (const uid in bases) {
            // A cancelled base drops its whole series, instances included.
            if (bases[uid].ev && bases[uid].ev.status !== "CANCELLED")
                series.push(bases[uid]);
        }

        _series = series;
        _months = ({});
        dayMap = ({});
    }

    // -------------------------------------------------------------------
    // Recurrence expansion
    // -------------------------------------------------------------------

    function _occ(ev, startMs) {
        return {
            title: ev.title,
            allDay: ev.allDay,
            start: startMs,
            end: startMs + (ev.end - ev.start),
            uid: ev.uid,
            color: ev.color,
            tentative: ev.tentative
        };
    }

    // Occurrences of one event overlapping [from, to).
    // `skipTimes` are overridden or cancelled instances: they are still
    // counted so COUNT stays exact, they are just not emitted.
    function _expand(ev, skipTimes, from, to) {
        const out = [];
        if (!ev.rrule) {
            if (ev.start < to && ev.end > from && skipTimes.indexOf(ev.start) < 0)
                out.push(_occ(ev, ev.start));
            return out;
        }

        const rule = ev.rrule;
        const interval = Math.max(1, rule.INTERVAL || 1);
        const maxCount = rule.COUNT !== undefined ? rule.COUNT : null;
        const startD = new Date(ev.start);
        const utc = ev.utc === true;
        const tz = !utc && ev.tz ? ev.tz : "";
        // UTC and TZID events walk on a Date whose UTC fields hold the event's
        // own wall clock, so a DST change in that zone cannot slide the time
        // of day. Floating events keep using the host's local fields.
        const useUtc = utc || !!tz;
        const wall = tz ? _zonedParts(ev.start, tz) : null;

        const getY = d => useUtc ? d.getUTCFullYear() : d.getFullYear();
        const getM = d => useUtc ? d.getUTCMonth() : d.getMonth();
        const getD = d => useUtc ? d.getUTCDate() : d.getDate();
        const getDow = d => useUtc ? d.getUTCDay() : d.getDay();
        const getH = d => useUtc ? d.getUTCHours() : d.getHours();
        const getMin = d => useUtc ? d.getUTCMinutes() : d.getMinutes();
        const getS = d => useUtc ? d.getUTCSeconds() : d.getSeconds();

        // Preserve the original time of day while stepping the date.
        const h0 = wall ? wall.h : getH(startD);
        const m0 = wall ? wall.mi : getMin(startD);
        const s0 = wall ? wall.s : getS(startD);
        const dow0 = wall ? wall.dow : getDow(startD);
        const mk = (y, m, day) => useUtc
            ? new Date(Date.UTC(y, m, day, h0, m0, s0))
            : new Date(y, m, day, h0, m0, s0);
        const addDays = (d, n) => mk(getY(d), getM(d), getD(d) + n);
        // Walking happens in wall-clock terms; only the emitted instant is
        // resolved through the event's zone.
        const toMs = d => tz
            ? _zonedMs(getY(d), getM(d), getD(d), getH(d), getMin(d), getS(d), tz)
            : d.getTime();

        // The window is half-open and UNTIL is inclusive, so the two bounds
        // cannot share one comparison.
        const until = rule.UNTIL !== undefined ? rule.UNTIL : Infinity;
        const exset = ({});
        for (let i = 0; i < ev.exdates.length; i++)
            exset[ev.exdates[i]] = true;

        // A COUNT-limited rule is walked from DTSTART so the count stays
        // exact; an open-ended one seeks to the window instead. Every seek
        // lands one step early — a DST shift can put the estimate a step
        // late — and push() drops whatever falls before the window.
        const counted = maxCount !== null;
        const budget = counted ? maxCount + 8 : 4000;
        let generated = 0;
        let stop = false;

        const push = function (d) {
            if (stop)
                return;
            const ms = toMs(d);
            if (ms > until || ms >= to) {
                stop = true;
                return;
            }
            if (ms < ev.start)
                return;
            generated++;
            if (maxCount !== null && generated > maxCount) {
                stop = true;
                return;
            }
            if (ms < from)
                return;
            if (skipTimes.indexOf(ms) >= 0)
                return;
            if (ms in exset)
                return;
            out.push(_occ(ev, ms));
        };

        const dowMap = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
        const byday = (rule.BYDAY || []).map(s => ({ ord: parseInt(s, 10) || null, dow: dowMap[s.replace(/^[+-]?\d+/, "")] }));
        const bymonthday = rule.BYMONTHDAY || [];

        if (rule.FREQ === "DAILY") {
            let cur = startD;
            let it = 0;
            if (!counted && from > startD.getTime()) {
                const steps = Math.floor((from - startD.getTime()) / (interval * 86400000)) - 1;
                cur = addDays(startD, Math.max(0, steps) * interval);
            }
            while (!stop && it++ < budget) {
                push(cur);
                cur = addDays(cur, interval);
            }
        } else if (rule.FREQ === "WEEKLY") {
            const wkst = rule.WKST !== undefined ? rule.WKST : 1;
            const targetDows = byday.length > 0 ? byday.map(b => b.dow) : [dow0];
            const offToWkst = d => (getDow(d) - wkst + 7) % 7;
            // Anchor the interval stepping to the start date's own week so
            // BYDAY days earlier in that week aren't generated twice.
            const anchorWeekStart = addDays(startD, -offToWkst(startD));
            let weekNo = 0;
            if (!counted && from > anchorWeekStart.getTime()) {
                weekNo = Math.floor((from - anchorWeekStart.getTime()) / (interval * 7 * 86400000)) - 1;
                if (weekNo < 0)
                    weekNo = 0;
            }
            while (!stop && weekNo < budget) {
                const weekStart = addDays(anchorWeekStart, weekNo * interval * 7);
                for (let d = 0; d < 7; d++) {
                    if (stop)
                        break;
                    const cand = addDays(weekStart, d);
                    if (targetDows.indexOf(getDow(cand)) >= 0)
                        push(cand);
                }
                weekNo++;
            }
        } else if (rule.FREQ === "MONTHLY") {
            const startDay = getD(startD);
            const startY = getY(startD);
            const startM = getM(startD);
            const monthIndex = (y, m) => y * 12 + m;
            let mIdx = 0;
            let it = 0;
            if (!counted && from > startD.getTime()) {
                const f = new Date(from);
                const est = Math.floor((monthIndex(getY(f), getM(f)) - monthIndex(startY, startM)) / interval) - 1;
                mIdx = est < 0 ? 0 : est;
            }
            while (!stop && it++ < budget) {
                const total = startM + mIdx * interval;
                const y = startY + Math.floor(total / 12);
                const m = total % 12;
                const days = _monthDayCandidates(y, m, startDay, byday, bymonthday);
                for (let i = 0; i < days.length && !stop; i++) {
                    const cand = mk(y, m, days[i]);
                    // mk overflow (e.g. Feb 29) rolls the month — drop those.
                    if (getY(cand) === y && getM(cand) === m)
                        push(cand);
                }
                mIdx++;
            }
        } else if (rule.FREQ === "YEARLY") {
            const startY = getY(startD);
            const startM = getM(startD);
            const startDay = getD(startD);
            const months = (rule.BYMONTH && rule.BYMONTH.length > 0) ? rule.BYMONTH : [startM];
            let yIdx = 0;
            let it = 0;
            if (!counted && from > startD.getTime()) {
                const est = Math.floor((getY(new Date(from)) - startY) / interval) - 1;
                yIdx = est < 0 ? 0 : est;
            }
            while (!stop && it++ < budget) {
                const y = startY + yIdx * interval;
                for (let mi = 0; mi < months.length && !stop; mi++) {
                    const m = months[mi];
                    const days = _monthDayCandidates(y, m, startDay, byday, bymonthday);
                    for (let i = 0; i < days.length && !stop; i++) {
                        const cand = mk(y, m, days[i]);
                        if (getY(cand) === y && getM(cand) === m)
                            push(cand);
                    }
                }
                yIdx++;
            }
        } else {
            // Unsupported FREQ (HOURLY…): single occurrence.
            push(startD);
        }
        return out;
    }

    // Candidate days-of-month for MONTHLY/YEARLY occurrences. These are
    // properties of the calendar date itself, so the host's local Date is
    // the right tool whatever frame the event is expressed in.
    function _monthDayCandidates(y, m, defaultDay, byday, bymonthday) {
        const days = [];
        if (bymonthday.length > 0) {
            for (let i = 0; i < bymonthday.length; i++) {
                const d = bymonthday[i];
                days.push(d > 0 ? d : new Date(y, m + 1, 0).getDate() + d + 1);
            }
        } else if (byday.length > 0) {
            const first = new Date(y, m, 1);
            const lastDay = new Date(y, m + 1, 0).getDate();
            const plainDows = [];
            for (let i = 0; i < byday.length; i++) {
                if (byday[i].ord === null) {
                    plainDows.push(byday[i].dow);
                    continue;
                }
                // Ordinal weekday: 1FR = first Friday, -1MO = last Monday.
                const ord = byday[i].ord;
                const firstMatch = 1 + ((byday[i].dow - first.getDay() + 7) % 7);
                const count = Math.floor((lastDay - firstMatch) / 7) + 1;
                let day;
                if (ord > 0)
                    day = firstMatch + (ord - 1) * 7;
                else
                    day = firstMatch + (count + ord) * 7;
                if (day >= 1 && day <= lastDay)
                    days.push(day);
            }
            if (plainDows.length > 0) {
                for (let d = 1; d <= lastDay; d++) {
                    if (plainDows.indexOf(new Date(y, m, d).getDay()) >= 0)
                        days.push(d);
                }
            }
        } else {
            days.push(defaultDay);
        }
        days.sort((a, b) => a - b);
        return days;
    }

    // -------------------------------------------------------------------
    // Time zones
    // -------------------------------------------------------------------

    readonly property var _tzFormatters: ({})

    // Resolved once; the locale cannot change under a running shell.
    property string _fmtTime: ""

    // Formatter for an IANA zone, or null when the name is unusable. Some
    // servers publish TZID as a URL path, so successively shorter suffixes
    // are tried — but only as a fallback, since "Europe/Berlin" is already a
    // perfectly good zone name.
    function _tzFormatter(tz) {
        if (tz in _tzFormatters)
            return _tzFormatters[tz];
        let f = null;
        const parts = tz.split("/");
        for (let i = 0; i < parts.length && !f; i++) {
            const candidate = parts.slice(i).join("/");
            if (candidate.length === 0)
                continue;
            try {
                f = new Intl.DateTimeFormat("en-US", {
                    timeZone: candidate,
                    hourCycle: "h23",
                    year: "numeric",
                    month: "2-digit",
                    day: "2-digit",
                    hour: "2-digit",
                    minute: "2-digit",
                    second: "2-digit"
                });
            } catch (e) {
                f = null;
            }
        }
        _tzFormatters[tz] = f;
        return f;
    }

    function _tzKnown(tz) {
        return _tzFormatter(tz) !== null;
    }

    // Offset of `tz` from UTC at `utcMs`, in milliseconds. 0 for an
    // unusable zone, which the caller avoids by checking _tzKnown first.
    function _tzOffset(tz, utcMs) {
        const f = _tzFormatter(tz);
        if (!f)
            return 0;
        const parts = f.formatToParts(new Date(utcMs));
        let y = 1970, mo = 1, d = 1, h = 0, mi = 0, s = 0;
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i];
            const n = parseInt(p.value, 10);
            if (p.type === "year")
                y = n;
            else if (p.type === "month")
                mo = n;
            else if (p.type === "day")
                d = n;
            else if (p.type === "hour")
                h = n;
            else if (p.type === "minute")
                mi = n;
            else if (p.type === "second")
                s = n;
        }
        return Date.UTC(y, mo - 1, d, h, mi, s) - utcMs;
    }

    // Wall-clock time in `tz` to a UTC instant. The first guess reads as if
    // the wall clock were UTC; the offset taken at that instant is right
    // unless it crosses a DST change, so the result is refined only when the
    // offset it lands on actually differs.
    function _zonedMs(y, mo, d, h, mi, s, tz) {
        const guess = Date.UTC(y, mo, d, h, mi, s);
        const off = _tzOffset(tz, guess);
        const ms = guess - off;
        const off2 = _tzOffset(tz, ms);
        return off2 === off ? ms : guess - off2;
    }

    // Wall-clock fields of an instant as seen in `tz`.
    function _zonedParts(ms, tz) {
        const shifted = new Date(ms + _tzOffset(tz, ms));
        return {
            y: shifted.getUTCFullYear(),
            m: shifted.getUTCMonth(),
            d: shifted.getUTCDate(),
            dow: shifted.getUTCDay(),
            h: shifted.getUTCHours(),
            mi: shifted.getUTCMinutes(),
            s: shifted.getUTCSeconds()
        };
    }

    // -------------------------------------------------------------------
    // ICS parsing
    // -------------------------------------------------------------------

    function _parseVEvents(text) {
        const rawLines = text.split(/\r\n|\r|\n/);
        const lines = [];
        for (let i = 0; i < rawLines.length; i++) {
            const line = rawLines[i];
            if ((line.startsWith(" ") || line.startsWith("\t")) && lines.length > 0)
                lines[lines.length - 1] += line.slice(1);
            else
                lines.push(line);
        }

        const events = [];
        let calColor = "";
        let cur = null;
        let depth = 0;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const upper = line.toUpperCase();
            if (upper === "BEGIN:VEVENT") {
                cur = { uid: "", title: "", status: "", color: "", start: null, end: null, duration: null, rrule: null, recurrenceId: null, exdates: [] };
                depth = 0;
                continue;
            }
            if (upper === "END:VEVENT") {
                if (cur && depth === 0 && cur.start)
                    events.push(_finishEvent(cur));
                cur = null;
                depth = 0;
                continue;
            }
            // A VALARM may carry SUMMARY, UID and DESCRIPTION of its own;
            // without this they would land on the parent event.
            if (upper === "BEGIN:VALARM") {
                depth++;
                continue;
            }
            if (upper === "END:VALARM") {
                if (depth > 0)
                    depth--;
                continue;
            }
            if (depth > 0)
                continue;
            if (!cur) {
                // VCALENDAR-level RFC 7986 COLOR (Google doesn't emit it;
                // some CalDAV servers do; X-WR-CALCOLOR is the de-facto one).
                const cc = line.indexOf(":");
                if (cc >= 0) {
                    const cn = line.slice(0, cc).split(";")[0].toUpperCase();
                    if (cn === "COLOR" || cn === "X-WR-CALCOLOR")
                        calColor = line.slice(cc + 1).trim();
                }
                continue;
            }
            const colon = line.indexOf(":");
            if (colon < 0)
                continue;
            const head = line.slice(0, colon);
            const value = line.slice(colon + 1);
            const semi = head.indexOf(";");
            const name = (semi >= 0 ? head.slice(0, semi) : head).toUpperCase();
            const params = semi >= 0 ? head.slice(semi + 1) : "";
            switch (name) {
            case "SUMMARY":
                cur.title = _unescape(value);
                break;
            case "UID":
                cur.uid = value.trim();
                break;
            case "STATUS":
                cur.status = value.trim().toUpperCase();
                break;
            case "DTSTART":
                cur.start = _parseDt(value, params);
                break;
            case "DTEND":
                cur.end = _parseDt(value, params);
                break;
            case "DURATION":
                cur.duration = value.trim();
                break;
            case "RRULE":
                cur.rrule = _parseRrule(value);
                break;
            case "RECURRENCE-ID":
                cur.recurrenceId = _parseDt(value, params);
                break;
            case "COLOR":
                cur.color = _normColor(value);
                break;
            case "EXDATE": {
                const parts = value.split(",");
                for (let j = 0; j < parts.length; j++) {
                    const dt = _parseDt(parts[j], params);
                    if (dt)
                        cur.exdates.push(dt.ms);
                }
                break;
            }
            }
        }
        return { color: calColor, events: events };
    }

    function _finishEvent(cur) {
        const startMs = cur.start.ms;
        let endMs = cur.end ? cur.end.ms : null;
        if (endMs === null && cur.duration)
            endMs = startMs + _durationMs(cur.duration);
        if (endMs === null)
            endMs = cur.start.allDay ? startMs + 24 * 3600 * 1000 : startMs;
        if (endMs <= startMs)
            endMs = startMs;
        return {
            uid: cur.uid,
            title: cur.title.length > 0 ? cur.title : "(untitled)",
            status: cur.status,
            tentative: cur.status === "TENTATIVE",
            color: cur.color,
            allDay: cur.start.allDay,
            start: startMs,
            end: endMs,
            utc: cur.start.utc === true,
            tz: cur.start.tz || "",
            rrule: cur.rrule,
            recurrenceId: cur.recurrenceId ? cur.recurrenceId.ms : null,
            exdates: cur.exdates
        };
    }

    // Returns null for anything that is not a usable date, so a broken
    // property drops the event instead of poisoning the index with NaN.
    function _parseDt(value, params) {
        const v = value.trim();
        if (v.length === 0)
            return null;

        if (params.indexOf("VALUE=DATE") >= 0 || v.length === 8) {
            if (v.length < 8)
                return null;
            const y = parseInt(v.slice(0, 4), 10);
            const mo = parseInt(v.slice(4, 6), 10) - 1;
            const d = parseInt(v.slice(6, 8), 10);
            if (mo < 0 || mo > 11 || d < 1 || d > 31)
                return null;
            const ms = new Date(y, mo, d).getTime();
            return isFinite(ms) ? { ms: ms, allDay: true, utc: false, tz: "" } : null;
        }

        const tIdx = v.indexOf("T");
        if (tIdx < 0)
            return null;
        const y = parseInt(v.slice(0, 4), 10);
        const mo = parseInt(v.slice(4, 6), 10) - 1;
        const d = parseInt(v.slice(6, 8), 10);
        const time = v.slice(tIdx + 1);
        const isUtc = time.endsWith("Z");
        const hh = parseInt(time.slice(0, 2), 10) || 0;
        const mi = parseInt(time.slice(2, 4), 10) || 0;
        const ss = parseInt(time.slice(4, 6), 10) || 0;
        if (mo < 0 || mo > 11 || d < 1 || d > 31 || hh > 23 || mi > 59 || ss > 60)
            return null;
        const raw = _paramValue(params, "TZID");

        if (isUtc) {
            return { ms: Date.UTC(y, mo, d, hh, mi, ss), allDay: false, utc: true, tz: "" };
        }
        // A TZID names a real zone, so the wall clock has to be resolved
        // through it rather than read as host-local. An unknown zone falls
        // back to floating time, which is what the value would have meant
        // without the parameter.
        const tz = _tzKnown(raw) ? raw : "";
        const ms = tz ? _zonedMs(y, mo, d, hh, mi, ss, tz) : new Date(y, mo, d, hh, mi, ss).getTime();
        return isFinite(ms) ? { ms: ms, allDay: false, utc: false, tz: tz } : null;
    }

    function _paramValue(params, name) {
        const m = params.match(new RegExp("(?:^|;)" + name + "=(?:\"([^\"]*)\"|([^;]*))", "i"));
        if (!m)
            return "";
        return ((m[1] !== undefined ? m[1] : m[2]) || "").trim();
    }

    function _durationMs(value) {
        const m = value.match(/^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
        if (!m)
            return 0;
        return ((parseInt(m[1] || 0, 10) * 7 + parseInt(m[2] || 0, 10)) * 86400 + parseInt(m[3] || 0, 10) * 3600 + parseInt(m[4] || 0, 10) * 60 + parseInt(m[5] || 0, 10)) * 1000;
    }

    function _parseRrule(value) {
        const rule = ({});
        const parts = value.split(";");
        for (let i = 0; i < parts.length; i++) {
            const eq = parts[i].indexOf("=");
            if (eq < 0)
                continue;
            const k = parts[i].slice(0, eq).toUpperCase();
            const v = parts[i].slice(eq + 1);
            switch (k) {
            case "FREQ":
                rule.FREQ = v.toUpperCase();
                break;
            case "INTERVAL":
                rule.INTERVAL = parseInt(v, 10) || 1;
                break;
            case "COUNT":
                rule.COUNT = parseInt(v, 10);
                break;
            case "UNTIL": {
                const dt = _parseDt(v, "");
                if (dt)
                    rule.UNTIL = dt.ms;
                break;
            }
            case "BYDAY":
                rule.BYDAY = v.split(",");
                break;
            case "BYMONTHDAY":
                rule.BYMONTHDAY = v.split(",").map(s => parseInt(s, 10));
                break;
            case "BYMONTH":
                rule.BYMONTH = v.split(",").map(s => parseInt(s, 10) - 1);
                break;
            case "WKST":
                rule.WKST = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 }[v.toUpperCase()];
                break;
            }
        }
        return rule;
    }

    function _unescape(value) {
        return value.replace(/\\[nN]/g, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
    }
}
