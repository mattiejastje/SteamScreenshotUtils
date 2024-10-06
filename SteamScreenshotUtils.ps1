Add-Type -AssemblyName System.Drawing

Function Get-SteamActiveProcessPid {
  return [Int32](Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).pid
}

Function Get-SteamActiveProcessUserId {
  return [Int32](Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).ActiveUser
}

Function Get-SteamExe {
  return "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamExe)".Replace("/", "\")
}

Function Get-SteamPath {
  return "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamPath)".Replace("/", "\")
}

Function Get-SteamUserId {
  [Int32[]]$userids = @(Get-ChildItem HKCU:\Software\Valve\Steam\Users -Name -ea Stop)
  If ($userids.Length -Eq 0) {
    Write-Warning "No steam user ids found."
    return 0
  }
  If ($userids.Length -Ne 1) {
    Write-Warning "Multiple steam user ids ($($userids -Join ", ")) found."
    return 0
  }
  Write-Verbose "Steam user id found ($($userids[0]))."
  return $userids[0]
}

Function Stop-Steam {
  [CmdletBinding(SupportsShouldProcess)]
  Param()
  If ( Get-SteamActiveProcessPid -ne 0 ) {
    [String]$steamexe = Get-SteamExe
    if($PSCmdlet.ShouldProcess($steamexe)) {
      & $steamexe -shutdown
      Do {
        Write-Verbose "Awaiting steam shutdown..."
        Start-Sleep -S 1
      } While ( Get-SteamActiveProcessPid -Ne 0 )
    }
  }
}

Function Save-Jpeg {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory)][String]$FilePath,
    [Int32]$Quality = 90
  )
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -Eq "image/jpeg" }
  $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
  $Bitmap.Save($FilePath, $codec, $params)
}

Function Install-SteamScreenshotsDirectory {
  [CmdletBinding()]
  [OutputType([System.IO.DirectoryInfo])]
  Param(
    [Int32]$UserId = 0,
    [Parameter(Mandatory)][String]$AppId
  )
  If ( $UserId -Eq 0 ) { $UserId = Get-SteamUserId }
  If ( $UserId -Eq 0 ) {
    Throw "Start steam and run Get-SteamActiveProcessUserId to get your steam user id. Then rerun the script with the -UserId <...> parameter."
  }
  If ( -Not ( Test-Path "HKCU:\Software\Valve\Steam\Users\$UserId" ) ) {
    Throw "Cannot find steam user with id '$UserId' in registry."
  }
  If ( -Not ( Test-Path "HKCU:\Software\Valve\Steam\Apps\$AppId" ) ) {
    Throw "Cannot find steam app with id '$AppId' in registry."
  }
  [String]$userdata = "$(Get-SteamPath)\userdata\$UserId"
  If ( -Not ( Test-Path $userdata ) ) {
    Throw "Cannot find steam path '$userdata' because it does not exist."
  }
  [String]$screenshots = "$userdata\760\remote\$AppId\screenshots"
  [String]$thumbnails = "$screenshots\thumbnails"
  Write-Debug "Screenshots path: $screenshots"
  Write-Debug "Thumbnails path: $thumbnails"
  [System.IO.DirectoryInfo]$screenshotsitem = If ( -Not ( Test-Path $screenshots ) ) {
      Write-Verbose "Creating directory $screenshots"
      New-Item -Path $screenshots -ItemType "directory"
  }
  Else {
    Get-Item -Path $screenshots
  }
  If ( -not ( Test-Path $thumbnails ) ) {
    Write-Verbose "Creating directory $thumbnails"
    New-Item -Path $thumbnails -ItemType "directory"
  }
  return $screenshotsitem
}

Function Get-SteamScreenshotFilePath {
  [CmdletBinding()]
  [OutputType([String])]
  Param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$ScreenshotsDirectory,
    [Parameter(Mandatory)][DateTime]$DateTime
  )
  [String]$datestr = $DateTime.ToString("yyyyMMddHHmmss")
  [Int32]$num = 1
  Do {
    $name = "{0}_{1}.jpg" -f $datestr, $num
    $path = "$ScreenshotsDirectory\$name"
    $num += 1
  } While ( Test-Path $path )
  return $path
}

Function Install-SteamScreenshot {
  [CmdletBinding()]
  Param(
    [UInt32]$MaxWidth = 16000,  # https://github.com/awthwathje/SteaScree/issues/4
    [UInt32]$MaxHeight = 16000,  # https://github.com/awthwathje/SteaScree/issues/4
    [UInt32]$MaxResolution = 26210175,  # https://github.com/awthwathje/SteaScree/issues/4
    [UInt32]$ConversionQuality = 90,  # seems to be steam default according to "magick identify -verbose"
    [UInt32]$ThumbnailQuality = 95,  # seems to be steam default according to "magick identify -verbose"
    [UInt32]$ThumbnailSize = 144,  # gives 256x144 for 16:9 pictures
    [Int32]$UserId = 0,
    [Parameter(Mandatory)][String]$AppId,
    [Parameter(Mandatory)][System.IO.FileInfo]$FilePath
  )
  Begin {
    Stop-Steam
    $screenshots = Install-SteamScreenshotsDirectory -UserId $UserId -AppId $AppId
    $thumbnails = Get-Item "$screenshots/thumbnails"
  }
  Process {
    Write-Verbose "Processing $(FilePath.FullName)..."
    $newscreenshot = Get-SteamScreenshotFilePath -ScreenshotsDirectory $screenshots -DateTime $FilePath.LastWriteTime
    Write-Verbose "  Loading image"
    $image = New-Object System.Drawing.Bitmap $newscreenshot
    [Decimal]$scale = [Math]::Min(
      [Math]::Min( $MaxWidth / $image.Width, $MaxHeight / $image.Height),
      $MaxResolution / ($image.Width * $image.Height)
    )
    If ( $scale -Ge 1 ) {
      If  ( $FilePath.Extension -In @(".jpg", ".jpeg", ".jfif", ".pjpeg", ".pjp") ) {
        Write-Verbose "  Copying image to $newscreenshot"
        Copy-Item -Path $FilePath -Destination $newscreenshot
      }
      Else {
        Write-Verbose "  Saving image as $newscreenshot"
        Save-Jpeg -Bitmap $image -Path $newscreenshot -Quality $ConversionQuality
      }
    }
    Else {
      [Int32]$screenshotwidth = $scale * $image.Width
      [Int32]$screenshotheight = $scale * $image.Height
      Write-Verbose "  Saving resized image as $newscreenshot ($screenshotwidth x $screenshotheight)"
      $screenshotsize = New-Object System.Drawing.Size $screenshotwidth, $screenshotheight
      $screenshotresized = New-Object System.Drawing.Bitmap $image, $screenshotsize
      Save-Jpeg -Bitmap $screenshotresized -Path $newscreenshot -Quality $ConversionQuality
    }
    Write-Output $newscreenshot
    If ( $image.Width -Gt $image.Height ) {
      [Int32]$thumbnailheight = [Math]::Min($ThumbnailSize, $image.Height)
      [Int32]$thumbnailwidth = $image.Width * $thumbnailheight / $image.Height
    }
    Else {
      [Int32]$thumbnailwidth = [Math]::Min($ThumbnailSize, $image.Width)
      [Int32]$thumbnailheight = $image.Height * $thumbnailwidth / $image.Width
    }
    Write-Verbose "  Saving thumbnail as $newthumbnail ($thumbnailwidth x $thumbnailheight)"
    $newthumbnail = "$thumbnails\$newname"
    $size = New-Object System.Drawing.Size $thumbnailwidth, $thumbnailheight
    $resized = New-Object System.Drawing.Bitmap $image, $size
    Save-Jpeg -Bitmap $resized -Path $newthumbnail -Quality $ThumbnailQuality
    Write-Output $newthumbnail
  }
}

Function Install-SteamTestScreenshot {
  [CmdletBinding()]
  Param(
    [Int32]$UserId = 0,
    [Parameter(Mandatory)][Int32]$AppId,
    [Parameter(Mandatory)][UInt32]$Resolution
  )
  Begin {
    Stop-Steam
    $screenshots = Install-SteamScreenshotsDirectory -UserId $UserId -AppId $AppId
    $thumbnails = Get-Item "$screenshots/thumbnails"
    $newscreenshot = Get-SteamScreenshotFilePath -ScreenshotsDirectory $screenshots -DateTime $(Get-Date)
  }
  Process {
    [String]$text = $resolution.ToString()
    [Int64]$minwidth = [Math]::Sqrt($resolution) - 1
    [Int64]$maxwidth = 16000
    ForEach ($width In $minwidth..$maxwidth) {
      [Int64]$rem = -1
      $height = [Math]::DivRem($resolution, $width, [ref] $rem)
      If ($rem -eq 0) {
        $image = New-Object System.Drawing.Bitmap $width, $height
        [Int32]$fontsize = [Math]::Min($width, $height) / ($text.Length)
        $font = new-object System.Drawing.Font "Ariel", $fontsize
        $brushBg = [System.Drawing.Brushes]::Yellow
        $brushFg = [System.Drawing.Brushes]::Black
        $graphics = [System.Drawing.Graphics]::FromImage($image)
        $graphics.FillRectangle($brushBg, 0, 0, $image.Width, $image.Height)
        $graphics.DrawString($text, $font, $brushFg, ($image.Width - $text.Length * $fontsize) / 2, ($image.Height - $fontsize) / 2)
        $graphics.Dispose()
        Save-Jpeg -Bitmap $image -Path $newscreenshot -Quality 20
        Write-Output $newscreenshot
        Write-Verbose "  Saving thumbnail as $newthumbnail ($thumbnailwidth x $thumbnailheight)"
        $newthumbnail = "$thumbnails\$newname"
        $size = New-Object System.Drawing.Size 150, 150
        $resized = New-Object System.Drawing.Bitmap $image, $size
        Save-Jpeg -Bitmap $resized -Path $newthumbnail -Quality 20
        Write-Output $newthumbnail
        Break
      }
    }
  }
}