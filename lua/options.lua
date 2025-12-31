local deep_merge = require("my.tables").deep_merge
local indent = 2

deep_merge(vim, {
	bo = {
		expandtab = false,
		shiftwidth = indent,
		softtabstop = 0,
		tabstop = indent,
	},
	o = {
		winblend = 10,
		pumblend = 10,
		compatible = false,
		autoindent = true,
		autoread = true,
		autowriteall = true,
		backup = false,
		-- clipboard = 'unnamedplus',
		completeopt = "menuone,noselect",
		cursorline = true,
		expandtab = true,
		-- guifont = 'Fira Code:h8', 
		-- guifont = "Victor Mono:h9",
		hidden = true,
		ignorecase = true,
		incsearch = true,
		linebreak = true,
		mouse = "a",
		shiftwidth = indent,
		-- shortmess = vim.o.shortmess .. 'c',
		shortmess = "IFc",
		showmode = false,
		showtabline = 2,
		sidescrolloff = 5,
		scrolloff = 5,
		smartcase = true,
		smarttab = true,
		softtabstop = 0,
		splitbelow = true,
		splitright = true,
		swapfile = false,
		syntax = "on",
		tabstop = indent,
		termguicolors = true,
		updatetime = 300,
		undofile = true,
		-- timeoutlen = 300,
		wildignorecase = true,
		wildoptions = "pum",
		wrap = false,
		grepprg = [[rg --glob "!.git" --no-heading --vimgrep --follow $*]],
		-- bufhidden = "wipe", -- this option seams to crash auto_session
		title = true,
	},
	wo = {
		number = false,
		relativenumber = false,
		signcolumn = "yes",
	},
	opt = {
		clipboard = "unnamedplus",
		diffopt = "internal,filler,closeoff,algorithm:patience",
		cc = "+1",
		conceallevel = 2,
		exrc = false, -- allow project local vimrc files example .nvimrc see :h exrc
		fillchars = "eob: ", -- remove annoying tildes in gutter beneath file buffer
		paste = false,
		secure = true, -- disable autocmd etc for project local vimrc files
		sessionoptions = "curdir,folds,tabpages,winsize",
		splitkeep = "screen",
		spell = false,
		spelllang = "en_us,fr",
		spelloptions = "camel",
		--[[ titlestring = "%{v:lua.my_title()}", -- defined in `globals.lua` ]]
		virtualedit = "block", -- allow cursor to move where there is no text in visual block mode,
    guifont = 'mono:h11',
	},
	g = {
		neovide_cursor_vfx_mode = "torpedo",
		neovide_opacity = 0.8,
    neovide_scale_factor = 1.2,
		transparency = 1,
		mapleader = " ",
		maplocalleader = ",",
	},
	env = {},
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		-- I write poetry
		deep_merge(vim.opt_local, {
			breakindent = true,
			breakindentopt = "shift:2",
		})
		deep_merge(vim.o, {
			wrap = true,
		})
	end,
})
