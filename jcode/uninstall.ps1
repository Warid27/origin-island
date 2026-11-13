$ErrorActionPreference = 'Stop'
$answer = Read-Host 'Remove Origin Island for Jcode and its event log? [y/N]'
if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
$configDir = if ($env:JCODE_HOME) { $env:JCODE_HOME } else { Join-Path $HOME '.jcode' }
$configPath = Join-Path $configDir 'config.toml'
$root = Join-Path $env:LOCALAPPDATA 'OriginIslandJcode'
$hookPath = Join-Path $root 'hook.ps1'
if (Test-Path -LiteralPath $configPath) {
    $backup = "$configPath.bak-before-origin-island-uninstall-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $configPath -Destination $backup
    $config = [IO.File]::ReadAllText($configPath)
    foreach ($event in @('turn_start','turn_end','session_start','session_end')) {
        $pattern = '(?m)^\s*' + [regex]::Escape($event) + '\s*=.*(?:\r?\n|$)'
        $m = [regex]::Match($config,$pattern)
        if (-not $m.Success -or $m.Value -notlike "*$hookPath*") { continue }
        $rhs = ($m.Value.Trim() -split '=',2)[1].Trim()
        if ($rhs.StartsWith('[')) {
            $items = @($rhs.Trim('[',']').Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notlike "*$hookPath*" })
            if ($items.Count -eq 0) { $replacement = '' }
            elseif ($items.Count -eq 1) { $replacement = "$event = $($items[0])`r`n" }
            else { $replacement = "$event = [$($items -join ', ')]`r`n" }
        } else { $replacement = '' }
        $config = $config.Substring(0,$m.Index) + $replacement + $config.Substring($m.Index + $m.Length)
    }
    [IO.File]::WriteAllText($configPath,$config,(New-Object Text.UTF8Encoding $false))
}
if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
Write-Host 'Origin Island for Jcode removed. Other Jcode hooks and config have been preserved.'
