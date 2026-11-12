function duration(mins) {
    if (mins < 60)
        return `${mins}m`;
    if (mins < 1440) {
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return m ? `${h}h ${m}m` : `${h}h`;
    }
    return `${Math.ceil(mins / 1440)}d`;
}
