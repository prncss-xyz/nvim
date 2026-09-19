local M = {}
local path_utils = require("plugins.toggleterm.put.path")

local vars = {
	artifacts = function(ctx)
		local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
		local path = vim.fs.abspath(vim.fn.expand(ctx.path))
		local project_dir = artifact_cwd.resolve(path) or vim.fs.root(path, ".git")
		return path_utils.home_relative(artifact_cwd.for_checkout(assert(project_dir, "Artifact project not found")))
	end,
	column = function(ctx)
		return ctx.col
	end,
	directory = function(ctx)
		return vim.fn.fnamemodify(ctx.path, ":h")
	end,
	extension = function(ctx) return vim.fn.fnamemodify(ctx.path, ":e") end,
	filename = function(ctx)
		return vim.fn.fnamemodify(ctx.path, ":t")
	end,
	filetype = function(ctx)
		return vim.bo[ctx.bufnr].filetype
	end,
	row = function(ctx)
		return ctx.row
	end,
	nvim_messages = function()
		local messages = vim.split(vim.api.nvim_exec2("messages", { output = true }).output, "\n", { plain = true })
		while messages[#messages] == "" do
			table.remove(messages)
		end
		return messages[#messages] or ""
	end,
	selection = function(ctx)
		return ctx.selection or require("neoterm.put.selection").get_selection(ctx)
	end,
	path = require("neoterm.put.position").path,
	line = require("neoterm.put.position").row,
	position = require("neoterm.put.position").position,
	hunk = require("neoterm.put.hunk").hunk,
	project_diagnostic = require("neoterm.put.diagnostics").get_diagnostics("project"),
	file_diagnostic = require("neoterm.put.diagnostics").get_diagnostics("file"),
	next_diagnostic = require("neoterm.put.diagnostics").get_diagnostics("next"),
}

function M.capture(str)
	local invocation = {}
	if str:find("{selection}", 1, true) then
		invocation.selection = require("neoterm.put.selection").capture()
	end
	return invocation
end

function M.template(str)
	return function(query, instance)
		return (
			string.gsub(str, "{(.-)}", function(key)
				return assert(vars[key], "unknown template variable: " .. key)(query, instance)
			end)
		)
	end
end

return M
