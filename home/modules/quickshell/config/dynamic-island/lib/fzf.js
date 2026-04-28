.pragma library

// Hand-rolled port of the fzf v2 fuzzy matching algorithm.
// Score-only (no match-position backtracking), good enough for ranking
// a few hundred desktop entries against a typed query.
//
// References (read for the algorithm, not vendored):
//   fzf (Go, MIT):              https://github.com/junegunn/fzf/blob/master/src/algo/algo.go
//   fzf-for-js (BSD-3-Clause):  https://github.com/ajitid/fzf-for-js/blob/master/src/lib/algo.ts
//
// Differences vs. upstream:
//   - Score-only; no positions, no extended-search syntax, no async.
//   - ASCII-focused char-class table (non-ASCII counted as letter, no normalization).
//   - Public API mimics fzf-for-js: `new Fzf(items, { selector, limit }).find(query)`
//     returns `[{ item, score }, ...]` sorted high-to-low.

var SCORE_MATCH = 16;
var SCORE_GAP_START = -3;
var SCORE_GAP_EXTENSION = -1;
var BONUS_BOUNDARY = SCORE_MATCH / 2;                              // 8
var BONUS_CAMEL_123 = BONUS_BOUNDARY + SCORE_GAP_EXTENSION;        // 7
var BONUS_CONSECUTIVE = -(SCORE_GAP_START + SCORE_GAP_EXTENSION);  // 4
var BONUS_FIRST_CHAR_MULTIPLIER = 2;

var CHAR_NON_WORD = 0;
var CHAR_LOWER = 1;
var CHAR_UPPER = 2;
var CHAR_NUMBER = 3;
var CHAR_LETTER = 4;

function charClass(code) {
    if (code >= 97 && code <= 122) return CHAR_LOWER;   // a-z
    if (code >= 65 && code <= 90) return CHAR_UPPER;    // A-Z
    if (code >= 48 && code <= 57) return CHAR_NUMBER;   // 0-9
    if (code >= 128) return CHAR_LETTER;                 // rough non-ASCII letter
    return CHAR_NON_WORD;
}

function bonusFor(prev, curr) {
    if (curr === CHAR_NON_WORD) return 0;
    if (prev === CHAR_NON_WORD) return BONUS_BOUNDARY;
    if (prev === CHAR_LOWER && curr === CHAR_UPPER) return BONUS_CAMEL_123;
    if (prev !== CHAR_NUMBER && curr === CHAR_NUMBER) return BONUS_CAMEL_123;
    return 0;
}

// Returns best fuzzy score or -Infinity if pattern is not a subsequence.
// Caller must pre-lowercase `pattern`.
function scoreText(text, pattern) {
    text = (text == null) ? "" : String(text);
    var pl = pattern.length;
    if (pl === 0) return 0;
    var tl = text.length;
    if (pl > tl) return -Infinity;

    var lowerText = text.toLowerCase();

    var pi = 0;
    var firstIdx = -1;
    var lastIdx = 0;
    for (var i = 0; i < tl; i++) {
        if (lowerText.charCodeAt(i) === pattern.charCodeAt(pi)) {
            if (firstIdx < 0) firstIdx = i;
            pi++;
            if (pi === pl) {
                lastIdx = i + 1;
                break;
            }
        }
    }
    if (pi < pl) return -Infinity;

    var width = lastIdx - firstIdx;

    var bonuses = new Array(width);
    var prevClass = firstIdx > 0 ? charClass(text.charCodeAt(firstIdx - 1)) : CHAR_NON_WORD;
    for (var j = 0; j < width; j++) {
        var cls = charClass(text.charCodeAt(firstIdx + j));
        bonuses[j] = bonusFor(prevClass, cls);
        prevClass = cls;
    }

    // DP. H = total score, C = score if (i, j) was a consecutive-match cell.
    var size = pl * width;
    var H = new Array(size);
    var C = new Array(size);
    for (var k = 0; k < size; k++) {
        H[k] = 0;
        C[k] = 0;
    }

    var maxScore = -Infinity;

    var inGap = false;
    var pc0 = pattern.charCodeAt(0);
    for (var j = 0; j < width; j++) {
        var ti = firstIdx + j;
        if (lowerText.charCodeAt(ti) === pc0) {
            var s = SCORE_MATCH + bonuses[j] * BONUS_FIRST_CHAR_MULTIPLIER;
            H[j] = s;
            C[j] = s;
            inGap = false;
            if (pl === 1 && s > maxScore) maxScore = s;
        } else {
            var prev = j > 0 ? H[j - 1] : 0;
            var gap = inGap ? SCORE_GAP_EXTENSION : SCORE_GAP_START;
            var v = prev + gap;
            H[j] = v > 0 ? v : 0;
            C[j] = 0;
            inGap = true;
        }
    }
    if (pl === 1) return maxScore === -Infinity ? -Infinity : maxScore;

    for (var i = 1; i < pl; i++) {
        var pc = pattern.charCodeAt(i);
        var rowOff = i * width;
        var prevOff = (i - 1) * width;
        inGap = false;
        for (var j = i; j < width; j++) {
            var ti = firstIdx + j;
            var match = -Infinity;
            if (lowerText.charCodeAt(ti) === pc) {
                var diag = j > 0 ? H[prevOff + j - 1] : 0;
                var s1 = diag + SCORE_MATCH + bonuses[j];
                var prevC = j > 0 ? C[prevOff + j - 1] : 0;
                if (prevC > 0) {
                    var consBonus = bonuses[j] > BONUS_CONSECUTIVE ? bonuses[j] : BONUS_CONSECUTIVE;
                    var s2 = prevC + SCORE_MATCH + consBonus;
                    match = s1 > s2 ? s1 : s2;
                } else {
                    match = s1;
                }
            }
            var horizontal = j > 0 ? H[rowOff + j - 1] + (inGap ? SCORE_GAP_EXTENSION : SCORE_GAP_START) : -Infinity;

            if (match >= horizontal && match > 0) {
                H[rowOff + j] = match;
                C[rowOff + j] = match;
                inGap = false;
            } else {
                H[rowOff + j] = horizontal > 0 ? horizontal : 0;
                C[rowOff + j] = 0;
                inGap = true;
            }
            if (i === pl - 1 && H[rowOff + j] > maxScore) maxScore = H[rowOff + j];
        }
    }
    return maxScore <= 0 ? -Infinity : maxScore;
}

// fzf-for-js compatible API: `new Fzf(items, { selector, limit }).find(query)`
function Fzf(items, options) {
    options = options || {};
    this.items = items;
    this.selector = options.selector || function (x) { return String(x); };
    this.limit = options.limit > 0 ? options.limit : items.length;

    this.targets = new Array(items.length);
    for (var i = 0; i < items.length; i++) {
        var t = this.selector(items[i]);
        this.targets[i] = (t == null) ? "" : String(t);
    }
}

Fzf.prototype.find = function (query) {
    var lowerQuery = (query == null ? "" : String(query)).toLowerCase();
    var n = this.items.length;
    var results = [];
    if (lowerQuery.length === 0) {
        var lim = this.limit < n ? this.limit : n;
        for (var i = 0; i < lim; i++) results.push({ item: this.items[i], score: 0 });
        return results;
    }
    for (var i = 0; i < n; i++) {
        var s = scoreText(this.targets[i], lowerQuery);
        if (s > -Infinity) results.push({ item: this.items[i], score: s });
    }
    results.sort(function (a, b) { return b.score - a.score; });
    if (results.length > this.limit) results.length = this.limit;
    return results;
};
