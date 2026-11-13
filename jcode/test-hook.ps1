# Manual hook test
$env:JCODE_HOOK_EVENT='turn_start'
$env:JCODE_HOOK_SESSION_ID='session-a'
$env:JCODE_HOOK_CWD='C:\repo'
$env:JCODE_HOOK_PAYLOAD='{"event":"turn_start","session_id":"session-a","cwd":"C:\\repo"}'
& (Join-Path $PSScriptRoot 'hook.ps1')
$env:JCODE_HOOK_EVENT='turn_end'
$env:JCODE_HOOK_STATUS='ok'
$env:JCODE_HOOK_LAST_ASSISTANT_TEXT='done'
$env:JCODE_HOOK_PAYLOAD='{"event":"turn_end","session_id":"session-a","cwd":"C:\\repo","status":"ok","last_assistant_text":"done"}'
& (Join-Path $PSScriptRoot 'hook.ps1')
Get-Content (Join-Path $env:LOCALAPPDATA 'OriginIslandJcode\events.jsonl')
