.pragma library
// What a cliphist entry is, from its one-line preview, for the clipboard
// tab's rows: a kind (its glyph), a subtitle, a title for the ones whose
// preview isn't readable (images, binary data), and for colours the colour.
// No QML types, so tests/test-island-helpers.sh runs it under node.

// Material Symbols codepoints, read from the font's ligatures
const GLYPHS = {
    link: "",      // link
    file: "",      // description
    color: "",     // palette
    image: "",     // image
    binary: "",    // data_object
    code: "",      // code
    text: ""       // notes
}

function classify(preview) {
    const p = preview.trim()
    let m = p.match(/^\[\[ binary data (\S+ \S+) (\S+) (\d+)x(\d+) \]\]$/)
    if (m) return { kind: "image", title: "image", subtitle: "image · " + m[2] + " · " + m[3] + "×" + m[4] + " · " + m[1] }
    m = p.match(/^\[\[ binary data (\S+ \S+) (.*) \]\]$/)
    if (m) return { kind: "binary", title: "binary data", subtitle: m[2] + " · " + m[1] }
    if (/^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(p))
        return { kind: "color", color: p, subtitle: "colour" }
    if (/^https?:\/\/\S+$/i.test(p)) return { kind: "link", subtitle: "link · " + p.replace(/^https?:\/\/([^/?#]+).*$/i, "$1") }
    if (/^file:\/\/\S+$/i.test(p) || /^~?\/\S*$/.test(p)) return { kind: "file", subtitle: "file" }
    // several code-shaped tokens rather than one stray bracket
    const codey = (p.match(/[{};]|=>|\(\)|==|!=|\bfunction\b|\bconst\b|\bdef\b|\breturn\b/g) || []).length
    if (codey >= 3) return { kind: "code", subtitle: "code · " + chars(p) }
    return { kind: "text", subtitle: "text · " + chars(p) }
}

// cliphist cuts previews off at 100 characters
function chars(p) {
    return p.length >= 100 ? "100+ chars" : p.length + " chars"
}

// newest first in, newest first out; later copies of the same text dropped
function dedupe(entries) {
    const seen = {}
    return entries.filter(e => {
        if (seen[e.preview]) return false
        seen[e.preview] = true
        return true
    })
}
