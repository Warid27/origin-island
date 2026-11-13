$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'OriginIslandJcode'
$hookPath = Join-Path $root 'hook.ps1'
$configDir = if ($env:JCODE_HOME) { $env:JCODE_HOME } else { Join-Path $HOME '.jcode' }
$configPath = Join-Path $configDir 'config.toml'
New-Item -ItemType Directory -Force -Path $root,$configDir | Out-Null
$backup = $null
if (Test-Path -LiteralPath $configPath) {
    $backup = "$configPath.bak-origin-island-$(Get-Date -Format yyyyMMddHHmmssfff)"
    Copy-Item -LiteralPath $configPath -Destination $backup
    $config = [IO.File]::ReadAllText($configPath)
} else { $config = '' }
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
# Aset maskot/ikon/suara berada di root repo (satu level di atas folder jcode/).
$assets = Split-Path -Parent $source
Copy-Item (Join-Path $source 'hook.ps1') $root -Force
Copy-Item (Join-Path $source 'island.ps1') $root -Force
New-Item -ItemType Directory -Force -Path (Join-Path $root 'icons'),(Join-Path $root 'sounds') | Out-Null
Copy-Item (Join-Path $assets 'icons\ogin-pixel.json') (Join-Path $root 'icons') -Force
Copy-Item (Join-Path $assets 'icons\*.svg') (Join-Path $root 'icons') -Force
Copy-Item (Join-Path $assets 'sounds\*.mp3') (Join-Path $root 'sounds') -Force

$hookCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $hookPath + '"'
$escapedCmd = $hookCommand.Replace('\','\\').Replace('"','\"')
foreach ($event in @('turn_start','turn_end','session_start','session_end')) {
    $keyPattern = '(?m)^\s*' + [regex]::Escape($event) + '\s*='
    $m = [regex]::Match($config,$keyPattern)
    if ($m.Success) {
        $valueStart = $m.Index + $m.Length
        $end = $config.IndexOf("`n",$valueStart)
        if ($end -lt 0) { $end = $config.Length }
        $rhs = $config.Substring($valueStart,$end-$valueStart).Trim()
        $lineText = $config.Substring($m.Index,$end-$m.Index).Replace('\\','\').Replace('/','\')
        if (-not $lineText.Contains($hookPath)) {
            if ($rhs.StartsWith('[')) { $newRhs = $rhs.TrimEnd(']') + ', "' + $escapedCmd + '"]' }
            elseif ($rhs -and $rhs -ne '""') { $newRhs = '[' + $rhs + ', "' + $escapedCmd + '"]' }
            else { $newRhs = '"' + $escapedCmd + '"' }
            $config = $config.Substring(0,$valueStart) + ' ' + $newRhs + $config.Substring($end)
        }
    } else {
        $hooksMatch = [regex]::Match($config,'(?m)^\s*\[hooks\]\s*(?:\r?\n|$)')
        if ($hooksMatch.Success) {
            $insertAt = $config.Length
            $nextTable = [regex]::Match($config.Substring($hooksMatch.Index+$hooksMatch.Length),'(?m)^\s*\[\[?[^\r\n]+\]\]?\s*(?:\r?\n|$)')
            if ($nextTable.Success) { $insertAt = $hooksMatch.Index+$hooksMatch.Length+$nextTable.Index }
            $config = $config.Substring(0,$insertAt) + "$event = `"$escapedCmd`"`r`n" + $config.Substring($insertAt)
        } else {
            $config += "`r`n[hooks]`r`n$event = `"$escapedCmd`"`r`n"
        }
    }
}
[IO.File]::WriteAllText($configPath,$config,(New-Object Text.UTF8Encoding $false))
Write-Host "Origin Island for Jcode installed at $root"
if ($backup) { Write-Host "Config backup: $backup" }
Write-Host 'Restart Jcode to load the hooks.'
