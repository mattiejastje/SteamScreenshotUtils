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

# test install functions
Describe "Install" {
    BeforeAll {
        $image = New-Object System.Drawing.Bitmap 480, 270
        $image.Save($(Join-Path $TestDrive "test.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $image.Dispose()
        $image = New-Object System.Drawing.Bitmap 400, 250
        $image.Save($(Join-Path $TestDrive "test.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $image.Dispose()
        Set-ItemProperty -Path "TestDrive:\test.jpg" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:00")
        Set-ItemProperty -Path "TestDrive:\test.png" -Name LastWriteTime -Value $(Get-Date -Date "2024-01-01 00:00:01")
    }
    Context "Steam not installed" {
        It "Install-SteamScreenshotsDirectory" {
            { Install-SteamScreenshotsDirectory -UserId 1 -AppId 1 } | Should -Throw "*Cannot find path*"
        }
        It "Install-SteamScreenshot" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 1 } | Should -Throw "*Cannot find path*"
        }
    }
    Context "Steam installed" {
        BeforeAll {
            Install-MockSteam -ProcessId 123123123 -AppIds 456456456,444555666 -UserIds 789789789,777888999
        }
        It "Install-SteamScreenshotsDirectory" {
            { Install-SteamScreenshotsDirectory -UserId 1 -AppId 1 } | Should -Throw "Cannot validate argument*UserId*"
            { Install-SteamScreenshotsDirectory -UserId 1 -AppId 456456456 } | Should -Throw "Cannot validate argument*UserId*"
            { Install-SteamScreenshotsDirectory -UserId 789789789 -AppId 1 } | Should -Throw "Cannot validate argument*AppId*"
            Install-SteamScreenshotsDirectory -UserId 789789789 -AppId 456456456 -WhatIf | Should -BeNullOrEmpty
            Install-SteamScreenshotsDirectory -UserId 789789789 -AppId 456456456 | Should -Be $(Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots")
        }
        It "Install-SteamScreenshot invalid argument" {
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 1 } | Should -Throw "Cannot validate argument*"
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 1 -AppId 456456456 } | Should -Throw "Cannot validate argument*"
            { Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 1 } | Should -Throw "Cannot validate argument*"
        }
        It "Install-SteamScreenshot -WhatIf" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000000_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000000_1.jpg"
            Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 -WhatIf | Should -BeNullOrEmpty
            Test-Path $screenshot | Should -BeFalse
            Test-Path $thumbnail | Should -BeFalse
        }
        It "Install-SteamScreenshot Jpeg" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000000_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000000_1.jpg"
            Get-Item "TestDrive:\test.jpg" | Install-SteamScreenshot -UserId 789789789 -AppId 456456456 | Should -Be $screenshot, $thumbnail
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
        It "Install-SteamScreenshot Png" {
            $screenshot = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\20240101000001_1.jpg"
            $thumbnail = Join-Path $TestDrive "steam\userdata\789789789\760\remote\456456456\screenshots\thumbnails\20240101000001_1.jpg"
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
    }
}