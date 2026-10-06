.import "TimeZones.js" as Tz

function parse(text) {
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
                events.push(finishEvent(cur));
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
            cur.title = unescape(value);
            break;
        case "UID":
            cur.uid = value.trim();
            break;
        case "STATUS":
            cur.status = value.trim().toUpperCase();
            break;
        case "DTSTART":
            cur.start = parseDt(value, params);
            break;
        case "DTEND":
            cur.end = parseDt(value, params);
            break;
        case "DURATION":
            cur.duration = value.trim();
            break;
        case "RRULE":
            cur.rrule = parseRrule(value);
            break;
        case "RECURRENCE-ID":
            cur.recurrenceId = parseDt(value, params);
            break;
        case "COLOR":
            // Left raw: validating it needs Qt.color, so the caller does it.
            cur.color = value.trim();
            break;
        case "EXDATE": {
            const parts = value.split(",");
            for (let j = 0; j < parts.length; j++) {
                const dt = parseDt(parts[j], params);
                if (dt)
                    cur.exdates.push(dt.ms);
            }
            break;
        }
        }
    }
    return { color: calColor, events: events };
}

function finishEvent(cur) {
    const startMs = cur.start.ms;
    let endMs = cur.end ? cur.end.ms : null;
    if (endMs === null && cur.duration)
        endMs = startMs + durationMs(cur.duration);
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
function parseDt(value, params) {
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
    const raw = paramValue(params, "TZID");

    if (isUtc) {
        return { ms: Date.UTC(y, mo, d, hh, mi, ss), allDay: false, utc: true, tz: "" };
    }
    // A TZID names a real zone, so the wall clock has to be resolved
    // through it rather than read as host-local. An unknown zone falls
    // back to floating time, which is what the value would have meant
    // without the parameter.
    const tz = Tz.known(raw) ? raw : "";
    const ms = tz ? Tz.zonedMs(y, mo, d, hh, mi, ss, tz) : new Date(y, mo, d, hh, mi, ss).getTime();
    return isFinite(ms) ? { ms: ms, allDay: false, utc: false, tz: tz } : null;
}

function paramValue(params, name) {
    const m = params.match(new RegExp("(?:^|;)" + name + "=(?:\"([^\"]*)\"|([^;]*))", "i"));
    if (!m)
        return "";
    return ((m[1] !== undefined ? m[1] : m[2]) || "").trim();
}

function durationMs(value) {
    const m = value.match(/^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
    if (!m)
        return 0;
    return ((parseInt(m[1] || 0, 10) * 7 + parseInt(m[2] || 0, 10)) * 86400 + parseInt(m[3] || 0, 10) * 3600 + parseInt(m[4] || 0, 10) * 60 + parseInt(m[5] || 0, 10)) * 1000;
}

function parseRrule(value) {
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
            const dt = parseDt(v, "");
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

function unescape(value) {
    return value.replace(/\\[nN]/g, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
}
