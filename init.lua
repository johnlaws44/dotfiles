-- local autocmd = vim.api.nvim_create_autocmd

-- Auto resize panes when resizing nvim window
-- autocmd("VimResized", {
--   pattern = "*",
--   command = "tabdo wincmd =",
-- })
vim.opt.signcolumn = "yes"
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function()
    vim.lsp.start {
      name = "rubocop",
      cmd = { "bundle", "exec", "rubocop", "--lsp" },
    }
  end,
})
