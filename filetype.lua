vim.filetype.add({
	filename = {
		[".eslintrc"] = "json",
		[".stylelintrc"] = "json",
		[".htmlhintrc"] = "json",
		[".busted"] = "lua",
		[".luacov"] = "lua",
		[".envrc"] = "bash",
	},
	extension = {
		mdx = "markdown",
	},
	pattern = {
		[".*/%.config/waybar/config"] = "json",
		[".*/%.config/systemd/user/.*%.service"] = "toml",
		[".*/sway/.*"] = "sway",
	},
})
