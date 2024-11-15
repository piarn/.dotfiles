-- mappings.lua
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.g.mapleader = ' '
-- Completion (using nvim-compe)
vim.o.completeopt = "menuone,noselect"

-- Save and quit mappings
map('n', '<leader>w', ':w<CR>', opts)           -- Save file
map('n', '<leader>q', ':q<CR>', opts)           -- Quit nvim regular
map('n', '<leader>Q', ':qa!<CR>', opts)         -- Force quit

-- Navigation Mappings
map('n', '<leader>ff', ':Telescope find_files<CR>', opts)  -- Find files
map('n', '<leader>fg', ':Telescope live_grep<CR>', opts)   -- Search in files
map('n', '<leader>fb', ':Telescope buffers<CR>', opts)     -- List buffers
map('n', '<leader>fh', ':Telescope help_tags<CR>', opts)   -- Help tags

-- LSP Mappings (e.g., for GoTo Definition)
map('n', 'gd', ':lua vim.lsp.buf.definition()<CR>', opts)  -- Go to definition
map('n', 'gr', ':lua vim.lsp.buf.references()<CR>', opts)  -- Show references
map('n', 'K', ':lua vim.lsp.buf.hover()<CR>', opts)       -- Show hover info
map('n', '<leader>rn', ':lua vim.lsp.buf.rename()<CR>', opts) -- Rename symbol

-- File Explorer (NvimTree)
vim.cmd([[
  " Make sure nvim-tree is loaded before setting keybinding
  augroup NvimTreeMappings
    autocmd!
    autocmd VimEnter * nnoremap <leader>e :NvimTreeToggle<CR>
  augroup END
]])

-- Window navigation (with split windows)
map('n', '<C-h>', '<C-w>h', opts)  -- Move to left split
map('n', '<C-j>', '<C-w>j', opts)  -- Move to bottom split
map('n', '<C-k>', '<C-w>k', opts)  -- Move to top split
map('n', '<C-l>', '<C-w>l', opts)  -- Move to right split

-- Resize splits using leader + hjkl
map('n', '<leader>j', ':resize +2<CR>', opts)    -- Increase height of split
map('n', '<leader>k', ':resize -2<CR>', opts)  -- Decrease height of split
map('n', '<leader>h', ':vertical resize -2<CR>', opts)   -- Decrease width of split
map('n', '<leader>l', ':vertical resize +2<CR>', opts)  -- Increase width of split

-- Move between buffers
map('n', '<leader>bn', ':bnext<CR>', opts)  -- Next buffer
map('n', '<leader>bp', ':bprevious<CR>', opts)  -- Previous buffer

-- Switch between open tabs
map('n', '<leader>to', ':tabnew<CR>', opts)  -- Open new tab
map('n', '<leader>tc', ':tabclose<CR>', opts)  -- Close tab
map('n', '<leader>tn', ':tabnext<CR>', opts)  -- Next tab
map('n', '<leader>tp', ':tabprevious<CR>', opts)  -- Previous tab

-- Incremental Search
map('n', '<leader>/', ':set hlsearch!<CR>', opts)  -- Toggle highlight search

-- Replace text within a file
-- Replace all in file (without prompt)
map('n', '<leader>r', ':%s//<Left>', opts)  -- Place cursor after first slash
-- Replace all in file with confirmation
map('n', '<leader>R', ':%s///gc<Left><Left><Left><Left>', opts)  -- Place cursor after first slash

-- LSP Formatting
map('n', '<leader>f', ':lua vim.lsp.buf.formatting()<CR>', opts)   -- Format the current buffer

-- LSP GoTo Mappings (extended)
map('n', '<leader>gd', ':lua vim.lsp.buf.definition()<CR>', opts)  -- Go to definition
map('n', '<leader>gi', ':lua vim.lsp.buf.implementation()<CR>', opts)  -- Go to implementation
map('n', '<leader>gw', ':lua vim.lsp.buf.document_symbol()<CR>', opts)  -- Show document symbols

-- Clear search highlighting
map('n', '<leader>cl', ':noh<CR>', opts)  -- Clear search highlights

-- Split the window horizontally or vertically
map('n', '<leader>sh', ':split<CR>', opts)  -- Horizontal split
map('n', '<leader>sv', ':vsplit<CR>', opts)  -- Vertical split

-- Toggle line numbers
map('n', '<leader>ln', ':set number!<CR>', opts)  -- Toggle line numbers

-- Toggle relative line numbers
map('n', '<leader>rn', ':set relativenumber!<CR>', opts)  -- Toggle relative line numbers

-- Undo and redo
map('n', 'u', ':undo<CR>', opts)       -- Undo
map('n', '<leader>U', ':redo<CR>', opts)  -- Redo

-- Open a terminal in a split
map('n', '<leader>th', ':split | terminal<CR>', opts)   -- Open terminal in a horizontal split
map('n', '<leader>tv', ':vsplit | terminal<CR>', opts)   -- Open terminal in a vertical split

-- Close terminal buffer
map('n', '<leader>T', ':bd!<CR>', opts)  -- Close terminal buffer in Normal Mode
map('t', '<leader>T', [[<C-\><C-n>:bd!<CR>]], opts)  -- Close terminal buffer in Terminal Mode
-- Exit terminal mode
map('t', '<Esc>', [[<C-\><C-n>]], opts)  -- Exit terminal mode

map('v', '<leader>y', '"+y', opts) -- Copy to clipboard in Visual mode
map('n', '<leader>p', '"+p', opts) -- Paste from clipboard in normal mode




