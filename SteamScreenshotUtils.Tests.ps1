BeforeAll {
    Import-Module .\SteamScreenshotUtils.psm1
    Mock -CommandName "Get-SteamRegistryRoot" `
        -ModuleName "SteamScreenshotUtils" `
        -MockWith { return "TestRegistry:\Steam" }
}

Describe 'SteamRunning' {
    BeforeAll {
        New-Item -Path "TestDrive:\steam\userdata\455455\760\remote" -ItemType "directory"
        New-Item TestRegistry:\Steam
        New-ItemProperty -Path "TestRegistry:\Steam" -Name "SteamPath" -Value "TestDrive:/steam"
        New-ItemProperty -Path "TestRegistry:\Steam" -Name "SteamExe" -Value "TestDrive:/steam/steam.exe"
        New-Item TestRegistry:\Steam\ActiveProcess
        New-ItemProperty -Path "TestRegistry:\Steam\ActiveProcess" -Name "ActiveUser" -Value 455455
        New-ItemProperty -Path "TestRegistry:\Steam\ActiveProcess" -Name "pid" -Value 1337
        New-Item TestRegistry:\Steam\Apps
        New-Item TestRegistry:\Steam\Apps\271590
        New-ItemProperty -Path TestRegistry:\Steam\Apps\271590 -Name "Name" -Value "Grand Theft Auto V"
        New-Item TestRegistry:\Steam\Users
        New-Item TestRegistry:\Steam\Users\455455
    }

    It 'Registry' {
        Get-SteamActiveProcessUserId | Should -Be 455455
        Get-SteamActiveProcessPid | Should -Be 1337
        Get-SteamPath | Should -Be "TestDrive:\steam"
        Get-SteamExe | Should -Be "TestDrive:\steam\steam.exe"
        Find-SteamUserId | Should -Be 455455
        Find-SteamAppIdByName "grand theft auto" | Should -Be 271590
        Find-SteamAppIdByName "not installed" | Should -Be $null
        Confirm-SteamUserId | Should -Be 455455
        Confirm-SteamUserId -UserId 455455 | Should -Be 455455
        { Confirm-SteamUserId -UserId 1 } | Should -Throw "*Cannot find steam user*"
        Confirm-SteamAppId -AppId 271590
        { Confirm-SteamAppId -AppId 1 } | Should -Throw "*Cannot find steam app*"
        { Stop-Steam } | Should -Throw "*'TestDrive:\steam\steam.exe' is not recognized*"
        Start-Steam | Should -Be $null
    }
}
