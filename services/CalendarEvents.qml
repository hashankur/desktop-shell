pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

import "calendar/ical.js" as Cal

// ICS event feeds. Reads ~/.config/quickshell/calendar.json
// ({"feeds": [{"url": "https://…", "color": "#rrggbb"}, …]}),
// fetches each feed with curl via Process (one per feed, in parallel), and
// answers day queries.
//
// Parsing, timezone and recurrence work is delegated to the vendored
// ical.js engine in calendar/ical.js (MPL-2.0, see services/calendar/LICENSE).
// This file owns the fetch pipeline, the month cache and the query surface.
//
// Zones come from the feed: ical.js reads an offset from the VTIMEZONE block
// the events name, and treats a time with neither a TZID nor a trailing Z as
// floating, which it resolves as UTC.
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

            onExited: exitCode => {
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
                        return {
                            url: f,
                            color: ""
                        };
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

        // Nothing to remember while there is nothing to expand: a view can
        // ask before the first fetch lands, and caching that empty result
        // would outlive it. This guard is also what keeps _rebuild's reset
        // inert, so do not drop it as redundant.
        if (_series.length > 0)
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
            const rewindDays = Math.min(366, Math.ceil((ev.durationMs || 0) / 86400000) + 1);
            const winFrom = fromMs - rewindDays * 86400000;

            const occs = _expandSeries(ev, s.skip, winFrom, toMs);
            for (let j = 0; j < occs.length; j++)
                _addOcc(added, occs[j]);

            for (let j = 0; j < s.overrides.length; j++) {
                const ov = s.overrides[j];
                if (ov.startMs < toMs && ov.startMs + (ov.durationMs || 0) > winFrom)
                    _addOcc(added, {
                        title: ov.title,
                        allDay: ov.allDay,
                        start: ov.startMs,
                        end: ov.startMs + ov.durationMs,
                        uid: ov.uid,
                        color: ov.color,
                        tentative: ov.tentative
                    });
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

    // Normalise a slot instant: all-day events key on local midnight, timed
    // events on the absolute UTC instant. Both sides of the skip comparison
    // must use the same convention.
    function _slotFor(time, allDay) {
        if (!time)
            return null;
        if (allDay)
            return new Date(time.year, time.month - 1, time.day).getTime();
        return time.toUnixTime() * 1000;
    }

    function _durationMsOf(ev) {
        try {
            const dur = ev.duration;
            if (dur) {
                const s = typeof dur.toSeconds === "function" ? dur.toSeconds() : null;
                if (s !== null && s !== undefined && isFinite(s))
                    return s * 1000;
            }
        } catch (e) {}
        if (ev.endDate && ev.startDate)
            return Math.max(0, (ev.endDate.toUnixTime() - ev.startDate.toUnixTime()) * 1000);
        return ev.startDate && ev.startDate.isDate ? 86400000 : 0;
    }

    // Occurrences of one base record overlapping [from, to). Timed and
    // all-day occurrences are keyed by the conventions in _slotFor.
    function _expandSeries(rec, skipStarts, from, to) {
        const out = [];
        if (rec.status === "CANCELLED")
            return out;

        if (rec.isRecurring) {
            const it = rec.ical.iterator();
            let next, guard = 0;
            while ((next = it.next()) && guard++ < 20000) {
                const startMs = rec.allDay ? new Date(next.year, next.month - 1, next.day).getTime() : next.toUnixTime() * 1000;
                if (startMs >= to)
                    break;
                if (startMs < from)
                    continue;
                if (skipStarts.indexOf(startMs) >= 0)
                    continue;
                out.push({
                    title: rec.title,
                    allDay: rec.allDay,
                    start: startMs,
                    end: startMs + rec.durationMs,
                    uid: rec.uid,
                    color: rec.color,
                    tentative: rec.tentative
                });
            }
            return out;
        }

        const startMs = rec.startMs;
        if (startMs >= from && startMs < to && skipStarts.indexOf(startMs) < 0)
            out.push({
                title: rec.title,
                allDay: rec.allDay,
                start: startMs,
                end: startMs + rec.durationMs,
                uid: rec.uid,
                color: rec.color,
                tentative: rec.tentative
            });
        return out;
    }

    // Build the normalised record for one VEVENT component. Returns null
    // when there is nothing usable to show.
    function _recordFromVc(vc) {
        // The date properties are lazy, so a malformed DTSTART throws on
        // first read rather than at construction, and one broken event must
        // not sink the whole feed.
        try {
            return _recordFields(vc);
        } catch (e) {
            console.warn("CalendarEvents: skipping unusable VEVENT:", e);
            return null;
        }
    }

    function _recordFields(vc) {
        let ev;
        try {
            ev = new Cal.ICAL.Event(vc);
        } catch (e) {
            return null;
        }
        if (!ev.startDate)
            return null;
        const allDay = !!ev.startDate.isDate;
        const status = vc.getFirstPropertyValue("status") || "";
        const rec = {
            uid: ev.uid || "",
            title: (ev.summary && ev.summary.length > 0) ? ev.summary : "(untitled)",
            status: status,
            tentative: status === "TENTATIVE",
            color: "",
            feedColor: "",
            calColor: "",
            rawColor: "",
            allDay: allDay,
            ical: ev,
            isRecurring: ev.isRecurring(),
            recurrenceSlot: ev.recurrenceId ? _slotFor(ev.recurrenceId, allDay) : null,
            durationMs: _durationMsOf(ev),
            startMs: null
        };

        // RFC 7986 COLOR at the VEVENT level; kept raw because validation
        // needs Qt.color, which the caller owns.
        let raw = vc.getFirstPropertyValue("COLOR");
        if (!(typeof raw === "string" && raw.length > 0))
            raw = vc.getFirstPropertyValue("color");
        if (!(typeof raw === "string" && raw.length > 0))
            raw = vc.getFirstPropertyValue("X-APPLE-CALENDAR-COLOR");
        if (typeof raw === "string" && raw.length > 0)
            rec.rawColor = raw;

        if (!rec.isRecurring) {
            const start = ev.startDate;
            rec.startMs = allDay ? new Date(start.year, start.month - 1, start.day).getTime() : start.toUnixTime() * 1000;
        }
        return rec;
    }

    function _vcalColor(comp) {
        let c = "";
        try {
            c = comp.getFirstPropertyValue("X-WR-CALCOLOR") || c;
        } catch (e) {}
        try {
            c = comp.getFirstPropertyValue("COLOR") || c;
        } catch (e) {}
        if (typeof c !== "string" || c.length === 0)
            return "";
        return root._normColor(c);
    }

    function _rebuild(texts) {
        // Nothing to do if the feeds said exactly what they said last time;
        // rebuilding would hand every view fresh arrays for no reason.
        const sig = texts.join("\x00");
        if (sig === _indexSig)
            return;
        _indexSig = sig;

        const bases = ({});
        const instances = [];

        for (let i = 0; i < texts.length; i++) {
            if (!texts[i])
                continue;

            let anonIdx = 0;
            let root;
            try {
                root = new Cal.ICAL.Component(Cal.ICAL.parse(texts[i]));
            } catch (e) {
                console.warn("CalendarEvents: cannot parse feed:", e);
                continue;
            }

            const feedColor = feeds[i] ? feeds[i].color : "";
            const calColor = _vcalColor(root);

            try {
                // Feeds usually ship a VTIMEZONE block for the zones their
                // events use; register it so the iterator resolves
                // TZID-anchored times in that zone.
                for (const t of root.getAllSubcomponents("vtimezone"))
                    Cal.ICAL.TimezoneService.register(t);
            } catch (e) {}

            for (const vc of root.getAllSubcomponents("vevent")) {
                const rec = _recordFromVc(vc);
                if (!rec)
                    continue;
                rec.feedColor = feedColor;
                rec.calColor = calColor;
                if (rec.recurrenceSlot !== null) {
                    instances.push(rec);
                    continue;
                }
                if (!rec.uid)
                    rec.uid = "anonymous-" + i + "-" + anonIdx++;
                // First base per UID wins (the same calendar in more than one feed).
                if (!(rec.uid in bases))
                    bases[rec.uid] = {
                        ev: rec,
                        skip: [],
                        overrides: []
                    };
            }
        }

        // Instances need the base resolved first, and their RECURRENCE-ID is
        // the *original* slot: that is what the base expansion has to
        // suppress, since a reschedule moves DTSTART somewhere else.
        for (let i = 0; i < instances.length; i++) {
            const inst = instances[i];
            const s = bases[inst.uid];
            if (!s || !s.ev)
                continue;
            if (s.skip.indexOf(inst.recurrenceSlot) < 0)
                s.skip.push(inst.recurrenceSlot);
            if (inst.status !== "CANCELLED") {
                // A partial instance is still the replacement for its slot.
                if (inst.title === "(untitled)")
                    inst.title = s.ev.title;
                if (!inst.rawColor)
                    inst.rawColor = s.ev.rawColor;
                s.overrides.push(inst);
            }
        }

        const series = [];
        for (const uid in bases) {
            const s = bases[uid];
            // A cancelled base drops its whole series, instances included.
            if (s.ev.status === "CANCELLED")
                continue;
            // Precedence: config color > VEVENT COLOR > VCALENDAR COLOR.
            s.ev.color = s.ev.feedColor || _normColor(s.ev.rawColor) || s.ev.calColor;
            for (let j = 0; j < s.overrides.length; j++) {
                const ov = s.overrides[j];
                ov.color = ov.feedColor || _normColor(ov.rawColor) || s.ev.color;
            }
            series.push(s);
        }

        // The assignments below each fire change notifications, and every
        // binding that reads a day (month grid cells, the day list, the bar
        // chip) re-enters _ensureMonth synchronously. That re-entry expands
        // and caches, so an assignment which empties dayMap *after* _months
        // has been cleared leaves the cache claiming a month that holds
        // nothing, and every later query short-circuits to an empty list.
        // Resetting while _series is empty closes that window: with nothing
        // to expand, _ensureMonth neither writes dayMap nor remembers the
        // month, and the final assignment is the one that re-expands.
        _series = [];
        _months = ({});
        dayMap = ({});
        _series = series;
    }
}
