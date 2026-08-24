function fuzzyScore(query, text) {
    if (query.length === 0) return 0;
    const q = query.toLowerCase();
    const t = text.toLowerCase();
    let qi = 0;
    let score = 0;
    let prevMatched = false;
    let prevWasSeparator = true;

    for (let ti = 0; ti < t.length && qi < q.length; ti++) {
        if (t[ti] === q[qi]) {
            score += 10;
            if (prevMatched)
                score += 15;
            if (prevWasSeparator)
                score += 20;
            if (ti === 0)
                score += 40;
            prevMatched = true;
            prevWasSeparator = false;
            qi++;
        } else {
            prevMatched = false;
            prevWasSeparator = (t[ti] === " " || t[ti] === "-" || t[ti] === "_");
            score -= 5;
        }
    }
    if (qi < q.length) return -1;
    score -= (t.length - q.length) * 2;
    return score;
}
