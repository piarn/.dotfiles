-- Shows what each leader group holds while you type; ␣dd uses its loop mode
-- for DEBUG mode. Group names come from config/keymaps.lua.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = function()
    return {
      preset = "helix",
      spec = require("config.keymaps").groups,
    }
  end,
}
