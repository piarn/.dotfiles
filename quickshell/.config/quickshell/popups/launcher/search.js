.pragma library
// Pure helpers for Launcher.qml: match scoring and the `=` calculator.
// No QML types in here, so it can be exercised with plain node.

// How well `text` matches the lowercase query `q`, or -1 for no match.
// Exact > prefix > word start > substring > in-order letters ("lbo" →
// LibreOffice); `loose` false skips that last one, for long text like
// descriptions where scattered letters match almost anything.
function score(text, q, loose) {
    if (!text) return -1
    const t = text.toLowerCase()
    if (t === q) return 1000
    if (t.startsWith(q)) return 800 - Math.min(t.length - q.length, 100)
    const at = t.indexOf(q)
    if (at > 0 && /[^a-z0-9]/.test(t[at - 1])) return 600 - Math.min(at, 100)
    for (const w of t.split(/[^a-z0-9]+/)) {
        if (w.startsWith(q)) return 600 - Math.min(t.indexOf(w), 100)
    }
    if (at > 0) return 400 - Math.min(at, 100)
    if (!loose || q.length < 2) return -1
    // In-order letters: reward runs of consecutive hits and hits on a
    // word start, so "lbo" ranks LibreOffice above a random long name.
    let ti = 0, run = 0, bonus = 0
    for (const c of q) {
        const found = t.indexOf(c, ti)
        if (found < 0) return -1
        run = found === ti ? run + 1 : 0
        bonus += run * 10
        if (found === 0 || /[^a-z0-9]/.test(t[found - 1])) bonus += 15
        ti = found + 1
    }
    return Math.min(100 + bonus - Math.min(t.length, 60), 350)
}

// Best score of one query word across weighted fields [{text, weight, loose}].
function fieldScore(fields, w) {
    let best = -1
    for (const f of fields) {
        const s = score(f.text, w, f.loose)
        if (s >= 0) best = Math.max(best, s * f.weight)
    }
    return best
}

// Every word of the query has to match some field; scores add up.
function match(fields, query) {
    const words = query.toLowerCase().split(/\s+/).filter(w => w)
    let total = 0
    for (const w of words) {
        const s = fieldScore(fields, w)
        if (s < 0) return -1
        total += s
    }
    return total
}

// Calculator: + - * / % ^, parentheses, unary minus, implicit nothing.
// Functions sqrt abs round floor ceil ln log sin cos tan, constants pi e.
// A hand-rolled parser rather than eval, so the box never runs code.
function calc(expr) {
    const src = expr.replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/")
    const toks = src.match(/\d*\.?\d+(?:e[+-]?\d+)?|[a-z]+|\*\*|[-+*/%^()]|\S/gi)
    if (!toks) return null
    let i = 0
    const peek = () => toks[i]
    const take = () => toks[i++]
    const fns = {
        sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor,
        ceil: Math.ceil, ln: Math.log, log: Math.log10, sin: Math.sin,
        cos: Math.cos, tan: Math.tan,
    }
    const consts = { pi: Math.PI, e: Math.E }

    function primary() {
        const t = take()
        if (t === undefined) throw 0
        if (t === "(") {
            const v = sum()
            if (take() !== ")") throw 0
            return v
        }
        if (t === "-") return -power()
        if (t === "+") return power()
        if (/^[\d.]/.test(t)) return parseFloat(t)
        const name = t.toLowerCase()
        if (name in consts) return consts[name]
        if (name in fns) {
            if (peek() === "(") return fns[name](primary())
            return fns[name](power())
        }
        throw 0
    }
    // right-associative: 2^3^2 = 2^9
    function power() {
        const base = primary()
        if (peek() === "^" || peek() === "**") {
            take()
            return Math.pow(base, power())
        }
        return base
    }
    function product() {
        let v = power()
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            const op = take(), r = power()
            v = op === "*" ? v * r : op === "/" ? v / r : v % r
        }
        return v
    }
    function sum() {
        let v = product()
        while (peek() === "+" || peek() === "-") {
            const op = take(), r = product()
            v = op === "+" ? v + r : v - r
        }
        return v
    }

    try {
        const v = sum()
        if (i !== toks.length || !isFinite(v)) return null
        return v
    } catch (e) {
        return null
    }
}

// 0.1+0.2 shows as 0.3, big/small numbers keep their exponent.
function formatNumber(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v)
    return String(parseFloat(v.toPrecision(12)))
}
