// The hub's "dev" scope: tmux sessions (running and the sessionizer's
// frozen ones), git projects, and ssh hosts — each opened as a tmux
// session through ~/.local/bin/tmux-open, which switches the terminal
// already showing tmux or opens a kitty. One session per case: a project
// session is named after its directory and starts nvim, a host session
// starts ssh.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property string name: "dev"
    readonly property string glyph: "\u{f0169}"
    readonly property string home: Quickshell.env("HOME")
    readonly property string open: home + "/.local/bin/tmux-open"

    property var sessions: []   // [{name, windows, attached, frozen}]
    property var projects: []   // [path], most-visited first (zoxide)
    property var hosts: []      // [name]

    function refresh() {
        sessionProc.running = true
        projectProc.running = true
        hostProc.running = true
    }

    function short(p) { return p.startsWith(home) ? "~" + p.slice(home.length) : p }

    function sessionRows() {
        return sessions.map(s => ({
            kind: "action", group: "session", key: "tmux:" + s.name,
            title: s.name, glyph: s.frozen ? "\u{f0717}" : "\u{f018d}",
            aliases: "tmux session case",
            subtitle: s.frozen ? "frozen · enter thaws" : s.windows + " windows" + (s.attached ? " · attached" : ""),
            on: s.attached,
            run: () => Quickshell.execDetached([root.open, s.name]),
        }))
    }

    function projectRows() {
        return projects.map(p => {
            const name = p.replace(/\/$/, "").split("/").pop().replace(/^\./, "")
            return {
                kind: "action", group: "project", key: "project:" + p,
                title: name, glyph: "\u{f02a2}", aliases: "project repo git code",
                subtitle: short(p),
                run: () => Quickshell.execDetached([root.open, name, p, "nvim"]),
            }
        })
    }

    function hostRows() {
        return hosts.map(h => ({
            kind: "action", group: "ssh", key: "ssh:" + h,
            title: h, glyph: "\u{f08c0}", aliases: "ssh host server remote",
            subtitle: "ssh " + h,
            run: () => Quickshell.execDetached([root.open, "ssh-" + h, root.home, "ssh", h]),
        }))
    }

    readonly property var rows: {
        const out = []
        const s = sessionRows(), p = projectRows(), h = hostRows()
        if (s.length) out.push({ kind: "header", title: "sessions" }, ...s)
        if (p.length) out.push({ kind: "header", title: "projects" }, ...p)
        if (h.length) out.push({ kind: "header", title: "ssh" }, ...h)
        return out
    }

    // running sessions, then frozen snapshots not running
    Process {
        id: sessionProc
        command: ["sh", "-c", `
            tmux list-sessions -F '#{session_name}\t#{session_windows}\t#{session_attached}' 2>/dev/null
            d=\${XDG_DATA_HOME:-$HOME/.local/share}/tmux/frozen
            for f in "$d"/*.txt; do [ -f "$f" ] && printf '%s\tF\t0\n' "$(basename "$f" .txt)"; done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                root.sessions = text.split("\n").filter(l => l).map(l => {
                    const [name, windows, attached] = l.split("\t")
                    return { name, windows: parseInt(windows) || 0, attached: attached !== "0", frozen: windows === "F" }
                }).filter(s => !seen[s.name] && (seen[s.name] = true))
            }
        }
    }

    // git repos under ~/projects plus the two you live in, ranked by
    // zoxide's frecency (unvisited ones last)
    Process {
        id: projectProc
        command: ["sh", "-c", `
            { zoxide query -l 2>/dev/null
              fd -H -t d --max-depth 4 '^\\.git$' "$HOME/projects" 2>/dev/null | sed 's|/\\.git/\\?$||'
              printf '%s\\n' "$HOME/.dots" "$HOME/.rice"
            } | awk '!seen[$0]++' | while IFS= read -r d; do [ -e "$d/.git" ] && printf '%s\\n' "$d"; done | head -n 40
        `]
        stdout: StdioCollector {
            onStreamFinished: root.projects = text.split("\n").filter(l => l)
        }
    }

    Process {
        id: hostProc
        command: ["sh", "-c", "awk 'tolower($1) == \"host\" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' \"$HOME/.ssh/config\" 2>/dev/null | awk '!seen[$0]++'"]
        stdout: StdioCollector {
            onStreamFinished: root.hosts = text.split("\n").filter(l => l)
        }
    }
}
