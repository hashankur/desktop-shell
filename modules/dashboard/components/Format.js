.pragma library

function duration(seconds) {
    const s = Math.max(0, Math.round(seconds));
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (d > 0)
        return d + "d " + h + "h";
    if (h > 0)
        return h + "h " + m + "m";
    return m + "m";
}

function bytes(n) {
    const units = ["B", "KB", "MB", "GB", "TB"];
    let v = Math.max(0, n);
    let i = 0;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return (v >= 100 || i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}

function rate(bytesPerSecond) {
    return bytes(bytesPerSecond) + "/s";
}
