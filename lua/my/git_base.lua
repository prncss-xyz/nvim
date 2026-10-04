local M = {}

local bases = {}

local function worktree_root(path)
	local root = vim.fn.system({ "git", "-C", path, "rev-parse", "--show-toplevel" })
	if vim.v.shell_error == 0 then
		return vim.fs.normalize(vim.trim(root))
	end
end

local function apply_to_buffer(bufnr, base)
	vim.api.nvim_buf_call(bufnr, function()
		if base == "HEAD" then
			require("gitsigns").reset_base()
		else
			require("gitsigns").change_base(base)
		end
	end)
end

function M.set(path, base)
	local root = worktree_root(path)
	if not root then
		return
	end
	bases[root] = base
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and worktree_root(vim.fs.dirname(name)) == root then
				apply_to_buffer(bufnr, base)
			end
		end
	end
end

function M.on_attach(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	local root = name ~= "" and worktree_root(vim.fs.dirname(name))
	if root and bases[root] then
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(bufnr) and bases[root] then
				apply_to_buffer(bufnr, bases[root])
			end
		end)
	end
end

return M
