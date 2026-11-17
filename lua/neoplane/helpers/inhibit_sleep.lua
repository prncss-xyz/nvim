local M = {}

local inhibitor
local working = false

local function command()
	local uname = vim.uv.os_uname()
	if uname.sysname == "Darwin" then
		-- caffeinate prevents display, idle-system, disk, and AC-powered system sleep.
		-- macOS does not allow software to reliably override clamshell sleep.
		return { "caffeinate", "-dims" }
	end

	if uname.sysname == "Linux" and uname.release:lower():find("microsoft", 1, true) then
		return {
			"powershell.exe",
			"-NoProfile",
			"-NonInteractive",
			"-Command",
			[[
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SleepInhibitor {
  [DllImport("kernel32.dll")]
  public static extern uint SetThreadExecutionState(uint flags);
}
'@
[SleepInhibitor]::SetThreadExecutionState(0x80000003) | Out-Null
Wait-Event
]],
		}
	end
end

local function stop()
	if inhibitor then
		inhibitor:kill(15)
		inhibitor = nil
	end
end

function M.set(value)
	working = value
	if not value then
		stop()
		return
	end
	if inhibitor then
		return
	end

	local cmd = command()
	if not cmd then
		return
	end
	local process
	process = vim.system(cmd, { text = true }, function(result)
		vim.schedule(function()
			if inhibitor == process then
				inhibitor = nil
				if working and result.code ~= 0 then
					vim.notify("Unable to inhibit system sleep: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
				end
			end
		end)
	end)
	inhibitor = process
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = stop,
})

return M
