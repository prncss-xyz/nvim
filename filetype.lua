vim.filetype.add({
	filename = {
		[".stylelintrc"] = "json",
		[".htmlhintrc"] = "json",
		[".busted"] = "lua",
		[".luacov"] = "lua",
		[".envrc"] = "bash",
	},
	extension = { mdx = "mdx" },
	pattern = {
		[".*/waybar/config"] = "json",
		[".*/systemd/user/.*%.service"] = "toml",
		[".*/sway/.*"] = "sway",
	},
})
