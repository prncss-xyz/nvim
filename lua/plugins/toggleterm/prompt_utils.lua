local M = {}

function M.with_prompt(cb)
	return function(input, prompt)
		input(prompt, function(contents)
			cb(contents, prompt)
		end)
	end
end

function M.create_task(remove, directory, project_root)
	return function(input, prompt)
		local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
		local current = vim.api.nvim_buf_get_name(0)
		local root = project_root or artifact_cwd.resolve(current) or vim.fs.root(0, ".git") or vim.uv.cwd()
		input(prompt, function(contents, using_selection)
			if remove and using_selection then
				vim.cmd.normal({ 'gv"_d', bang = true })
			end
			require("plugins.toggleterm.harness").create_artifact(contents, "task.md", root, directory)
		end)
	end
end

function M.sender(prefix)
	return function(input, prompt, new_agent)
		input(prompt, function(contents)
			local method = new_agent and "put_new" or "put"
			require("plugins.toggleterm.terms")[method]({ tag = "agent" }, (prefix or prompt) .. " " .. contents)
		end)
	end
end

return M
