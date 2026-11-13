# Origin Island for Jcode (Windows)

A Windows-only notification pill driven by Jcode's official lifecycle observer hooks. This integration does not read provider credentials or usage/quota data and does not require WSL or Python.

## Features

- Live status across distinct Jcode sessions
- Completion notification with a short assistant response excerpt
- Error notification when a turn fails
- Working state keyed by session ID, ready for future agent-role/subagent attribution
- Lightweight hook process writing normalized JSONL events; UI reads them independently

Subagent-specific grouping is not yet implemented. Jcode's current stable observer hook payload carries session ID and working directory, not a guaranteed parent/child agent relation. Session state is already stored by ID so this can be extended when Jcode exposes reliable attribution.

## Install

From PowerShell in this checkout:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

It copies the Windows app to `%LOCALAPPDATA%\OriginIslandJcode`, backs up the active `config.toml`, and appends the observer hook to `turn_start`, `turn_end`, `session_start`, and `session_end`. It honors `JCODE_HOME` if set. Existing unrelated configuration and hooks are preserved. Restart Jcode after installation.

## Uninstall

Run `uninstall.ps1`, confirm the prompt, and it removes this integration's hooks and local app files. It backs up the config before changing it and preserves other hook commands. This does not remove any other user settings.

## Test

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test-integration.ps1` to check installer idempotence, preservation of an unrelated hook setting, and event serialization.

## Known limitations

- No usage quota or provider API calls.
- No subagent-specific grouping yet.
- Terminal focusing is not wired up; the pill currently notifies and lists separate sessions.
- The WPF interface must be exercised interactively on Windows to confirm final behavior.
# UI sizing

The island starts as a 240px content-sized capsule, centered at the top of the Windows work area. It expands to fit the hover panel or a notification, then collapses again. After updating `island.ps1`, run `restart-island.ps1` from PowerShell to restart only the Origin Island process.
