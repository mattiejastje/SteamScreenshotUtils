Param(
  [CmdletBinding()]
  [String]$UserId = "",
  [Parameter(Mandatory)][String]$AppId,
  [Parameter(Mandatory)][ValidateScript({Test-Path $_})][String]$Path
)

Add-Type -AssemblyName System.Drawing

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
  If ( $image.Width -Gt $image.Height ) {
    [Int32]$width = [math]::Min(200, $image.Width)
    [Int32]$height = $image.Height * $width / $image.Width
  } Else {
    [Int32]$height = [math]::Min(200, $image.Height)
    [Int32]$width = $image.Width * $height / $image.Height
  }
  Write-Host "  Generating $newthumbnail ($width x $height)"
  $newthumbnail = "$thumbnails\$newname"
  $size = New-Object System.Drawing.Size $width,$height
  $resized = New-Object System.Drawing.Bitmap $image,$size
  $imageformat = "System.Drawing.Imaging.ImageFormat" -as [Type]
  $resized.Save($newthumbnail, $imageformat::Jpeg)
}
