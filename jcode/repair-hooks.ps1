# Repair Jcode hook table placement; preserve a fresh backup.
$ErrorActionPreference='Stop'
$path=Join-Path $HOME '.jcode\config.toml'
$backup="$path.bak-origin-island-repair-$(Get-Date -Format yyyyMMddHHmmssfff)"
Copy-Item -LiteralPath $path -Destination $backup
$config=[IO.File]::ReadAllText($path)
$root=Join-Path $env:LOCALAPPDATA 'OriginIslandJcode'
$hookPath=Join-Path $root 'hook.ps1'
$command='powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$hookPath+'"'
$escaped=$command.Replace('\','\\').Replace('"','\"')
$hooks=[regex]::Match($config,'(?m)^\[hooks\]\s*(?:\r?\n|$)')
if(-not $hooks.Success){throw 'No [hooks] table in config'}
$after=$hooks.Index+$hooks.Length
$next=[regex]::Match($config.Substring($after),'(?m)^\[\[?[^\r\n]+\]\]?\s*(?:\r?\n|$)')
$end=if($next.Success){$after+$next.Index}else{$config.Length}
$section=$config.Substring($after,$end-$after)
# Remove any malformed copies of these four keys accidentally added later under other tables.
$tail=$config.Substring($end)
foreach($event in @('turn_start','turn_end','session_start','session_end')){
    $tail=[regex]::Replace($tail,'(?m)^\s*'+[regex]::Escape($event)+'\s*=.*(?:\r?\n|$)','')
    if($section -notmatch '(?m)^\s*'+[regex]::Escape($event)+'\s*='){
        $section += "$event = `"$escaped`"`r`n"
    }
}
[IO.File]::WriteAllText($path,$config.Substring(0,$after)+$section+$tail,(New-Object Text.UTF8Encoding $false))
Write-Output "Repaired hook section; backup: $backup"
