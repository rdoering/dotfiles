-- lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

-- Standard-Features (in Neovim meist schon an, aber sicher ist sicher)
vim.cmd('syntax on')
vim.cmd('filetype indent plugin on')

-- UI Einstellungen
vim.opt.cursorline = true
vim.opt.termguicolors = true -- Aktiviert 24-bit RGB Farben im Terminal

-- linenumber
vim.opt.number = true
