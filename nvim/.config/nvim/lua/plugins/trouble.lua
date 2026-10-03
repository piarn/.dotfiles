-- Problems panel, bottom: diagnostics (␣p file, ␣P project) and the quickfix
-- list after a build (␣rb).
return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    focus = true,
    warn_no_results = false,
    open_no_results = true,
  },
}
