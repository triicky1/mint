-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- In visual mode, pressing <leader>p deletes the selected text to a "black hole"
-- register (so it doesn’t overwrite anything) and then pastes it.
vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Paste without yanking selection" })

-- Centering the screen with Up/Down movement
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Search results centering
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- No operation
vim.keymap.set("n", "Q", "<nop>", { desc = "Disable Q (no-op)" })

-- Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>', { desc = "Disable left arrow" })
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>', { desc = "Disable right arrow" })
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>', { desc = "Disable up arrow" })
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>', { desc = "Disable down arrow" })
