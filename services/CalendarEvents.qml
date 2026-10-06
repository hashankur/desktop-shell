pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

import "calendar/Ics.js" as Ics
import "calendar/Recurrence.js" as Rec

// ICS event feeds. Reads ~/.config/quickshell/calendar.json
// ({"feeds": [{"url": "https://…", "color": "#rrggbb"}, …]}),
// fetches each feed with curl via Process (one per feed, in parallel), and
// answers day queries.
//
// The parsing, timezone and recurrence work lives in calendar/*.js, which
// are pure JS with no Qt dependency. This file owns the fetch pipeline,
// the month cache and the query surface.
//
// Recurrences are expanded lazily: only the months a view actually asks
// for are materialized into the day index, so a big calendar costs one
// month of work instead of two years of work per refresh.
//
// A failed fetch keeps the slot's previous text, so stale beats empty.
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

        // The `loaded` signal fires on every successful load. The
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

            // A completion whose generation no longer matches belongs to a
            // wave we have already replaced.
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

            const occs = Rec.expand(ev, s.skip, winFrom, toMs);
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

    // All-day DTEND is exclusive per RFC 5545, hence the -1.
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
            const cal = Ics.parse(texts[i]);
            const cfgColor = feeds[i] ? feeds[i].color : "";
            const calColor = _normColor(cal.color);
            for (let j = 0; j < cal.events.length; j++) {
                const ev = cal.events[j];
                // Precedence: config color > VEVENT COLOR > VCALENDAR COLOR.
                // The parser hands the VEVENT color back raw, since
                // validating it needs Qt.color.
                ev.color = cfgColor || _normColor(ev.color) || calColor;
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



}
