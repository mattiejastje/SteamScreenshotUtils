Add-Type -AssemblyName System.Drawing

Function Get-SteamRegistryRoot {
    Return "HKCU:\Software\Valve\Steam"
}

<#
.SYNOPSIS
Get the process id of the currently running steam executable.
.DESCRIPTION
Fetches the steam process id using the registry.
Stops if registry key is not present (for instance, if steam is not installed).
.OUTPUTS
The steam process id, or 0 if steam is not running.
#>
Function Get-SteamActiveProcessId {
    Return [Int32](Get-ItemProperty "$(Get-SteamRegistryRoot)\ActiveProcess" -ea Stop).pid
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
Function Get-SteamActiveUserId {
    Return [Int32](Get-ItemProperty "$(Get-SteamRegistryRoot)\ActiveProcess" -ea Stop).ActiveUser
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
    Return "$((Get-ItemProperty $(Get-SteamRegistryRoot) -ea Stop).SteamExe)".Replace("/", "\")
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
    Return "$((Get-ItemProperty $(Get-SteamRegistryRoot) -ea Stop).SteamPath)".Replace("/", "\")
}

<#
.SYNOPSIS
Get all steam user ids.
.DESCRIPTION
Fetches the user ids from the registry.
.OUTPUTS
The user ids.
#>
Function Get-SteamUserIds {
    Get-Item "$(Get-SteamRegistryRoot)\Users" -ea Stop | Out-Null
    Return [Int32[]]@(Get-ChildItem "$(Get-SteamRegistryRoot)\Users" -Name -ea Stop)
}

<#
.SYNOPSIS
Test steam user id.
.DESCRIPTION
Test whether steam user id exists in the registry.
#>
Function Test-SteamUserId {
    Param([Parameter(Mandatory)][Int32]$UserId)
    Get-Item "$(Get-SteamRegistryRoot)\Users" -ea Stop | Out-Null
    Return Test-Path "$(Get-SteamRegistryRoot)\Users\$UserId"
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
.EXAMPLE
PS> Find-SteamAppIdByName "hellblade" -Verbose
VERBOSE: Senua’s Saga: Hellblade II
2461850
VERBOSE: Hellblade: Senua's Sacrifice
414340
#>
Function Find-SteamAppIdByName {
    [CmdletBinding()]
    [OutputType([Int32])]
    Param([Parameter(Mandatory)][String]$Regex)
    Get-ChildItem "$(Get-SteamRegistryRoot)\Apps" -ea Stop | ForEach-Object {
        $property = Get-ItemProperty $_.PSPath
        If ( $property.Name -Match $Regex) {
            Write-Verbose $property.Name
            Return [Int32]($property.PSChildName)
        }
    }
}

<#
.SYNOPSIS
Test steam app id.
.DESCRIPTION
Test whether steam app id exists in the registry.
#>
Function Test-SteamAppId {
    [CmdletBinding()]
    Param([Parameter(Mandatory)][Int32]$AppId)
    Get-Item "$(Get-SteamRegistryRoot)\Apps" -ea Stop | Out-Null
    Return Test-Path "$(Get-SteamRegistryRoot)\Apps\$AppId"
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
    If ( $(Get-SteamActiveProcessId) -Ne 0 ) {
        [String]$steamexe = Get-SteamExe
        if ($PSCmdlet.ShouldProcess($steamexe)) {
            & $steamexe -shutdown
            While ( $(Get-SteamActiveProcessId) -Ne 0 ) {
                Write-Verbose "Awaiting steam shutdown..."
                Start-Sleep -Seconds 1
            }
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
    If ( $(Get-SteamActiveProcessId) -Eq 0 ) {
        [String]$steamexe = Get-SteamExe
        if ($PSCmdlet.ShouldProcess($steamexe)) {
            & $steamexe
            While ( $(Get-SteamActiveProcessId) -Eq 0 ) {
                Write-Verbose "Awaiting steam start..."
                Start-Sleep -Seconds 1
            }
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
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.DirectoryInfo])]
    Param(
        [Parameter(Mandatory)][ValidateScript({ Test-SteamUserId $_ })][Int32]$UserId,
        [Parameter(Mandatory)][ValidateScript({ Test-SteamAppId $_ })][Int32]$AppId
    )
    [String]$userdata = "$(Get-SteamPath)\userdata\$UserId"
    Get-Item $userdata | Out-Null  # assert existence (steam install is botched if it does not exist)
    [String]$screenshots = "$userdata\760\remote\$AppId\screenshots"
    [String]$thumbnails = "$screenshots\thumbnails"
    Write-Debug "Screenshots path: $screenshots"
    Write-Debug "Thumbnails path: $thumbnails"
    If ( -Not ( Test-Path $screenshots ) ) {
        If ( $PSCmdlet.ShouldProcess($screenshots, "new directory") ) {
            New-Item -Path $screenshots -ItemType "directory"
        }
    }
    Else {
        Get-Item -Path $screenshots
    }
    If ( -not ( Test-Path $thumbnails ) ) {
        If ( $PSCmdlet.ShouldProcess($thumbnails, "new directory") ) {
            New-Item -Path $thumbnails -ItemType "directory" | Out-Null
        }
    }
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
Function Find-SteamNonExistingScreenshotName {
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
    Return $name
}

<#
.SYNOPSIS
Scale size.
.DESCRIPTION
Scale size respecting width, height, and resolution limits.
.PARAMETER MaxWidth
Maximum width.
.PARAMETER MaxHeight
Maximum height.
.PARAMETER MaxResolution
Maximum resolution (width times height).
.PARAMETER Size
Original size.
.OUTPUTS
Scaled size.
#>
Function Resize-SizeWithinLimits {
    Param(
        [Parameter(Mandatory)][Int32]$MaxWidth,
        [Parameter(Mandatory)][Int32]$MaxHeight,
        [Parameter(Mandatory)][Int32]$MaxResolution,
        [Parameter(Mandatory)][System.Drawing.Size]$Size
    )
    $scale = (
        @(
            ( $MaxWidth / $Size.Width ),
            ( $MaxHeight / $Size.Height ),
            ( $MaxResolution / ( $Size.Width * $Size.Height ) ),
            1
        ) | Measure-Object -Minimum
    ).Minimum
    If ( $scale -Eq 1 ) {
        $Size
    }
    Else {
        [Int32]$scaledwidth = [Math]::Floor($scale * $Size.Width)
        [Int32]$scaledheight = [Math]::Floor($scale * $Size.Height)
        If ( $scaledwidth -Eq 0 ) {
            New-Object System.Drawing.Size 1, $((@($Size.Height, $MaxHeight, $MaxResolution) | Measure-Object -Minimum).Minimum)
        }
        ElseIf ( $scaledheight -Eq 0 ) {
            New-Object System.Drawing.Size $((@($Size.Width, $MaxWidth, $MaxResolution) | Measure-Object -Minimum).Minimum), 1
        }
        Else {
            New-Object System.Drawing.Size $scaledwidth, $scaledheight
        }
    }
}

<#
.SYNOPSIS
Install an image file into the steam screenshots folder for a given user and app.
.DESCRIPTION
Stops steam before installing any files.
Inspects the image file and preforms any conversions required.
If the image is valid for steam
(i.e. a jpeg not exceeding dimension and resolution requirements),
the image will be simply copied.
Otherwise, the image will be converted to the correct format.
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
.PARAMETER MinThumbnailSize
Minimum size of thumbnails.
The generated thumbnails will have a width or height equal to this number,
whichever is smallest.
Defaults to 144.
Note that steam creates thumbnails with a fixed width of 200,
but this sometimes leads to extremely pixelated thumbnails at very high aspect ratios.
We use a more sensible algorithm for determining thumbnail dimensions.
.PARAMETER UserId
The steam user id.
.PARAMETER AppId
The steam app id.
.INPUTS
Image items to install.
.OUTPUTS
Paths of the generated screenshots and thumbnails.
.EXAMPLE
Install all png images from a folder into Grand Theft Auto V:
PS> Get-Item folder\to\images\*.png | Install-SteamScreenshot -AppId 271590
#>
Function Install-SteamScreenshot {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String[]])]
    Param(
        [Int32]$MaxWidth = 16000, # https://github.com/awthwathje/SteaScree/issues/4
        [Int32]$MaxHeight = 16000, # https://github.com/awthwathje/SteaScree/issues/4
        [Int32]$MaxResolution = 26210175, # https://github.com/awthwathje/SteaScree/issues/4
        [Int32]$ConversionQuality = 90, # seems to be steam default according to "magick identify -verbose"
        [Int32]$ThumbnailQuality = 95, # seems to be steam default according to "magick identify -verbose"
        [Int32]$MinThumbnailSize = 144, # gives 256x144 for 16:9 pictures
        [Parameter(Mandatory)][ValidateScript({ Test-SteamUserId $_ })][Int32]$UserId,
        [Parameter(Mandatory)][ValidateScript({ Test-SteamAppId $_ })][Int32]$AppId,
        [Parameter(Mandatory, ValueFromPipeline)][System.IO.FileInfo]$FileInfo
    )
    Begin {
        Stop-Steam
        [System.IO.DirectoryInfo]$screenshots = Install-SteamScreenshotsDirectory -UserId $UserId -AppId $AppId
        [System.IO.DirectoryInfo]$thumbnails = Get-Item "$screenshots/thumbnails" -ea Stop
    }
    Process {
        Write-Verbose "Loading image"
        $image = New-Object System.Drawing.Bitmap $FileInfo.FullName
        [String]$newscreenshotname = Find-SteamNonExistingScreenshotName -ScreenshotsDirectory $screenshots -DateTime $FileInfo.LastWriteTime
        [String]$newscreenshot = Join-Path $screenshots $newscreenshotname
        $screenshotsize = Resize-SizeWithinLimits `
            -MaxWidth $MaxWidth -MaxHeight $MaxHeight -MaxResolution $MaxResolution `
            -Size $image.Size
        If ( $screenshotsize -Eq $image.Size ) {
            If ( $FileInfo.Extension -In @(".jpg", ".jpeg", ".jfif", ".pjpeg", ".pjp") ) {
                If ( $PSCmdlet.ShouldProcess($FileInfo.FullName, "copy to $newscreenshot" ) ) {
                    Copy-Item -Path $FileInfo.FullName -Destination $newscreenshot
                    Get-Item $newscreenshot
                }
            }
            Else {
                If ( $PSCmdlet.ShouldProcess($FileInfo.FullName, "save as $newscreenshot" ) ) {
                    Save-BitmapAsJpeg -Bitmap $image -Path $newscreenshot -Quality $ConversionQuality
                    Get-Item $newscreenshot
                }
            }
        }
        Else {
            If ( $PSCmdlet.ShouldProcess($FileInfo.FullName, "resize to $($screenshotsize.Width)x$($screenshotsize.Height) and save as $newscreenshot" ) ) {
                $screenshotresized = New-Object System.Drawing.Bitmap $image, $screenshotsize
                Save-BitmapAsJpeg -Bitmap $screenshotresized -Path $newscreenshot -Quality $ConversionQuality
                $screenshotresized.Dispose()
                Get-Item $newscreenshot
            }
        }
        $thumbnailsize = If ( $image.Width -Gt $image.Height ) {
            Resize-SizeWithinLimits `
                -MaxWidth $MaxWidth -MaxHeight $([Math]::Min($MaxHeight, $MinThumbnailSize)) -MaxResolution $MaxResolution `
                -Size $image.Size
        }
        Else {
            Resize-SizeWithinLimits `
                -MaxWidth $([Math]::Min($MaxWidth, $MinThumbnailSize)) -MaxHeight $MaxHeight -MaxResolution $MaxResolution `
                -Size $image.Size
        }
        $newthumbnail = Join-Path $thumbnails $newscreenshotname
        if ( $PSCmdlet.ShouldProcess($FileInfo.FullName, "resize to $($thumbnailsize.Width)x$($thumbnailsize.Height) and save as $newthumbnail" ) ) {
            $resized = New-Object System.Drawing.Bitmap $image, $thumbnailsize
            Save-BitmapAsJpeg -Bitmap $resized -Path $newthumbnail -Quality $ThumbnailQuality
            $resized.Dispose()
            Get-Item $newthumbnail
        }
        $image.Dispose()
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
            Return $size
        }
    }
    Write-Warning "No size for resolution $Resolution with width between $minwidth and $MaxWidth."
    $height = [Math]::DivRem($Resolution, $minwidth, [ref] $null)
    $size = New-Object System.Drawing.Size $minwidth, $height
    Return $size
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