# Jcode lifecycle hook -> Origin Island. Must never write stdout or block/fail Jcode.
$ErrorActionPreference = 'Stop'
try {
    $root = Join-Path $env:LOCALAPPDATA 'OriginIslandJcode'
    $eventPath = Join-Path $root 'events.jsonl'
    $payload = $env:JCODE_HOOK_PAYLOAD
    if (-not $payload) {
        $payload = (@{
            event = $env:JCODE_HOOK_EVENT
            session_id = $env:JCODE_HOOK_SESSION_ID
            cwd = $env:JCODE_HOOK_CWD
            status = $env:JCODE_HOOK_STATUS
            last_assistant_text = $env:JCODE_HOOK_LAST_ASSISTANT_TEXT
            error = $env:JCODE_HOOK_ERROR
            source = $env:JCODE_HOOK_SOURCE
        } | ConvertTo-Json -Compress)
    }
    $e = $payload | ConvertFrom-Json
    $record = [ordered]@{
        ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        event = [string]$e.event
        session_id = [string]$e.session_id
        cwd = [string]$e.cwd
        status = [string]$e.status
        last_assistant_text = [string]$e.last_assistant_text
        error = [string]$e.error
        source = [string]$e.source
    }
    $line = ($record | ConvertTo-Json -Compress) + "`n"
    $bytes = (New-Object Text.UTF8Encoding $false).GetBytes($line)
    $mutex = New-Object Threading.Mutex($false, 'Local\OriginIslandJcodeEvents')
    [void]$mutex.WaitOne(2000)
    try {
    for ($i = 0; $i -lt 8; $i++) {
        try {
            $fs = [IO.File]::Open($eventPath, 'OpenOrCreate', 'Write', 'ReadWrite')
            try { [void]$fs.Seek(0, 'End'); $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            break
        } catch [IO.IOException] { Start-Sleep -Milliseconds 20 }
    }
    } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    if ($e.event -eq 'session_start') {
        $alive = Join-Path $root 'alive'
        $fresh = [IO.File]::Exists($alive) -and ([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($alive)).TotalSeconds -lt 10
        if (-not $fresh) { Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',(Join-Path $root 'island.ps1')) }
    }
} catch {}
exit 0
