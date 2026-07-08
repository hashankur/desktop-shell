function fuzzyScore(query, text) {
    if (query.length === 0) return 0;
    var q = query.toLowerCase();
    var t = text.toLowerCase();
    var qi = 0;
    var score = 0;
    var prevMatched = false;
    var prevWasSeparator = true;

    for (var ti = 0; ti < t.length && qi < q.length; ti++) {
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
            if (t[ti] === " " || t[ti] === "-" || t[ti] === "_")
                prevWasSeparator = true;
            else
                prevWasSeparator = false;
            score -= 5;
        }
    }
    if (qi < q.length) return -1;
    score -= (t.length - q.length) * 2;
    return score;
}
