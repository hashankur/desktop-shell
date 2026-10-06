.import "TimeZones.js" as Tz

function occ(ev, startMs) {
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
function expand(ev, skipTimes, from, to) {
    const out = [];
    if (!ev.rrule) {
        if (ev.start < to && ev.end > from && skipTimes.indexOf(ev.start) < 0)
            out.push(occ(ev, ev.start));
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
    const wall = tz ? Tz.zonedParts(ev.start, tz) : null;

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
        ? Tz.zonedMs(getY(d), getM(d), getD(d), getH(d), getMin(d), getS(d), tz)
        : d.getTime();

    // The window is half-open and UNTIL is inclusive, so the two bounds
    // cannot share one comparison.
    const until = rule.UNTIL !== undefined ? rule.UNTIL : Infinity;
    const exset = ({});
    for (let i = 0; i < ev.exdates.length; i++)
        exset[ev.exdates[i]] = true;

    // A COUNT-limited rule is walked from DTSTART so the count stays
    // exact; an open-ended one seeks to the window instead. Every seek
    // lands one step early, because a DST shift can put the estimate a
    // step late. push() drops whatever falls before the window.
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
        out.push(occ(ev, ms));
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
            const days = monthDayCandidates(y, m, startDay, byday, bymonthday);
            for (let i = 0; i < days.length && !stop; i++) {
                const cand = mk(y, m, days[i]);
                // mk overflow (e.g. Feb 29) rolls the month, so drop those.
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
                const days = monthDayCandidates(y, m, startDay, byday, bymonthday);
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
function monthDayCandidates(y, m, defaultDay, byday, bymonthday) {
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
