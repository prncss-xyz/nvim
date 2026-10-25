local M = {}

local function windows_command(title, msg)
	-- Base64 keeps UTF-8 text and PowerShell metacharacters out of the script.
	local script = string.format(
		[[
$ErrorActionPreference = 'Stop'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastTemplateType, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$texts = $xml.GetElementsByTagName('text')
$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'))
$message = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'))
$texts.Item(0).AppendChild($xml.CreateTextNode($title)) | Out-Null
$texts.Item(1).AppendChild($xml.CreateTextNode($message)) | Out-Null
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
# Use the existing Windows PowerShell Start-menu identity.
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
]],
		vim.base64.encode(title),
		vim.base64.encode(msg)
	)
	return { "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script }
end

---Send a system notification or fallback to vim.notify
---@param msg string Notification message
---@param opts? { title?: string }
function M.notify(msg, opts)
	opts = opts or {}
	local title = opts.title or "Neovim"
	local uname = vim.uv.os_uname()
	local is_wsl = uname.sysname == "Linux" and uname.release:lower():find("microsoft", 1, true)
	local fallback = vim.schedule_wrap(function()
		vim.notify(msg, vim.log.levels.INFO, { title = title })
	end)

	local notify_cmd
	if is_wsl then
		if vim.fn.executable("powershell.exe") == 1 then
			notify_cmd = windows_command(title, msg)
		end
	elseif vim.fn.executable("osascript") == 1 then
		notify_cmd = {
			"osascript",
			"-e",
			"on run argv",
			"-e",
			"display notification (item 2 of argv) with title (item 1 of argv)",
			"-e",
			"end run",
			"--",
			title,
			msg,
		}
	elseif vim.fn.executable("notify-send") == 1 then
		notify_cmd = { "notify-send", "--", title, msg }
	end

	if notify_cmd then
		local ok = pcall(vim.system, notify_cmd, { detach = true, text = true }, function(result)
			if result.code ~= 0 then
				fallback()
			end
		end)
		if not ok then
			fallback()
		end
	else
		fallback()
	end
end

return M
