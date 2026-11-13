# UI loop. Existing singleton exits quickly; kill only this app by matching its exact script path.
$scriptPath = Join-Path $env:LOCALAPPDATA 'OriginIslandJcode\island.ps1'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*$scriptPath*" -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',$scriptPath)
Write-Output 'Jcode Island process restarted with compact pill UI.'
