BeforeAll {
    Import-Module .\SteamScreenshotUtils.psm1 -Force
    Mock -CommandName "Get-SteamRegistryRoot" `
        -ModuleName "SteamScreenshotUtils" `
        -MockWith { Return "TestRegistry:\Steam" }
    Mock -CommandName "Get-Date" `
        -ModuleName "SteamScreenshotUtils" `
        -MockWith { Return $(Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0) }

    Function Install-MockSteam {
        Param(
            [Int32]$ProcessId = 1,
            [Int32[]]$AppIds = @(),
            [Int32[]]$UserIds = @(),
            [Switch]$Running = $false
        )
        [Int32]$activeuserid = If ( $UserIds.Length ) { $UserIds[0] } Else { 0 }
        New-Item TestRegistry:\Steam
        $activeprocess = New-Item TestRegistry:\Steam\ActiveProcess
        If ( $Running ) {
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "pid" -Value $ProcessId
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "ActiveUser" -Value $activeuserid
        }
        Else {
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "pid" -Value 0
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "ActiveUser" -Value 0
        }
        New-ItemProperty -Path TestRegistry:\Steam -Name "SteamPath" -Value "TestDrive:/steam"
        New-ItemProperty -Path TestRegistry:\Steam -Name "SteamExe" -Value "TestDrive:/steam/steam.ps1"
        New-Item TestDrive:\steam -ItemType "directory"
        New-Item TestDrive:\steam\steam.ps1 -ItemType "file" -Value "
Param([Switch]`$shutdown = `$false)
If ( `$shutdown ) {
    Start-Job -ScriptBlock {
        Start-Sleep -Milliseconds 10
        Set-ItemProperty -Path $($activeprocess.PSPath) -Name `"pid`" -Value 0
        Set-ItemProperty -Path $($activeprocess.PSPath) -Name `"ActiveUser`" -Value 0
    }
}
Else {
    Start-Job -ScriptBlock {
        Start-Sleep -Milliseconds 10
        Set-ItemProperty -Path $($activeprocess.PSPath) -Name `"pid`" -Value $ProcessId
        Set-ItemProperty -Path $($activeprocess.PSPath) -Name `"ActiveUser`" -Value $activeuserid
    }
}
"
        New-Item TestRegistry:\Steam\Apps
        $AppIds | ForEach-Object {
            New-Item TestRegistry:\Steam\Apps\$_
            New-ItemProperty -Path TestRegistry:\Steam\Apps\$_ -Name "Name" -Value "Test App $_"
        }
        New-Item TestRegistry:\Steam\Users
        $UserIds | ForEach-Object {
            New-Item TestRegistry:\Steam\Users\$_
            New-Item -Path TestDrive:\steam\userdata\$_\760\remote -ItemType "directory"
        }
    }
}

# test functions that directly access the registry
Describe "Registry" {
    Context "Steam not installed" {
        It "Get-ActiveProcessId" {
            { Get-SteamActiveProcessId } | Should -Throw "Cannot find path*"
        }
        It "Get-ActiveUserId" {
            { Get-SteamActiveUserId } | Should -Throw "Cannot find path*"
        }
        It "Get-SteamExe" {
            { Get-SteamExe } | Should -Throw "Cannot find path*"
        }
        It "Get-SteamPath" {
            { Get-SteamPath } | Should -Throw "Cannot find path*"
        }
        It "Get-SteamUserId" {
            { Get-SteamUserId } | Should -Throw "Cannot find path*"
        }
        It "Find-SteamAppIdByName" {
            { Find-SteamAppIdByName -Regex "Test App" } | Should -Throw "Cannot find path*"
        }
        It "Test-SteamAppId" {
            { Test-SteamAppId -AppId 1 } | Should -Throw "Cannot find path*"
        }
        It "Test-SteamUserId" {
            { Test-SteamUserId -UserId 1 } | Should -Throw "Cannot find path*"
        }    
    }
    Context "Steam installed" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999
        }
        It "Get-ActiveProcessId" {
            Get-SteamActiveProcessId | Should -Be 0
        }
        It "Get-ActiveUserId" {
            Get-SteamActiveUserId | Should -Be 0
        }
        It "Get-SteamExe" {
            Get-SteamExe | Should -Be "TestDrive:\steam\steam.ps1"
        }
        It "Get-SteamPath" {
            Get-SteamPath | Should -Be "TestDrive:\steam"
        }
        It "Get-SteamUserId" {
            Get-SteamUserId | Sort-Object | Should -Be @(777888999,789789789)
        }
        It "Find-SteamAppIdByName" {
            Find-SteamAppIdByName "app" | Sort-Object | Should -Be @(444555666,456456456)
            Find-SteamAppIdByName "app 456" | Should -Be 456456456 
            Find-SteamAppIdByName "app 444" | Should -Be 444555666
            Find-SteamAppIdByName "non-existing app" | Should -Be $null 
        }
        It "Test-SteamAppId" {
            Test-SteamAppId -AppId 456456456 | Should -BeTrue
            Test-SteamAppId -AppId 1 | Should -BeFalse
        }
        It "Test-SteamUserId" {
            Test-SteamUserId -UserId 789789789 | Should -BeTrue
            Test-SteamUserId -UserId 1 | Should -BeFalse
        }
    }
}

# test functions that control the steam process
Describe "Steam process" {
    Context "Steam installed" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999
        }
        It "Start steam" {
            Get-SteamActiveProcessId | Should -Be 0
            Get-SteamActiveUserId | Should -Be 0
            Start-Steam
            Get-SteamActiveProcessId | Should -Be 123123123
            Get-SteamActiveUserId | Should -Be 789789789
        }
    }
    Context "Steam installed and running" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999 -Running
        }
        It "Stop steam" {
            Get-SteamActiveProcessId | Should -Be 123123123
            Get-SteamActiveUserId | Should -Be 789789789
            Stop-Steam
            Get-SteamActiveProcessId | Should -Be 0
            Get-SteamActiveUserId | Should -Be 0
        }
    }
}

Describe "Save-BitmapAsJpeg" {
    It "Header" -ForEach @(0, 50, 100) {
        $image = New-Object System.Drawing.Bitmap 20, 10
        $file = Join-Path $TestDrive test1.jpg
        Save-BitmapAsJpeg -Bitmap $image -Path $file -Quality $_
        $image.Dispose()
        Test-JpegHeader -Path $file | Should -BeTrue
    }
    It "Invalid quality" -ForEach @(-1, 101) {
        $image = New-Object System.Drawing.Bitmap 20, 10
        { Save-BitmapAsJpeg -Bitmap $image -Path $(Join-Path $TestDrive test2.jpg) -Quality $_ } | Should -Throw "Cannot validate argument on parameter*"
        $image.Dispose()
    }
}

Describe "Install-ScreenshotsPath" {
    Context "Steam not installed" {
        It "Cannot find path" {
            { Install-SteamScreenshotsPath -UserId 1 -AppId 1 } | Should -Throw "*Cannot find path*"
        }
    }
    Context "Steam installed" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999
        }
        It "Invalid UserId and AppId" {
            { Install-SteamScreenshotsPath -UserId 1 -AppId 1 } | Should -Throw "Cannot validate argument*UserId*"
        }
        It "Invalid UserId" {
            { Install-SteamScreenshotsPath -UserId 1 -AppId 456456456 } | Should -Throw "Cannot validate argument*UserId*"
        }
        It "Invalid AppId" {
            { Install-SteamScreenshotsPath -UserId 789789789 -AppId 1 } | Should -Throw "Cannot validate argument*AppId*"
        }
        It "WhatIf" {
            Install-SteamScreenshotsPath -UserId 789789789 -AppId 456456456 -WhatIf | Should -BeNullOrEmpty
        }
        It "Success" {
            $screenshots = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots"
            $thumbnails = Join-Path $screenshots "thumbnails"
            Install-SteamScreenshotsPath -UserId 789789789 -AppId 456456456 | Should -Be $screenshots, $thumbnails
            Test-Path $screenshots | Should -BeTrue
            Test-Path $thumbnails | Should -BeTrue
        }
    }
}

Describe "Install-Screenshots" {
    BeforeAll {
        $image = New-Object System.Drawing.Bitmap 480, 270
        $image.Save($(Join-Path $TestDrive "test.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $image.Dispose()
        $image = New-Object System.Drawing.Bitmap 400, 250
        $image.Save($(Join-Path $TestDrive "test.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $image.Dispose()
        $image = New-Object System.Drawing.Bitmap 32000, 4
        $image.Save($(Join-Path $TestDrive "testlarge.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $image.Dispose()
        $image = New-Object System.Drawing.Bitmap 384, 512
        $image.Save($(Join-Path $TestDrive "testportrait.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $image.Dispose()
        New-Item -Path "TestDrive:\invalid.jpg"
    }
    Context "Steam not installed" {
        It "Cannot find path" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 1 } | Should -Throw "*Cannot find path*"
        }
    }
    Context "Steam installed" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999
        }
        It "Invalid UserId and AppId" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 1 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid UserId" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 456456456 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid AppId" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 1 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid MaxSize" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -MaxSize 0 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid MaxResolution" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -MaxResolution 0 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid MinThumbnailSize" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -MinThumbnailSize 0 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid ConversionQuality" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -ConversionQuality -1 } | Should -Throw "Cannot validate argument*"
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -ConversionQuality 101 } | Should -Throw "Cannot validate argument*"
        }
        It "Invalid ThumbnailQuality" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -ThumbnailQuality -1 } | Should -Throw "Cannot validate argument*"
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -ThumbnailQuality 101 } | Should -Throw "Cannot validate argument*"
        }
        It "WhatIf" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\19700101000000_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\19700101000000_1.jpg"
            Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -WhatIf | Should -BeNullOrEmpty
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
        }
        It "Jpeg" {
            $screenshots = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots"
            $thumbnails = Join-Path $screenshots "thumbnails"
            $screenshot = Join-Path $screenshots "19700101000000_1.jpg"
            $thumbnail = Join-Path $thumbnails "19700101000000_1.jpg"
            Test-Path $screenshots | Should -BeFalse
            Test-Path $thumbnails | Should -BeFalse
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
            Get-Item TestDrive:\test.jpg | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshots, $thumbnails, $screenshot, $thumbnail
            Test-Path $screenshots | Should -BeTrue
            Test-Path $thumbnails | Should -BeTrue
            Test-Path $screenshot | Should -BeTrue
            Test-Path $thumbnail | Should -BeTrue
            $screenshotimage = New-Object System.Drawing.Bitmap $screenshot
            $thumbnailimage = New-Object System.Drawing.Bitmap $thumbnail
            $screenshotimage.Width | Should -Be 480
            $screenshotimage.Height | Should -Be 270
            $thumbnailimage.Width | Should -Be 256
            $thumbnailimage.Height | Should -Be 144
            $screenshotimage.Dispose()
            $thumbnailimage.Dispose()
        }
        It "Png" {
            $screenshots = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots"
            $thumbnails = Join-Path $screenshots "thumbnails"
            $screenshot = Join-Path $screenshots "19700101000000_2.jpg"
            $thumbnail = Join-Path $thumbnails "19700101000000_2.jpg"
            Test-Path $screenshots | Should -BeTrue # from previous test
            Test-Path $thumbnails | Should -BeTrue # from previous test
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
            Get-Item "TestDrive:\test.png" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshot, $thumbnail
            Test-Path $screenshot | Should -BeTrue
            Test-Path $thumbnail | Should -BeTrue
            $screenshotimage = New-Object System.Drawing.Bitmap $screenshot
            $thumbnailimage = New-Object System.Drawing.Bitmap $thumbnail
            $screenshotimage.Width | Should -Be 400
            $screenshotimage.Height | Should -Be 250
            $thumbnailimage.Width | Should -Be 230
            $thumbnailimage.Height | Should -Be 144
            $screenshotimage.Dispose()
            $thumbnailimage.Dispose()
        }
        It "Large" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\19700101000000_3.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\19700101000000_3.jpg"
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
            Get-Item "TestDrive:\testlarge.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshot, $thumbnail
            Test-Path $screenshot | Should -BeTrue
            Test-Path $thumbnail | Should -BeTrue
            $screenshotimage = New-Object System.Drawing.Bitmap $screenshot
            $thumbnailimage = New-Object System.Drawing.Bitmap $thumbnail
            $screenshotimage.Width | Should -Be 16000
            $screenshotimage.Height | Should -Be 2
            $thumbnailimage.Width | Should -Be 16000
            $thumbnailimage.Height | Should -Be 2
            $screenshotimage.Dispose()
            $thumbnailimage.Dispose()
        }
        It "Portrait" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\19700101000000_4.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\19700101000000_4.jpg"
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
            Get-Item "TestDrive:\testportrait.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshot, $thumbnail
            Test-Path $screenshot | Should -BeTrue
            Test-Path $thumbnail | Should -BeTrue
            $screenshotimage = New-Object System.Drawing.Bitmap $screenshot
            $thumbnailimage = New-Object System.Drawing.Bitmap $thumbnail
            $screenshotimage.Width | Should -Be 384
            $screenshotimage.Height | Should -Be 512
            $thumbnailimage.Width | Should -Be 144
            $thumbnailimage.Height | Should -Be 192
            $screenshotimage.Dispose()
            $thumbnailimage.Dispose()
        }
        It "Invalid image" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\19700101000000_5.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\19700101000000_5.jpg"
            $(Get-Item "TestDrive:\invalid.jpg" -ea Stop), $(Get-Item "TestDrive:\test.jpg" -ea Stop) | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshot, $thumbnail
        }
        It "Invalid image with error action stop" {
            { Get-Item "TestDrive:\invalid.jpg" -ea Stop | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -ErrorAction Stop } | Should -Throw "Cannot load*"
        }
        It "Formats" {
            $output = Get-ChildItem -Path $PSScriptRoot -Filter test*.* | Install-SteamScreenshot -UserId 777888999 -AppId 444555666
            # 2 folders, 9 screenshots, 9 thumbnails
            $output.Length | Should -Be 20
        }
    }
}

Describe "Resize-SizeWithinLimit" {
    It "Test <MaxWidth> <MaxHeight> <MaxResolution> <Width> <Height> -> <ExpWidth> <ExpHeight>" -ForEach @(
        @{ MaxWidth = 1000; MaxHeight = 1000; MaxResolution = 100000; Width = 200; Height = 100; ExpWidth = 200; ExpHeight = 100 }
        @{ MaxWidth = 50; MaxHeight = 1000; MaxResolution = 100000; Width = 200; Height = 100; ExpWidth = 50; ExpHeight = 25 }
        @{ MaxWidth = 1000; MaxHeight = 50; MaxResolution = 100000; Width = 200; Height = 100; ExpWidth = 100; ExpHeight = 50 }
        @{ MaxWidth = 1000; MaxHeight = 1000; MaxResolution = 200; Width = 200; Height = 100; ExpWidth = 20; ExpHeight = 10 }
        @{ MaxWidth = 20; MaxHeight = 1000; MaxResolution = 100000; Width = 200; Height = 2; ExpWidth = 20; ExpHeight = 1 }
        @{ MaxWidth = 1000; MaxHeight = 20; MaxResolution = 100000; Width = 2; Height = 100; ExpWidth = 1; ExpHeight = 20 }
        @{ MaxWidth = 1000; MaxHeight = 1000; MaxResolution = 20; Width = 200; Height = 2; ExpWidth = 20; ExpHeight = 1 }
        @{ MaxWidth = 1000; MaxHeight = 1000; MaxResolution = 20; Width = 2; Height = 100; ExpWidth = 1; ExpHeight = 20 }
    ) {
        $size = New-Object System.Drawing.Size $Width, $Height
        $expsize = New-Object System.Drawing.Size $ExpWidth, $ExpHeight
        Resize-SizeWithinLimit -MaxWidth $MaxWidth -MaxHeight $MaxHeight -MaxResolution $MaxResolution -Size $size | Should -Be $expsize
    }
    It "Invalid parameters <MaxWidth> <MaxHeight> <MaxResolution> <Width> <Height>"  -ForEach @(
        @{ MaxWidth = 0; MaxHeight = 1; MaxResolution = 1; Width = 1; Height = 1 }
        @{ MaxWidth = 1; MaxHeight = 0; MaxResolution = 1; Width = 1; Height = 1 }
        @{ MaxWidth = 1; MaxHeight = 1; MaxResolution = 0; Width = 1; Height = 1 }
        @{ MaxWidth = 1; MaxHeight = 1; MaxResolution = 1; Width = 0; Height = 1 }
        @{ MaxWidth = 1; MaxHeight = 1; MaxResolution = 1; Width = 1; Height = 0 }
        @{ MaxWidth = 1; MaxHeight = 1; MaxResolution = 1; Width = 0; Height = 0 }
    ) {
        $size = New-Object System.Drawing.Size $Width, $Height
        { Resize-SizeWithinLimit -MaxWidth $MaxWidth -MaxHeight $MaxHeight -MaxResolution $MaxResolution -Size $size } | Should -Throw "Cannot validate argument on parameter*"
    }
}

Describe "Find-SizeForResolution" {
    It "Exact <MaxWidth> <Resolution> -> <Width>x<Height>" -ForEach @(
        @{ MaxWidth = 1000; Resolution = 100; Width = 10; Height = 10 }
        @{ MaxWidth = 1000; Resolution = 120; Width = 12; Height = 10 }
        @{ MaxWidth = 1000; Resolution = 113; Width = 113; Height = 1 }
    ) {
        $size = New-Object System.Drawing.Size $Width, $Height
        Find-SizeForResolution -MaxWidth $MaxWidth -Resolution $Resolution | Should -Be $size
        $Width * $Height | Should -Be $Resolution
    }
    It "Not exact <MaxWidth> <Resolution> -> <Width>x<Height>" -ForEach @(
        @{ MaxWidth = 20; Resolution = 113; Width = 11; Height = 10 }
    ) {
        $size = New-Object System.Drawing.Size $Width, $Height
        Find-SizeForResolution -MaxWidth $MaxWidth -Resolution $Resolution | Should -Be $size
        $Width * $Height | Should -BeLessOrEqual $Resolution
    }
    It "Invalid parameters" {
        { Find-SizeForResolution -MaxWidth -1 -Resolution 1 } | Should -Throw "Cannot validate argument on parameter*"
        { Find-SizeForResolution -MaxWidth 1 -Resolution -1 } | Should -Throw "Cannot validate argument on parameter*"
    }
}

Describe "Save-TestJpegForSize" {
    It "Simple test" {
        $path = Join-Path $TestDrive "testforsize.jpg"
        $size = New-Object System.Drawing.Size 200, 100
        Save-TestJpegForSize -Size $size -Path $path
        $bitmap = New-Object System.Drawing.Bitmap $path
        $bitmap.Width | Should -Be 200
        $bitmap.Height | Should -Be 100
        $bitmap.Dispose()
    }
}

Describe "Save-TestJpegForResolution" {
    It "Simple test" {
        $path = Join-Path $TestDrive "testforsize.jpg"
        Save-TestJpegForResolution -Resolution 120 -Path $path
        $bitmap = New-Object System.Drawing.Bitmap $path
        $bitmap.Width | Should -Be 12
        $bitmap.Height | Should -Be 10
        $bitmap.Dispose()
    }
}

Describe "Split-SteamVdf" {
    It "Test <Vdf> <Tokens>" -ForEach @(
        @{ Vdf="hi"; Tokens="hi" },
        @{ Vdf="  hi  "; Tokens="hi" },
        @{ Vdf='"hi"'; Tokens="hi" },
        @{ Vdf='  "hi"  '; Tokens="hi" },
        @{ Vdf='"h\"i"'; Tokens='h"i' },
        @{ Vdf='a b "c" "d" e "f" g "h" 1 2 "3"'; Tokens=@("a", "b", "c", "d", "e", "f", "g", "h", "1", "2", "3") },
        @{ Vdf='a b"c""d" e"f"g"h" 1 2"3"'; Tokens=@("a", "b", "c", "d", "e", "f", "g", "h", "1", "2", "3") },
        @{ Vdf="hi { there champ }"; Tokens=@("hi", "{", "there", "champ", "}") },
        @{ Vdf="hi{there champ}"; Tokens=@("hi", "{", "there", "champ", "}") }
        @{ Vdf="hi`n{`n`t`tthere`t`tchamp`n}"; Tokens=@("hi", "{", "there", "champ", "}") }
        @{ Vdf="`"hi`"`n{`n`t`t`"there`"`t`t`"champ`"`n}"; Tokens=@("hi", "{", "there", "champ", "}") }
    ) {
        $Vdf | Split-SteamVdf | Should -Be $Tokens
        $Vdf -Split "`n" | Split-SteamVdf | Should -Be $Tokens
    }
    It "Cannot find token" {
        { '"hi' | Split-SteamVdf } | Should -Throw "Cannot find token*"
    }
}

Describe "Format-SteamVdf" {
    It "Simple example" {
        "hi{there champ}" | Format-SteamVdf | Should -Be @('"hi"', "{", "`t`"there`"`t`t`"champ`"", "}")
    }
    It "Subkey without key" {
        { "{there champ}" | Format-SteamVdf } | Should -Throw "Subkey without key*"
    }
    It "Final subkey missing value" {
        { "hi{there}" | Format-SteamVdf } | Should -Throw "Key*is missing a value*"
    }
    It "Too many }" {
        { "}" | Format-SteamVdf } | Should -Throw "Too many }*"
    }
    It "Missing value due to closing bracket" {
        { "hi}" | Format-SteamVdf } | Should -Throw "Key*is missing a value*"
    }
    It "Incomplete value" {
        { "hi{there" | Format-SteamVdf } | Should -Throw "Key*has missing or incomplete value*"
    }
    It "Missing closing bracket" {
        { "hi{there champ" | Format-SteamVdf } | Should -Throw "Key*is missing }*"
    }
    It "Empty value" {
        "hi `"`"" | Format-SteamVdf | Should -Be @("`"hi`"`t`t`"`"")
    }
    It "Empty subkeys" {
        "hi {}" | Format-SteamVdf | Should -Be @('"hi"', "{", "}")
    }
}

Describe "Get-SteamVdfValue" {
    It "Simple test" {
        "hi { nothing here there champ }" | Get-SteamVdfValue -Location @("hi", "nothing") | Should -Be "here"
        "hi { nothing here there champ }" | Get-SteamVdfValue -Location @("hi", "there") | Should -Be "champ"
    }
    It "Multiple matches test" {
        "hi { there champ } hi { there another }" | Get-SteamVdfValue -Location @("hi", "there") | Should -Be @("champ", "another")
    }
}

Describe "Get-SteamVdfSubkey" {
    It "Simple test" {
        "hi { nothing { there champ } }" | Get-SteamVdfSubkey -Location @("hi") | Should -Be @("nothing")
    }
    It "Multiple matches test" {
        "hi { nothing { there champ } another { } }" | Get-SteamVdfSubkey -Location @("hi") | Should -Be @("nothing", "another")
    }
}
