pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ICS event feeds. Reads ~/.config/quickshell/calendar.json
// ({"feeds": ["https://…/basic.ics", "webcal://…", "file://…"]}),
// fetches each feed (XHR for http(s), FileView for file://), parses the
// RFC 5545 subset Google's basic.ics needs, and materializes occurrences
// into a local-date index the dashboard calendar queries per day.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/calendar.json"
    property var feeds: []
    readonly property bool feedsConfigured: feeds.length > 0
    property int refreshMinutes: 15
    property double lastRefresh: 0

    // "y-m-d" (local date) -> array of {title, allDay, start, end, uid}
    property var dayMap: ({})

    // file:// feeds go through FileView — XHR blocks local file reads
    // unless QML_XHR_ALLOW_FILE_READ is set, which we can't rely on.
    property var _fileQueue: []
    property int _curIdx: -1
    property var _texts: []
    property int _pending: 0

    FileView {
        id: configFile
        path: root.configPath

        onLoadedChanged: {
            if (loaded)
                root.loadConfig();
        }
    }

    FileView {
        id: fileReader
        printErrors: false

        onLoadedChanged: {
            if (loaded && root._curIdx >= 0) {
                const idx = root._curIdx;
                root._curIdx = -1;
                root._complete(idx, fileReader.text());
                root._nextFile();
            }
        }

        onLoadFailed: {
            if (root._curIdx >= 0) {
                console.warn("CalendarEvents: cannot read", fileReader.path);
                const idx = root._curIdx;
                root._curIdx = -1;
                root._complete(idx, null);
                root._nextFile();
            }
        }
    }

    Timer {
        interval: root.refreshMinutes * 60 * 1000
        repeat: true
        running: root.feeds.length > 0
        onTriggered: root.refresh()
    }

    function loadConfig() {
        let list = [];
        try {
            const content = configFile.text();
            if (content && content.trim().length > 0) {
                const cfg = JSON.parse(content);
                list = cfg.feeds || [];
            }
        } catch (e) {
            console.warn("CalendarEvents: invalid calendar.json:", e);
        }
        feeds = list;
        if (feeds.length > 0)
            refresh();
    }

    function refresh() {
        lastRefresh = Date.now();
        if (feeds.length === 0) {
            dayMap = ({});
            return;
        }
        _texts = new Array(feeds.length).fill(null);
        _pending = feeds.length;
        _fileQueue = [];
        for (let i = 0; i < feeds.length; i++) {
            const idx = i;
            let url = feeds[idx].trim();
            if (url.startsWith("webcal://"))
                url = "https://" + url.slice(8);
            if (url.startsWith("file://")) {
                let path = url.slice(7);
                try {
                    path = decodeURIComponent(path);
                } catch (e) {
                    console.warn("CalendarEvents: bad file URL", url);
                }
                _fileQueue.push({ idx, path });
                continue;
            }
            const xhr = new XMLHttpRequest();
            xhr.open("GET", url, true);
            xhr.timeout = 10000;
            xhr.onload = function () {
                if (xhr.status !== 200) {
                    console.warn("CalendarEvents: fetch status", xhr.status, "for", url);
                    root._complete(idx, null);
                    return;
                }
                root._complete(idx, xhr.responseText || "");
            };
            xhr.onerror = function () {
                console.warn("CalendarEvents: fetch error for", url);
                root._complete(idx, null);
            };
            xhr.ontimeout = function () {
                console.warn("CalendarEvents: fetch timed out for", url);
                root._complete(idx, null);
            };
            xhr.send();
        }
        _nextFile();
    }

    // One local file at a time; every feed (http or file) decrements
    // _pending exactly once, so the rebuild happens exactly once.
    function _nextFile() {
        if (_fileQueue.length === 0)
            return;
        const item = _fileQueue.shift();
        _curIdx = item.idx;
        fileReader.path = item.path;
    }

    function _complete(idx, text) {
        _texts[idx] = text;
        if (--_pending === 0)
            _rebuild(_texts);
    }

    // Cheap hook for dashboard-open: skip if fetched within the last 5 min.
    function refreshIfStale() {
        if (!feedsConfigured)
            return;
        if (Date.now() - lastRefresh > 5 * 60 * 1000)
            refresh();
    }

    function hasEvents(date) {
        const arr = dayMap[_key(date)];
        return !!arr && arr.length > 0;
    }

    function eventsForDay(date) {
        const arr = dayMap[_key(date)];
        if (!arr || arr.length === 0)
            return [];
        const copy = arr.slice();
        copy.sort(function (a, b) {
            if (a.allDay !== b.allDay)
                return a.allDay ? -1 : 1;
            return a.start - b.start;
        });
        return copy;
    }

    function _key(d) {
        return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
    }

    // -------------------------------------------------------------------
    // Rebuild the day index from raw feed texts
    // -------------------------------------------------------------------

    function _rebuild(texts) {
        const vevents = [];
        for (let i = 0; i < texts.length; i++) {
            if (!texts[i])
                continue;
            const parsed = _parseVEvents(texts[i]);
            for (let j = 0; j < parsed.length; j++)
                vevents.push(parsed[j]);
        }

        // First base per UID wins (dedupes the same calendar in >1 feed);
        // RECURRENCE-ID instances are overrides of their base.
        const baseByUid = ({});
        const overrides = [];
        const seenOverrides = ({});
        for (let i = 0; i < vevents.length; i++) {
            const ev = vevents[i];
            if (ev.status === "CANCELLED")
                continue;
            if (ev.recurrenceId !== null) {
                const k = ev.uid + "|" + ev.recurrenceId;
                if (k in seenOverrides)
                    continue;
                seenOverrides[k] = true;
                overrides.push(ev);
            } else if (!(ev.uid in baseByUid)) {
                baseByUid[ev.uid] = ev;
            }
        }

        const overrideTimes = ({});
        for (let i = 0; i < overrides.length; i++) {
            const uid = overrides[i].uid;
            if (!(uid in overrideTimes))
                overrideTimes[uid] = [];
            overrideTimes[uid].push(overrides[i].start);
        }

        const index = ({});
        const add = function (occ) {
            const startD = new Date(occ.start);
            const endD = new Date(occ.end - 1);
            let cursor = new Date(startD.getFullYear(), startD.getMonth(), startD.getDate());
            const last = new Date(endD.getFullYear(), endD.getMonth(), endD.getDate());
            const maxSpan = occ.allDay ? 366 : 31;
            let guard = 0;
            while (cursor.getTime() <= last.getTime() && guard++ < maxSpan) {
                const k = cursor.getFullYear() + "-" + cursor.getMonth() + "-" + cursor.getDate();
                if (!(k in index))
                    index[k] = [];
                index[k].push(occ);
                cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
            }
        };

        const uids = Object.keys(baseByUid);
        for (let i = 0; i < uids.length; i++) {
            const ev = baseByUid[uids[i]];
            const skip = overrideTimes[uids[i]] || [];
            const occs = _expand(ev, skip);
            for (let j = 0; j < occs.length; j++)
                add(occs[j]);
        }
        for (let i = 0; i < overrides.length; i++) {
            const ov = overrides[i];
            add({ title: ov.title, allDay: ov.allDay, start: ov.start, end: ov.end, uid: ov.uid });
        }

        dayMap = index;
    }

    // -------------------------------------------------------------------
    // Recurrence expansion
    // -------------------------------------------------------------------

    function _occ(ev, startMs) {
        return { title: ev.title, allDay: ev.allDay, start: startMs, end: startMs + (ev.end - ev.start), uid: ev.uid };
    }

    // Expands one base event into occurrences within [DTSTART, hardEnd].
    // hardEnd = min(UNTIL, DTSTART + 2 years); COUNT additionally caps the
    // number. Returns plain occurrences; `skipTimes` are overridden
    // instances (still consumed so COUNT stays correct, just not emitted).
    function _expand(ev, skipTimes) {
        const out = [];
        if (!ev.rrule) {
            if (skipTimes.indexOf(ev.start) < 0)
                out.push(_occ(ev, ev.start));
            return out;
        }

        const rule = ev.rrule;
        const interval = Math.max(1, rule.INTERVAL || 1);
        const maxCount = rule.COUNT !== undefined ? rule.COUNT : null;
        const startD = new Date(ev.start);
        const utc = ev.utc;

        const getY = d => utc ? d.getUTCFullYear() : d.getFullYear();
        const getM = d => utc ? d.getUTCMonth() : d.getMonth();
        const getD = d => utc ? d.getUTCDate() : d.getDate();
        const getDow = d => utc ? d.getUTCDay() : d.getDay();
        const getH = d => utc ? d.getUTCHours() : d.getHours();
        const getMin = d => utc ? d.getUTCMinutes() : d.getMinutes();
        const getS = d => utc ? d.getUTCSeconds() : d.getSeconds();
        // Preserve the original wall-clock time while stepping the date.
        const mk = (y, m, day) => utc ? new Date(Date.UTC(y, m, day, getH(startD), getMin(startD), getS(startD))) : new Date(y, m, day, getH(startD), getMin(startD), getS(startD));
        const addDays = (d, n) => mk(getY(d), getM(d), getD(d) + n);

        const hardEnd = Math.min(rule.UNTIL !== undefined ? rule.UNTIL : Infinity, ev.start + 2 * 366 * 24 * 3600 * 1000);
        const exset = ({});
        for (let i = 0; i < ev.exdates.length; i++)
            exset[ev.exdates[i]] = true;

        let generated = 0;
        let stop = false;

        const push = function (d) {
            if (stop)
                return;
            const ms = d.getTime();
            if (ms > hardEnd) {
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
            while (!stop && it++ < 4000) {
                push(cur);
                cur = addDays(cur, interval);
            }
        } else if (rule.FREQ === "WEEKLY") {
            const wkst = rule.WKST !== undefined ? rule.WKST : 1;
            const targetDows = byday.length > 0 ? byday.map(b => b.dow) : [getDow(startD)];
            const offToWkst = d => (getDow(d) - wkst + 7) % 7;
            // Anchor the interval stepping to the start date's own week so
            // BYDAY days earlier in that week aren't generated twice.
            const anchorWeekStart = addDays(startD, -offToWkst(startD));
            let weekNo = 0;
            while (!stop && weekNo < 4000) {
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
            let mIdx = 0;
            let it = 0;
            while (!stop && it++ < 600) {
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
            while (!stop && it++ < 200) {
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

    // Candidate days-of-month for MONTHLY/YEARLY occurrences.
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
        let cur = null;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const upper = line.toUpperCase();
            if (upper === "BEGIN:VEVENT") {
                cur = { uid: "", title: "", status: "", start: null, end: null, duration: null, rrule: null, recurrenceId: null, exdates: [] };
                continue;
            }
            if (upper === "END:VEVENT") {
                if (cur && cur.start)
                    events.push(_finishEvent(cur));
                cur = null;
                continue;
            }
            if (!cur)
                continue;
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
        return events;
    }

    function _finishEvent(cur) {
        const startMs = cur.start.ms;
        let endMs = cur.end ? cur.end.ms : null;
        if (endMs === null && cur.duration)
            endMs = startMs + _durationMs(cur.duration);
        if (endMs === null)
            endMs = cur.start.allDay ? startMs + 24 * 3600 * 1000 : startMs;
        return {
            uid: cur.uid,
            title: cur.title.length > 0 ? cur.title : "(untitled)",
            status: cur.status,
            allDay: cur.start.allDay,
            start: startMs,
            end: endMs,
            utc: cur.start.utc === true,
            rrule: cur.rrule,
            recurrenceId: cur.recurrenceId ? cur.recurrenceId.ms : null,
            exdates: cur.exdates
        };
    }

    function _parseDt(value, params) {
        let v = value.trim();
        if (v.length === 0)
            return null;
        if (params.indexOf("VALUE=DATE") >= 0 || v.length === 8) {
            if (v.length < 8)
                return null;
            const y = parseInt(v.slice(0, 4), 10);
            const m = parseInt(v.slice(4, 6), 10) - 1;
            const d = parseInt(v.slice(6, 8), 10);
            return { ms: new Date(y, m, d).getTime(), allDay: true, utc: false };
        }
        const tIdx = v.indexOf("T");
        if (tIdx < 0)
            return null;
        const y = parseInt(v.slice(0, 4), 10);
        const m = parseInt(v.slice(4, 6), 10) - 1;
        const d = parseInt(v.slice(6, 8), 10);
        const time = v.slice(tIdx + 1);
        const isUtc = time.endsWith("Z");
        const hh = parseInt(time.slice(0, 2), 10) || 0;
        const mm = parseInt(time.slice(2, 4), 10) || 0;
        const ss = parseInt(time.slice(4, 6), 10) || 0;
        const ms = isUtc ? Date.UTC(y, m, d, hh, mm, ss) : new Date(y, m, d, hh, mm, ss).getTime();
        return { ms, allDay: false, utc: isUtc };
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
