# Origin Island - Jcode lifecycle notification pill (Windows only).
# Use Unicode escapes in XAML/text assignments to avoid Windows PowerShell's legacy script encoding corruption.
# UI intentionally consumes a normalized JSONL contract keyed by session_id.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$AppDir = $PSScriptRoot
$cfgPath = Join-Path $AppDir 'config.json'
if (-not (Test-Path $cfgPath)) { '{"notifySeconds":8,"sound":true,"hideOnFullscreen":true}' | Set-Content -Encoding UTF8 $cfgPath }
$cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json
$eventsPath = Join-Path $AppDir 'events.jsonl'
$script:events = @{}
$script:offset = if (Test-Path $eventsPath) { (Get-Item $eventsPath).Length } else { 0 }
$script:notifUntil = [datetime]::MinValue
$script:notif = $null
$script:hover = $false
$script:drag = $false
$script:sound = if ($null -eq $cfg.sound) { $true } else { [bool]$cfg.sound }
$script:iconFiles = Join-Path $AppDir 'icons\ogin-pixel.json'

function Log($msg) { try { Add-Content (Join-Path $AppDir 'island.log') ("{0:HH:mm:ss} {1}" -f (Get-Date),$msg) } catch {} }

# --- maskot "ogin" (icons/ogin-pixel.json) -----------------------------------
# JSON berisi palet + frame 16x16 per status (idle, thinking, working, waiting, done, error).
# Tiap frame diubah sekali saat start menjadi DrawingImage vektor yang dibekukan; animasinya
# cukup menukar gambar lewat mesin animasi WPF (tanpa kode per frame).
$Conv = New-Object System.Windows.Media.BrushConverter
$BrushCache = @{}
function Brush($hex) {
    $b = $BrushCache[$hex]
    if (-not $b) { $b = $Conv.ConvertFromString($hex); $b.Freeze(); $BrushCache[$hex] = $b }
    $b
}
$Ogin = @{}   # status -> @{ Frames = DrawingImage[]; Ms = int[] }
function Load-Ogin {
    $j = Get-Content -Raw -LiteralPath (Join-Path $AppDir 'icons\ogin-pixel.json') | ConvertFrom-Json
    $size = [int]$j.size
    $pal = @{}
    foreach ($p in $j.palette.PSObject.Properties) { $pal[[string]$p.Name] = Brush $p.Value }
    foreach ($st in $j.states.PSObject.Properties) {
        $frames = foreach ($fr in $st.Value.frames) {
            # Kelompokkan piksel per warna; piksel berurutan dalam satu baris digabung jadi satu persegi.
            $groups = @{}
            for ($y = 0; $y -lt $fr.Count; $y++) {
                $row = [string]$fr[$y]; $x = 0
                while ($x -lt $row.Length) {
                    $ch = [string]$row[$x]
                    if (-not $pal.ContainsKey($ch)) { $x++; continue }
                    $start = $x
                    while ($x -lt $row.Length -and [string]$row[$x] -ceq $ch) { $x++ }
                    if (-not $groups.ContainsKey($ch)) { $groups[$ch] = New-Object System.Windows.Media.GeometryGroup }
                    $groups[$ch].Children.Add((New-Object System.Windows.Media.RectangleGeometry([System.Windows.Rect]::new($start, $y, $x - $start, 1))))
                }
            }
            $dg = New-Object System.Windows.Media.DrawingGroup
            # Kotak transparan seukuran kanvas supaya semua frame berukuran sama (tidak "goyang").
            [void]$dg.Children.Add((New-Object System.Windows.Media.GeometryDrawing((Brush '#00000000'), $null, (New-Object System.Windows.Media.RectangleGeometry([System.Windows.Rect]::new(0, 0, $size, $size))))))
            foreach ($k in $groups.Keys) {
                [void]$dg.Children.Add((New-Object System.Windows.Media.GeometryDrawing($pal[$k], $null, $groups[$k])))
            }
            $img = New-Object System.Windows.Media.DrawingImage($dg)
            $img.Freeze()
            $img
        }
        $Ogin[[string]$st.Name] = @{ Frames = @($frames); Ms = @($st.Value.ms | ForEach-Object { [int]$_ }); Name = [string]$st.Value.name }
    }
}
try { Load-Ogin } catch { Log "maskot ogin gagal dimuat: $_" }

function New-Ogin([double]$size) {
    $im = New-Object System.Windows.Controls.Image
    $im.Width = $size; $im.Height = $size; $im.Stretch = 'Fill'
    [System.Windows.Media.RenderOptions]::SetEdgeMode($im, 'Aliased')   # piksel tetap tajam
    $im
}

# Jalankan animasi status pada sebuah Image (berulang terus).
function Set-OginState($im, $state) {
    $s = $Ogin[$state]
    if (-not $s) { $s = $Ogin['idle'] }
    if (-not $s) { return }
    $im.BeginAnimation([System.Windows.Controls.Image]::SourceProperty, $null)
    $im.Source = $s.Frames[0]
    if ($s.Frames.Count -lt 2) { return }
    $a = New-Object System.Windows.Media.Animation.ObjectAnimationUsingKeyFrames
    $t = 0
    for ($i = 0; $i -lt $s.Frames.Count; $i++) {
        $kt = [System.Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds($t))
        [void]$a.KeyFrames.Add((New-Object System.Windows.Media.Animation.DiscreteObjectKeyFrame($s.Frames[$i], $kt)))
        $t += $s.Ms[[math]::Min($i, $s.Ms.Count - 1)]
    }
    $a.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds($t))
    $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $a.SetValue([System.Windows.Media.Animation.Timeline]::DesiredFrameRateProperty, 20)
    $im.BeginAnimation([System.Windows.Controls.Image]::SourceProperty, $a)
}

function Read-Events {
    if (-not (Test-Path $eventsPath)) { return }
    $f = Get-Item $eventsPath
    if ($f.Length -lt $script:offset) { $script:offset = 0 }
    if ($f.Length -eq $script:offset) { return }
    $fs = [IO.File]::Open($eventsPath,'Open','Read','ReadWrite,Delete')
    try { [void]$fs.Seek($script:offset,'Begin'); $b = New-Object byte[] ($fs.Length-$script:offset); $n=$fs.Read($b,0,$b.Length) } finally { $fs.Dispose() }
    if ($n -lt 1) { return }
    $end = [Array]::LastIndexOf($b,[byte]10,$n-1)
    if ($end -lt 0) { return }
    $script:offset += $end+1
    foreach ($line in ([Text.Encoding]::UTF8.GetString($b,0,$end) -split "`n")) {
        try {
            $e = $line | ConvertFrom-Json
            if (-not $e.session_id) { continue }
            $id = [string]$e.session_id
            if (-not $script:events.ContainsKey($id)) { $script:events[$id] = @{ session_id=$id; cwd=''; project='jcode'; state='idle'; updated=Get-Date } }
            $s=$script:events[$id]; $s.updated=Get-Date; if ($e.cwd) {$s.cwd=[string]$e.cwd; $s.project=Split-Path $s.cwd -Leaf}
            switch ([string]$e.event) {
                'session_start' { $s.state='idle' }
                'turn_start' { $s.state='working' }
                'turn_end' {
                    if ($e.status -eq 'error') { $s.state='error'; $body=[string]$e.error; if (-not $body) {$body='The Jcode turn failed.'}; Show-Notice error 'Jcode failed' $s $body }
                    else { $s.state='done'; $body=[string]$e.last_assistant_text; if (-not $body) {$body=[string]$e.text}; Show-Notice done 'Jcode finished' $s $body }
                }
                'session_end' { $script:events.Remove($id) }
            }
        } catch { Log "event parse failure: $_" }
    }
    Refresh-Compact
}

$mutex=$false
$script:mutex=New-Object Threading.Mutex($true,'Local\OriginIslandJcode',[ref]$mutex)
if (-not $mutex) { exit }
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Origin Island for Jcode" SizeToContent="WidthAndHeight" Width="Auto" Height="Auto" WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" ShowActivated="False" ResizeMode="NoResize" Left="0" Top="0">
<Grid><Border x:Name="Pill" Background="#F20B0B0D" BorderBrush="#35FFFFFF" BorderThickness="1" CornerRadius="23" Margin="0,6,0,0" Width="220"><StackPanel>
<Grid Height="40" Margin="13,0,10,0"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><Border x:Name="IconBadge" Width="28" Height="28" CornerRadius="14" Background="#1C1C1E" VerticalAlignment="Center"><Image x:Name="Mascot" Width="24" Height="24" Stretch="Fill" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock x:Name="Status" Grid.Column="1" Text="Jcode &#xB7; Siaga" Foreground="#F5F5F7" FontSize="12" FontWeight="SemiBold" Margin="9,0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/><Button x:Name="Close" Grid.Column="2" Content="&#x00D7;" Width="24" Height="24" Foreground="#A1A1A6" Background="Transparent" BorderThickness="0" FontSize="18"/></Grid>
<StackPanel x:Name="Panel" Visibility="Collapsed" Margin="18,6,18,16"><TextBlock x:Name="Title" Foreground="#F5F5F7" FontSize="14" FontWeight="SemiBold"/><TextBlock x:Name="Project" Foreground="#A1A1A6" FontSize="11" Margin="0,3,0,0"/><TextBlock x:Name="Body" Foreground="#D1D1D6" FontSize="12" TextWrapping="Wrap" MaxHeight="66" Margin="0,8,0,0"/><TextBlock x:Name="Sessions" Foreground="#8E8E93" FontSize="10.5" TextWrapping="Wrap" Margin="0,10,0,0"/></StackPanel>
</StackPanel></Border></Grid></Window>
'@
$win=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
foreach($name in 'Pill','IconBadge','Mascot','Status','Close','Panel','Title','Project','Body','Sessions'){Set-Variable -Name $name -Value $win.FindName($name) -Scope Script}
function Set-MascotMode($mode) {
    if ($mode -eq $script:mascotMode) { return }
    $script:mascotMode = $mode
    Set-OginState $script:Mascot $mode
}
$script:mascotMode = ''
# Mode maskot: idle, thinking, working, waiting, done, error (lihat ogin-pixel.json).
$script:Mascot = $Mascot
Set-MascotMode 'idle'
function Refresh-Compact {
    $all=@($script:events.Values); $work=@($all | Where-Object state -eq 'working'); $errors=@($all | Where-Object state -eq 'error')
    # Saat bekerja: 'working' bila ada alat yang sedang berjalan, selain itu 'thinking'.
    $workMode = if (@($work | Where-Object { $_.activity -eq 'tool' }).Count -gt 0) { 'working' } else { 'thinking' }
    $n = $script:notif

    if ($n -and $n.kind -eq 'error') { $mode = 'error'; $text = 'Gagal · ' + $n.project }
    elseif ($errors.Count -gt 0) { $mode = 'error'; $text = 'Gagal ' + [char]0x00B7 + ' ' + $errors[0].project }
    elseif ($work.Count -gt 1) { $mode = $workMode; $text = "$($work.Count) sesi beraksi" }
    elseif ($work.Count -eq 1) { $mode = $workMode; $text = 'Beraksi ' + [char]0x00B7 + ' ' + $work[0].project }
    elseif ($n -and $n.kind -eq 'done') { $mode = 'done'; $text = 'Selesai ' + [char]0x00B7 + ' ' + $n.project }
    elseif ($all.Count) { $mode = 'idle'; $text = 'Siaga ' + [char]0x00B7 + ' ' + $all.Count + ' sesi' }
    else { $mode = 'idle'; $text = 'Jcode ' + [char]0x00B7 + ' Siaga' }

    Set-MascotMode $mode
    $Status.Text = $text
    $IconBadge.Background = '#1C1C1E'
    $Sessions.Text=($all | Sort-Object updated -Descending | Select-Object -First 8 | ForEach-Object { $state=if($_.state -eq 'working'){'Bekerja'}else{'Siaga'}; "$($_.project) · $state" }) -join "`n"
}
function Show-Notice($kind,$title,$session,$body){$script:notif=@{kind=$kind;title=$title;project=$session.project;session_id=$session.session_id};$script:notifUntil=(Get-Date).AddSeconds([double]$cfg.notifySeconds);$script:Title.Text=$title;$script:Project.Text=$session.project;if($body.Length -gt 280){$body=$body.Substring(0,280)+'…'};$script:Body.Text=$body;$script:Panel.Visibility='Visible';$script:win.Visibility='Visible';Update-WindowSize;if($script:sound){try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}}}
$script:win=$win
function Update-WindowSize {
    $script:Pill.Measure((New-Object Windows.Size(220,[double]::PositiveInfinity)))
    $w=220
    $h=[math]::Ceiling($script:Pill.DesiredSize.Height)+6
    $script:win.Width=$w; $script:win.Height=$h
}
function Place-Window {
    $area=[Windows.SystemParameters]::WorkArea
    $script:win.Left=$area.Left+($area.Width-$script:win.Width)/2
    $script:win.Top=$area.Top+4
}
$Close.Add_Click({$win.Close()})
$win.Add_MouseEnter({$script:hover=$true;$script:Panel.Visibility='Visible';$script:Sessions.Visibility='Visible';Update-WindowSize})
$win.Add_MouseLeave({$script:hover=$false;if(-not $script:notif){$script:Panel.Visibility='Collapsed';Update-WindowSize}})
$Pill.Add_MouseLeftButtonDown({$script:drag=$true;$win.DragMove();$script:drag=$false})
$timer=New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromMilliseconds(350);$timer.Add_Tick({try{Read-Events;try{[IO.File]::WriteAllText((Join-Path $AppDir 'alive'),[string](Get-Date).Ticks)}catch{};if($script:notif -and (Get-Date) -ge $script:notifUntil -and -not $script:hover){$script:notif=$null;$script:Panel.Visibility='Collapsed';Refresh-Compact;Update-WindowSize};foreach($k in @($script:events.Keys)){if(((Get-Date)-$script:events[$k].updated).TotalMinutes -gt 30){$script:events.Remove($k)}}}catch{Log "tick: $_"}})
$win.Add_Loaded({Update-WindowSize;Place-Window;try{[IO.File]::WriteAllText((Join-Path $AppDir 'alive'),[string](Get-Date).Ticks)}catch{};$timer.Start();Refresh-Compact})
$win.Add_Closed({$timer.Stop();try{$script:mutex.ReleaseMutex()}catch{}})
Log 'Jcode island started'
try{$win.Show();[Windows.Threading.Dispatcher]::Run()}catch{Log "UI failure: $_"}
