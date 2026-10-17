Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'apps/desktop'
$size = 1024
$bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.Clear([System.Drawing.Color]::Transparent)
$rect = New-Object System.Drawing.Rectangle(32, 32, 960, 960)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$radius = 210
$path.AddArc(32, 32, $radius, $radius, 180, 90)
$path.AddArc(992-$radius, 32, $radius, $radius, 270, 90)
$path.AddArc(992-$radius, 992-$radius, $radius, $radius, 0, 90)
$path.AddArc(32, 992-$radius, $radius, $radius, 90, 90)
$path.CloseFigure()
$graphics.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 23, 27, 31))), $path)
$gem = [System.Drawing.Point[]]@([System.Drawing.Point]::new(512,142),[System.Drawing.Point]::new(804,400),[System.Drawing.Point]::new(512,882),[System.Drawing.Point]::new(220,400))
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,231,163,74)); $graphics.FillPolygon($brush, $gem); $brush.Dispose()
$rightFacet = [System.Drawing.Point[]]@([System.Drawing.Point]::new(512,142),[System.Drawing.Point]::new(804,400),[System.Drawing.Point]::new(512,882))
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,196,122,45)); $graphics.FillPolygon($brush, $rightFacet); $brush.Dispose()
$topFacet = [System.Drawing.Point[]]@([System.Drawing.Point]::new(512,142),[System.Drawing.Point]::new(804,400),[System.Drawing.Point]::new(512,400),[System.Drawing.Point]::new(220,400))
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,240,189,112)); $graphics.FillPolygon($brush, $topFacet); $brush.Dispose()
$monogram = [System.Drawing.Point[]]@([System.Drawing.Point]::new(430,345),[System.Drawing.Point]::new(646,345),[System.Drawing.Point]::new(646,433),[System.Drawing.Point]::new(520,433),[System.Drawing.Point]::new(520,517),[System.Drawing.Point]::new(628,517),[System.Drawing.Point]::new(628,605),[System.Drawing.Point]::new(520,605),[System.Drawing.Point]::new(520,760),[System.Drawing.Point]::new(430,760))
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,23,27,31)); $graphics.FillPolygon($brush, $monogram); $brush.Dispose()
$graphics.Dispose()
$path.Dispose()
$mac = Join-Path $out 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
foreach ($px in @(16,32,64,128,256,512,1024)) {
  $scaled = New-Object System.Drawing.Bitmap($px,$px,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($scaled)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($bitmap,0,0,$px,$px)
  $file = if ($px -eq 1024) {'app_icon_1024.png'} else {"app_icon_$px.png"}
  $scaled.Save((Join-Path $mac $file), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $scaled.Dispose()
}
$small = New-Object System.Drawing.Bitmap(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($small)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($bitmap,0,0,256,256)
$g.Dispose()
$hicon = $small.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hicon)
$stream = [System.IO.File]::Create((Join-Path $out 'windows/runner/resources/app_icon.ico'))
$icon.Save($stream); $stream.Dispose(); $icon.Dispose(); $small.Dispose(); $bitmap.Dispose()
