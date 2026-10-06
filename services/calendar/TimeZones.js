// IANA time zone resolution through Intl, with a cache of the
// formatters. A QML script that imports another does not inherit the QML
// document context, which is fine here: nothing below touches Qt.

var formatters = {};

// Formatter for an IANA zone, or null when the name is unusable. Some
// servers publish TZID as a URL path, so successively shorter suffixes
// are tried, but only as a fallback: "Europe/Berlin" is already a
// perfectly good zone name.
function formatter(tz) {
    if (tz in formatters)
        return formatters[tz];
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
    formatters[tz] = f;
    return f;
}

function known(tz) {
    return formatter(tz) !== null;
}

// 0 for an unusable zone, which the caller avoids by checking known first.
function offset(tz, utcMs) {
    const f = formatter(tz);
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
function zonedMs(y, mo, d, h, mi, s, tz) {
    const guess = Date.UTC(y, mo, d, h, mi, s);
    const off = offset(tz, guess);
    const ms = guess - off;
    const off2 = offset(tz, ms);
    return off2 === off ? ms : guess - off2;
}

function zonedParts(ms, tz) {
    const shifted = new Date(ms + offset(tz, ms));
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
