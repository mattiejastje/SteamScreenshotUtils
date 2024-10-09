BeforeAll {
    Import-Module .\SteamScreenshotUtils.psm1 -Force
    Mock -CommandName "Get-SteamRegistryRoot" `
        -ModuleName "SteamScreenshotUtils" `
        -MockWith { Return "TestRegistry:\Steam" }

    Function Install-MockSteam {
        Param(
            [Int32]$ProcessId = 1,
            [Int32[]]$AppIds = @(),
            [Int32[]]$UserIds = @(),
            [Switch]$Running = $false
        )
        [Int32]$activeuserid = If ( $UserIds.Length ) { $UserIds[0] } Else { 0 }
        New-Item TestRegistry:\Steam
        New-ItemProperty -Path TestRegistry:\Steam -Name "SteamPath" -Value "TestDrive:/steam"
        New-ItemProperty -Path TestRegistry:\Steam -Name "SteamExe" -Value "TestDrive:/steam/steam.ps1"
        New-Item TestDrive:\steam -ItemType "directory"
        New-Item TestDrive:\steam\steam.ps1 -ItemType "file" -Value "
Param([Switch]`$shutdown = `$false)
If ( `$shutdown ) {
    Set-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name `"pid`" -Value 0
    Set-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name `"ActiveUser`" -Value 0
}
Else {
    Set-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name `"pid`" -Value $ProcessId
    Set-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name `"ActiveUser`" -Value $activeuserid
}
"
        New-Item TestRegistry:\Steam\ActiveProcess
        If ( $Running ) {
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "pid" -Value $ProcessId
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "ActiveUser" -Value $activeuserid
        }
        Else {
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "pid" -Value 0
            New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "ActiveUser" -Value 0
        }
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
        It "Get-SteamUserIds" {
            { Get-SteamUserIds } | Should -Throw "Cannot find path*"
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
        It "Get-SteamUserIds" {
            Get-SteamUserIds | Sort-Object | Should -Be @(777888999,789789789)
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
        It "Start and stop steam" {
            Get-SteamActiveProcessId | Should -Be 0
            Get-SteamActiveUserId | Should -Be 0
            Start-Steam
            Get-SteamActiveProcessId | Should -Be 123123123
            Get-SteamActiveUserId | Should -Be 789789789
            Stop-Steam
            Get-SteamActiveProcessId | Should -Be 0
            Get-SteamActiveUserId | Should -Be 0
        }
    }
    Context "Steam installed and running" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999 -Running
        }
        It "Stop and start steam" {
            Get-SteamActiveProcessId | Should -Be 123123123
            Get-SteamActiveUserId | Should -Be 789789789
            Stop-Steam
            Get-SteamActiveProcessId | Should -Be 0
            Get-SteamActiveUserId | Should -Be 0
            Start-Steam
            Get-SteamActiveProcessId | Should -Be 123123123
            Get-SteamActiveUserId | Should -Be 789789789
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
        Set-ItemProperty -Path "TestDrive:\test.jpg" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:00")
        Set-ItemProperty -Path "TestDrive:\test.png" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:01")
        Set-ItemProperty -Path "TestDrive:\testlarge.jpg" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:02")
        Set-ItemProperty -Path "TestDrive:\testportrait.jpg" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:03")
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
        It "WhatIf" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000000_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000000_1.jpg"
            Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -WhatIf | Should -BeNullOrEmpty
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
        }
        It "Jpeg" {
            $screenshots = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots"
            $thumbnails = Join-Path $screenshots "thumbnails"
            $screenshot = Join-Path $screenshots "20240101000000_1.jpg"
            $thumbnail = Join-Path $thumbnails "20240101000000_1.jpg"
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
            $screenshot = Join-Path $screenshots "20240101000001_1.jpg"
            $thumbnail = Join-Path $thumbnails "20240101000001_1.jpg"
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
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000002_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000002_1.jpg"
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
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000003_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000003_1.jpg"
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
    }
}

Describe "Resize-SizeWithinLimits" {
    It "Correct <MaxWidth> <MaxHeight> <MaxResolution> <Width> <Height> -> <ExpWidth> <ExpHeight>" -ForEach @(
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
        Resize-SizeWithinLimits -MaxWidth $MaxWidth -MaxHeight $MaxHeight -MaxResolution $MaxResolution -Size $size | Should -Be $expsize
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
        { Resize-SizeWithinLimits -MaxWidth $MaxWidth -MaxHeight $MaxHeight -MaxResolution $MaxResolution -Size $size } | Should -Throw "Cannot validate argument on parameter*"
    }
}
