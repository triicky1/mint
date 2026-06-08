-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.mapleader = " " -- change leader to a space
vim.g.maplocalleader = "," -- change localleader to a comma

vim.opt.expandtab = true -- convert tabs to spaces
vim.opt.shiftwidth = 4 -- indent length (4 spaces)

vim.g.loaded_netrw = 1 -- disable netrw
vim.g.loaded_netrwPlugin = 1 -- disable netrw

vim.opt.number = true -- set numbered lines
vim.opt.relativenumber = true -- set relative numbered lines
vim.opt.numberwidth = 2 -- set number column width to 2 {default 4}

vim.opt.smartindent = true -- make indenting smarter again
vim.opt.smartcase = true -- smart case

vim.opt.wrap = true -- display lines as one long line
vim.opt.linebreak = true -- ensures that the text wraps at logical word boundaries instead of splitting a word in the middle of a character sequence.
vim.opt.breakindent = true -- wrap lines with indent

vim.opt.incsearch = true -- make search act like search in modern browsers
vim.opt.hlsearch = true -- highlight all matches on previous search pattern

vim.opt.updatetime = 100 -- faster completion (4000ms default)
vim.opt.timeoutlen = 1000 -- time to wait for a mapped sequence to complete (in milliseconds)

vim.opt.termguicolors = true -- set term gui colors (most terminals support this)
vim.opt.fileencoding = "utf-8" -- the encoding written to a file

vim.opt.scrolloff = 8 -- Makes sure there are always eight lines of context

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.opt.confirm = true -- confirm to save changes before exiting modified buffer

vim.opt.writebackup = false -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
vim.opt.undodir = os.getenv("HOME") .. "/.config/nvim/.undodir"
vim.opt.undofile = true
vim.opt.winborder = "rounded"

vim.g.lazyvim_picker = "fzf"
vim.g.lazyvim_mini_snippets_in_completion = false
vim.g.lazyvim_blink_main = true
