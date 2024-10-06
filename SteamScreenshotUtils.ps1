Add-Type -AssemblyName System.Drawing

<#
.SYNOPSIS
Get the process id of the currently running steam executable.
.DESCRIPTION
Fetches the steam process id using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The steam process id, or 0 if steam is not running.
#>
Function Get-SteamActiveProcessPid {
  return [Int32](Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).pid
}

<#
.SYNOPSIS
Get the user id of the user currently logged into steam.
.DESCRIPTION
Fetches the active user id using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The active user id, or 0 if steam is not running.
#>
Function Get-SteamActiveProcessUserId {
  If ( $(Get-SteamActiveProcessPid) -Eq 0 ) {
    Write-Warning "Steam is not running, no active user."
  }
  return [Int32](Get-ItemProperty HKCU:\Software\Valve\Steam\ActiveProcess -ea Stop).ActiveUser
}

<#
.SYNOPSIS
Get the path to the steam executable.
.DESCRIPTION
Fetches the path using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The path to the steam executable.
#>
Function Get-SteamExe {
  return "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamExe)".Replace("/", "\")
}

<#
.SYNOPSIS
Get the steam installation directory.
.DESCRIPTION
Fetches the directory using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The path to the steam installation directory.
#>
Function Get-SteamPath {
  return "$((Get-ItemProperty HKCU:\Software\Valve\Steam\ -ea Stop).SteamPath)".Replace("/", "\")
}

<#
.SYNOPSIS
Find steam user id in case there is exactly one user using steam.
.DESCRIPTION
Fetches the user id using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The steam user id, or 0 if there are no or multiple steam users.
#>
Function Find-SteamUserId {
  [CmdletBinding()]
  [OutputType([Int32])]
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

<#
.SYNOPSIS
Confirm and return a valid steam user id.
.DESCRIPTION
Attempts to find user id if none is specified.
Checks the user id against the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.PARAMETER UserId
Steam user id to confirm, or 0 to try to find it automatically.
.OUTPUTS
A valid steam user id.
#>
Function Confirm-SteamUserId {
  [CmdletBinding()]
  [OutputType([Int32])]
  Param([Int32]$UserId = 0)
  If ( $UserId -Eq 0 ) {
    $UserId = Get-SteamActiveProcessUserId
  }
  If ( $UserId -Eq 0 ) {
    $UserId = Find-SteamUserId
  }
  If ( $UserId -Eq 0 ) {
    Throw "Start steam and run Get-SteamActiveProcessUserId to get your steam user id. Then rerun the script with the -UserId <...> parameter."
  }
  If ( -Not ( Test-Path "HKCU:\Software\Valve\Steam\Users\$UserId" ) ) {
    Throw "Cannot find steam user with id '$UserId' in registry."
  }
  return $UserId
}

<#
.SYNOPSIS
Find steam app id by app name.
.DESCRIPTION
Searches for the app id using the registry.
Beware that some apps do not store their name in the registry.
For those, you will need to find the app id via the steam store.
Stops if registry key is not present (for instance, if steam is not installed).
Use the -Verbose flag to see the full names of the apps that have been matched.
.PARAMETER Regex
Regular expression to match the name to.
.OUTPUTS
All app ids for whose app name matches the regular expression.
#>
Function Find-SteamAppIdByName {
  [CmdletBinding()]
  Param([Parameter(Mandatory)][String]$Regex)
  Get-ChildItem HKCU:\Software\Valve\Steam\Apps -ea Stop | ForEach-Object {
    $property = Get-ItemProperty $_.PSPath
    If ( $property.Name -Match $Regex) {
      Write-Verbose $name
      return [Int32]($property.PSChildName)
    }
  }
}

<#
.SYNOPSIS
Confirm steam app id.
.DESCRIPTION
Checks the app id against the registry.
Stops if registry key is not present (for instance, if steam is not installed).
#>
Function Confirm-SteamAppId {
  [CmdletBinding()]
  Param([Parameter(Mandatory)][Int32]$AppId)
  If ( -Not ( Test-Path "HKCU:\Software\Valve\Steam\Apps\$AppId" ) ) {
    Throw "Cannot find steam app with id '$AppId' in registry."
  }
}

<#
.SYNOPSIS
Stop steam.
.DESCRIPTION
Stop steam and wait until the process is no longer running.
#>
Function Stop-Steam {
  [CmdletBinding(SupportsShouldProcess)]
  Param()
  If ( $(Get-SteamActiveProcessPid) -Ne 0 ) {
    [String]$steamexe = Get-SteamExe
    if($PSCmdlet.ShouldProcess($steamexe)) {
      & $steamexe -shutdown
      Do {
        Write-Verbose "Awaiting steam shutdown..."
        Start-Sleep -S 1
      } While ( $(Get-SteamActiveProcessPid) -Ne 0 )
    }
  }
}

<#
.SYNOPSIS
Start steam.
.DESCRIPTION
Start steam and wait until the process is running.
#>
Function Start-Steam {
  [CmdletBinding(SupportsShouldProcess)]
  Param()
  If ( $(Get-SteamActiveProcessPid) -Eq 0 ) {
    [String]$steamexe = Get-SteamExe
    if($PSCmdlet.ShouldProcess($steamexe)) {
      & $steamexe
      Do {
        Write-Verbose "Awaiting steam start..."
        Start-Sleep -S 1
      } While ( $(Get-SteamActiveProcessPid) -Eq 0 )
    }
  }
}

<#
.SYNOPSIS
Save bitmap as jpeg file.
.DESCRIPTION
Save bitmap as jpeg file compressed with the given quality.
.PARAMETER Bitmap
The bitmap.
.PARAMETER Path
Path to the file to be saved.
.PARAMETER Quality
Compression quality, between 0 and 100.
0 has smallest filesize and worst quality,
whilst 100 has largest filesize and best quality.
#>
Function Save-BitmapAsJpeg {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory)][String]$Path,
    [Int32]$Quality = 90
  )
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -Eq "image/jpeg" }
  $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
  $Bitmap.Save($Path, $codec, $params)
}

<#
.SYNOPSIS
Install a steam screenshots directory for given user and app.
.DESCRIPTION
Directory for screenshots and thumbnails will be created if they do not exist.
.PARAMETER UserId
The steam user id.
.PARAMETER AppId
The steam app id.
.OUTPUTS
Screenshots directory.
#>
Function Install-SteamScreenshotsDirectory {
  [CmdletBinding()]
  [OutputType([System.IO.DirectoryInfo])]
  Param(
    [Int32]$UserId = 0,
    [Parameter(Mandatory)][Int32]$AppId
  )
  $UserId = Confirm-SteamUserId $UserId
  Confirm-SteamAppId $AppId
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

<#
.SYNOPSIS
Find an unused steam screenshot file path.
.DESCRIPTION
Converts the given date and time to the format that steam expects.
Then, tests if the path already exists,
incrementing the counter part of the screenshot name until a non-existing path is found.
.PARAMETER ScreenshotsDirectory
A steam screenshots directory.
.PARAMETER DateTime
The date and time of the screenshot to be created.
.OUTPUTS
Unused path to a screenshot using steam screenshot naming conventions.
#>
Function Find-SteamNonExistingScreenshotPath {
  [CmdletBinding()]
  [OutputType([String])]
  Param(
    [Parameter(Mandatory)][System.IO.DirectoryInfo]$ScreenshotsDirectory,
    [Parameter(Mandatory)][DateTime]$DateTime
  )
  [String]$datestr = $DateTime.ToString("yyyyMMddHHmmss")
  [Int32]$num = 1
  Do {
    $name = "{0}_{1}.jpg" -f $datestr, $num++
    $path = "$ScreenshotsDirectory\$name"
  } While ( Test-Path $path )
  return $path
}

<#
.SYNOPSIS
Install an image file into the steam screenshots folder for a given user and app.
.DESCRIPTION
Inspects the image file and preforms any conversions required.
If the image is valid for steam
(i.e. not exceeding dimension and resolution requirements, and jpeg),
the image will be simply copied.
Otherwise, the image will be converted to the correct steam format.
.PARAMETER MaxWidth
Maximum width of the installed image.
Steam accepts up to 16000 for upload so this is the default.
You can adjust this if you want higher dimensions in your screenshots library,
however you will be unable to upload these.
.PARAMETER MaxHeight
Maximum height of the installed image.
Steam accepts up to 16000 for upload so this is the default.
You can adjust this if you want higher dimensions in your screenshots library,
however you will be unable to upload these.
.PARAMETER MaxResolution
Maximum resolution (width times height) of the installed image.
Steam accepts up to about 26210175 for upload so this is the default.
You can adjust this if you want higher resolutions in your screenshots library,
however you will be unable to upload these.
.PARAMETER ConversionQuality
Jpeg quality of the image, if it needs to be converted due to not incorrect format.
Steam takes screenshots with quality 90, and this is the default.
.PARAMETER ThumbnailQuality
Jpeg quality of the generated thumbnail.
Steam creates thumbnails with quality 95, and this is the default.
.PARAMETER ThumbnailSize
Size of thumbnails.
The generated thumbnails will a width or height equal to this number,
whichever is smallest.
Defaults to 144.
Note that steam creates thumbnails with a fixed width of 200,
but this sometimes leads to extremely pixelated thumbnails at very high aspect ratios.
We use a more sensible algorithm for determining thumbnail dimensions.
.PARAMETER UserId
The steam user id.
.PARAMETER AppId
The steam app id.
.PARAMETER Path
Path to the image to install.
.OUTPUTS
Paths of the generated screenshot and thumbnail.
#>
Function Install-SteamScreenshot {
  [CmdletBinding()]
  [OutputType([String[]])]
  Param(
    [Int32]$MaxWidth = 16000,  # https://github.com/awthwathje/SteaScree/issues/4
    [Int32]$MaxHeight = 16000,  # https://github.com/awthwathje/SteaScree/issues/4
    [Int32]$MaxResolution = 26210175,  # https://github.com/awthwathje/SteaScree/issues/4
    [Int32]$ConversionQuality = 90,  # seems to be steam default according to "magick identify -verbose"
    [Int32]$ThumbnailQuality = 95,  # seems to be steam default according to "magick identify -verbose"
    [Int32]$ThumbnailSize = 144,  # gives 256x144 for 16:9 pictures
    [Int32]$UserId = 0,
    [Parameter(Mandatory)][String]$AppId,
    [Parameter(Mandatory)][String]$Path
  )
  Begin {
    Stop-Steam
    [System.IO.DirectoryInfo]$screenshots = Install-SteamScreenshotsDirectory -UserId $UserId -AppId $AppId
    [System.IO.DirectoryInfo]$thumbnails = Get-Item "$screenshots/thumbnails" -ea Stop
  }
  Process {
    [System.IO.FileInfo]$file = Get-Item -Path $Path
    Write-Verbose "Loading image"
    $image = New-Object System.Drawing.Bitmap $FilePath
    $newscreenshot = Find-SteamNonExistingScreenshotPath -ScreenshotsDirectory $screenshots -DateTime $file.LastWriteTime
    $scale = [Math]::Min(
      [Math]::Min( $MaxWidth / $image.Width, $MaxHeight / $image.Height),
      $MaxResolution / ($image.Width * $image.Height)
    )
    If ( $scale -Ge 1 ) {
      If  ( $FilePath.Extension -In @(".jpg", ".jpeg", ".jfif", ".pjpeg", ".pjp") ) {
        Write-Verbose "Copying image to $newscreenshot"
        Copy-Item -Path $FilePath -Destination $newscreenshot
      }
      Else {
        Write-Verbose "Saving image as $newscreenshot"
        Save-BitmapAsJpeg -Bitmap $image -Path $newscreenshot -Quality $ConversionQuality
      }
    }
    Else {
      [Int32]$screenshotwidth = $scale * $image.Width
      [Int32]$screenshotheight = $scale * $image.Height
      Write-Verbose "Saving resized image as $newscreenshot ($screenshotwidth x $screenshotheight)"
      $screenshotsize = New-Object System.Drawing.Size $screenshotwidth, $screenshotheight
      $screenshotresized = New-Object System.Drawing.Bitmap $image, $screenshotsize
      Save-BitmapAsJpeg -Bitmap $screenshotresized -Path $newscreenshot -Quality $ConversionQuality
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
    Write-Verbose "Saving thumbnail as $newthumbnail ($thumbnailwidth x $thumbnailheight)"
    $newthumbnail = "$thumbnails\$newname"
    $size = New-Object System.Drawing.Size $thumbnailwidth, $thumbnailheight
    $resized = New-Object System.Drawing.Bitmap $image, $size
    Save-BitmapAsJpeg -Bitmap $resized -Path $newthumbnail -Quality $ThumbnailQuality
    Write-Output $newthumbnail
  }
}

<#
.SYNOPSIS
Find a size for given resolution.
.DESCRIPTION
Find a size that matches exactly, or if not possible, closely, the given resolution.
Meant to assist with testing steam upload limits.
.PARAMETER MaxWidth
The maximum width to consider.
.PARAMETER Resolution
The desired resolution.
.OUTPUTS
Size (i.e. width and height).
#>
Function Find-SizeForResolution {
  [CmdletBinding()]
  [OutputType([System.Drawing.Size])]
  Param(
    [Int32]$MaxWidth = 16000,
    [Int32]$Resolution
  )
  [Int32]$minwidth = [Math]::Sqrt($Resolution)
  ForEach ($width In $minwidth..$MaxWidth) {
    [Int32]$rem = -1
    $height = [Math]::DivRem($Resolution, $width, [ref] $rem)
    If ($rem -eq 0) {
      $size = New-Object System.Drawing.Size $width, $height
      return $size
    }
  }
  Write-Warning "No size for resolution $Resolution with width between $minwidth and $MaxWidth."
  $height = [Math]::DivRem($Resolution, $minwidth, [ref] $null)
  $size = New-Object System.Drawing.Size $minwidth, $height
  return $size
}

<#
.SYNOPSIS
Save test jpeg file for given size.
.DESCRIPTION
For identification, the image shows its size and resolution.
.PARAMETER Quality
The jpeg quality. Defaults at 0 for minimal size.
.PARAMETER Size
Desired file size.
.PARAMETER Path
Name of the file to save.
.OUTPUTS
The saved file path.
#>
Function Save-TestJpegForSize {
  [CmdletBinding()]
  [OutputType([String])]
  Param(
    [Int32]$Quality = 0,
    [Parameter(Mandatory)][System.Drawing.Size]$Size,
    [Parameter(Mandatory)][String]$Path
  )
  [String]$text = "{0}x{1}`n{2}" -f $Size.width, $Size.height, ( $Size.width * $Size.height )
  [Int32]$textlength = ("{0}x{1}" -f $Size.width, $Size.height).Length
  $image = New-Object System.Drawing.Bitmap $Size.width, $Size.height
  [Int32]$fontsize = [Math]::Min($Size.width, $Size.height) / $textlength
  $font = New-Object System.Drawing.Font "Ariel", $fontsize
  $brushbg = [System.Drawing.Brushes]::White
  $brushfg = [System.Drawing.Brushes]::Black
  $graphics = [System.Drawing.Graphics]::FromImage($image)
  $graphics.FillRectangle($brushbg, 0, 0, $image.Width, $image.Height)
  $graphics.DrawString($text, $font, $brushfg, ($image.Width - $textlength * $fontsize) / 2, ($image.Height - 2 * $font.Height) / 2)
  $graphics.Dispose()
  Save-BitmapAsJpeg -Bitmap $image -Path $Path -Quality $Quality
  Write-Output $Path
}

<#
.SYNOPSIS
Save test jpeg file for given resolution, if possible.
.DESCRIPTION
For identification, the image shows its size and resolution.
.PARAMETER Quality
The jpeg quality. Defaults at 0 for minimal size.
.PARAMETER MaxWidth
The maximum width to consider.
.PARAMETER Resolution
The desired resolution.
.PARAMETER Path
Name of the file to save.
.OUTPUTS
The saved file path if resolution was possible, otherwise nothing.
#>
Function Save-TestJpegForResolution {
  [CmdletBinding()]
  [OutputType([String])]
  Param(
    [Int32]$Quality = 0,
    [Int32]$MaxWidth = 16000,
    [Parameter(Mandatory)][Int32]$Resolution,
    [Parameter(Mandatory)][String]$Path
  )
  [System.Drawing.Size]$size = Find-SizeForResolution -MaxWidth $MaxWidth -Resolution $Resolution
  If ( $size.Width * $size.Height -Eq $Resolution ) {
    Save-TestJpegForSize -Size $size -Path $Path -Quality $Quality
  }
}