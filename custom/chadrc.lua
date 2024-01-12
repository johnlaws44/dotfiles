---@type ChadrcConfig
local M = {}

-- Path to overriding theme and highlights files
local highlights = require "custom.highlights"

M.ui = {
  theme = "gatekeeper",
  theme_toggle = { "gatekeeper", "one_light" },
  hl_override = highlights.override,
  hl_add = highlights.add,
  transparency = true,
}
-- Change comment color
vim.api.nvim_set_hl(0, "Comment", { fg = "#dbd9d9"})

M.plugins = "custom.plugins"

-- check core.mappings for table structure
M.mappings = require "custom.mappings"

return M
