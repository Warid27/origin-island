$ErrorActionPreference='Stop'
$base=Join-Path $env:TEMP ('origin-island-jcode-test-'+[guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA=Join-Path $base 'local'
$env:JCODE_HOME=Join-Path $base 'jcode'
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA,$env:JCODE_HOME | Out-Null
$config=Join-Path $env:JCODE_HOME 'config.toml'
[IO.File]::WriteAllText($config,"[hooks]`r`nturn_start = ['existing-hook']`r`npre_tool = 'do-not-change'`r`n",(New-Object Text.UTF8Encoding $false))
& (Join-Path $PSScriptRoot 'install.ps1')
& (Join-Path $PSScriptRoot 'install.ps1')
$text=[IO.File]::ReadAllText($config)
if ($text -notmatch "pre_tool = 'do-not-change'") { throw 'Existing unrelated config was lost' }
if ([regex]::Matches($text,'powershell\.exe').Count -ne 4) { throw "Expected 4 installed hook commands but found $([regex]::Matches($text,'powershell\.exe').Count)" }
$env:JCODE_HOOK_EVENT='turn_start';$env:JCODE_HOOK_SESSION_ID='session-a';$env:JCODE_HOOK_CWD='C:\repo';$env:JCODE_HOOK_SOURCE='chat'
$env:JCODE_HOOK_PAYLOAD='{"event":"turn_start","session_id":"session-a","cwd":"C:\\repo","source":"chat"}'
& (Join-Path (Join-Path $env:LOCALAPPDATA 'OriginIslandJcode') 'hook.ps1')
$env:JCODE_HOOK_EVENT='turn_end';$env:JCODE_HOOK_STATUS='ok';$env:JCODE_HOOK_LAST_ASSISTANT_TEXT='done'
$env:JCODE_HOOK_PAYLOAD='{"event":"turn_end","session_id":"session-a","cwd":"C:\\repo","status":"ok","last_assistant_text":"done"}'
& (Join-Path (Join-Path $env:LOCALAPPDATA 'OriginIslandJcode') 'hook.ps1')
$log=[IO.File]::ReadAllLines((Join-Path (Join-Path $env:LOCALAPPDATA 'OriginIslandJcode') 'events.jsonl'))
if ($log.Count -ne 2) { throw "Expected two event records, got $($log.Count)" }
Write-Output 'Installer idempotence, config preservation, and hook JSONL checks passed.'
Remove-Item -LiteralPath $base -Recurse -Force
