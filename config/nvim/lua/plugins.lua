-- plugins.lua
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
  end
end
ensure_packer()

-- Packer setup for Telescope and its dependencies
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- Essential Plugins
  use 'nvim-treesitter/nvim-treesitter'  -- Syntax highlighting & parsing
  use 'hrsh7th/nvim-compe'              -- Auto-completion
  use 'neovim/nvim-lspconfig'           -- LSP Configuration

  -- Install Telescope and its dependency plenary.nvim
  use { 'nvim-telescope/telescope.nvim', requires = { 'nvim-lua/plenary.nvim' } }

  -- Install Catppuccin theme
  use { "catppuccin/nvim", as = "catppuccin" }

  -- Install Nvim Tree for file navigation
  use 'kyazdani42/nvim-tree.lua'         -- File explorer
end)

-- Configure Nvim Tree to open on the left side

