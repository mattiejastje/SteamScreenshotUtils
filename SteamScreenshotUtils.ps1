Add-Type -AssemblyName System.Drawing

Function SteamCustomScreenshots {
Param(
  [CmdletBinding()]
  [String]$UserId = "",
  [Parameter(Mandatory)][String]$AppId,
  [Parameter(Mandatory)][ValidateScript({Test-Path $_})][String]$Path
)

Write-Host "Checking whether steam is running..."
[Int32]$steampid = (Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).pid
If ( $steampid -ne 0) {
  Write-Host "Steam is running, awaiting exit..."
  [String]$steamexe = "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamExe)".Replace("/", "\")
  & $steamexe -shutdown
  Do {
    Start-Sleep -s 1
    [Int32]$steampid = (Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).pid
  } While ( $steampid -ne 0)
}

Write-Host "Looking up steam path... " -NoNewline
[String]$steampath = "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamPath)".Replace("/", "\")
Write-Host $steampath

Write-Host "Looking up steam game with app id $AppId... " -NoNewline
[String]$game = (Get-ItemProperty "HKCU:\Software\Valve\Steam\Apps\$AppId" -ea Stop).Name
Write-Host $game

Write-Host "Looking up steam user id... " -NoNewline
If ($UserId -eq "") {
  [Object[]]$userids = @(Get-ChildItem HKCU:\Software\Valve\Steam\Users -Name -ea Stop)
  If ($userids.Length -eq 0) {
    throw "No user ids found"
  }
  If ($userids.Length -ne 1) {
    Write-Host $userids -Join ", "
    throw "Multiple user ids found, please specify -UserId"
  }
  $UserId = $userids[0]
}
Write-Host $UserId

$userdata = "$steampath\userdata\$userid"
Write-Host "Userdata: $userdata"
If ( -not ( Test-Path $userdata ) ) {
  throw "$userdata not found"
}

[String]$screenshots = "$userdata\760\remote\$AppId\screenshots"
Write-Host "Screenshots: $screenshots"
If ( -not ( Test-Path $screenshots ) ) {
  Write-Host "  Creating directory..."
  New-Item -Path $screenshots -ItemType "directory"
}

[String]$thumbnails = "$screenshots\thumbnails"
Write-Host "Thumbnails: $thumbnails"
If ( -not ( Test-Path $thumbnails ) ) {
  Write-Host "  Creating directory..."
  New-Item -Path $thumbnails -ItemType "directory"
}

Write-Host "Processing all *.jpg files from $Path"
Get-ChildItem -Path $Path -Filter *.jpg | ForEach-Object {
  Write-Host "Processing $_..."
  [String]$datestr = $_.LastWriteTime.ToString("yyyyMMddHHmmss")
  [Int32]$num = 1
  Do {
    $newname = "{0}_{1}.jpg" -f $datestr,$num
    $newscreenshot = "$screenshots\$newname"
    $num += 1
  } While ( Test-Path $newscreenshot )
  Write-Host "  Moving to $newscreenshot"
  Move-Item -Path $_ -Destination $newscreenshot
  Write-Host "  Loading image"
  $image = New-Object System.Drawing.Bitmap $newscreenshot
  $minsize = 112.49  # 200x112 for 16:9 pictures
  If ( $image.Width -Gt $image.Height ) {
    [Int32]$height = [math]::Min($minsize, $image.Height)
    [Int32]$width = $image.Width * $height / $image.Height
  } Else {
    [Int32]$width = [math]::Min($minsize, $image.Width)
    [Int32]$height = $image.Height * $width / $image.Width
  }
  Write-Host "  Generating $newthumbnail ($width x $height)"
  $newthumbnail = "$thumbnails\$newname"
  $size = New-Object System.Drawing.Size $width,$height
  $resized = New-Object System.Drawing.Bitmap $image,$size
  $resized.Save($newthumbnail, [System.Drawing.Imaging.ImageFormat]::Jpeg)
}
}

Function SteamLargeScreenshots {
$date = Get-Date
[String]$datestr = $date.ToString("yyyyMMddHHmmss")
[Int32]$num = 1

ForEach ($resolution In 26210175..26210225) {
  [Int64]$minwidth = [Math]::Sqrt($resolution) - 1
  [Int64]$maxwidth = 16000
  ForEach ($width In $minwidth..$maxwidth) {
    [Int64]$rem = -1
    $height = [Math]::DivRem($resolution, $width, [ref] $rem)
    If ($rem -eq 0) {
      Write-Host "$num -- $width x $height = $resolution"
      $image = New-Object System.Drawing.Bitmap $width,$height
      $filename = "{0}_{1}.jpg" -f $datestr,$num
      Write-Host "  $filename"
      [Int32]$fontsize = [Math]::Min($width, $height) / 2
      $font = new-object System.Drawing.Font "Ariel",$fontsize
      $brushBg = [System.Drawing.Brushes]::Yellow 
      $brushFg = [System.Drawing.Brushes]::Black 
      $graphics = [System.Drawing.Graphics]::FromImage($image) 
      $graphics.FillRectangle($brushBg,0,0,$image.Width,$image.Height) 
      $graphics.DrawString("$num",$font,$brushFg,($image.Width - 2 * $fontsize) / 2,($image.Height - 2 * $fontsize) / 2) 
      $graphics.Dispose()
      $jpegcodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
      $encparams = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $encquality = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 90)
      $encparams.Param[0] = $encquality
      $image.Save($filename, $jpegcodec, $encparams)
      $num += 1
      Break
    }
  }
}
}