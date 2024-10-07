BeforeAll {
    Import-Module .\SteamScreenshotUtils.psm1 -Force
    Mock -CommandName "Get-SteamRegistryRoot" `
        -ModuleName "SteamScreenshotUtils" `
        -MockWith { Return "TestRegistry:\Steam" }
    
    Function Install-MockSteam {
        Param(
            [Int32]$ProcessId = 0,
            [Int32[]]$AppIds = @(),
            [Int32[]]$UserIds = @()
        )
        [Int32]$activeuserid = If ( $ProcessId -And $UserIds.Length ) { $UserIds[0] } Else { 0 }
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
        New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "pid" -Value $ProcessId
        New-ItemProperty -Path TestRegistry:\Steam\ActiveProcess -Name "ActiveUser" -Value $activeuserid
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

Describe "SteamNotInstalled" {
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
    It "Start-Steam" {
        { Start-Steam } | Should -Throw "Cannot find path*"
    }
    It "Stop-Steam" {
        { Stop-Steam } | Should -Throw "Cannot find path*"
    }
    It "Test-SteamAppId" {
        { Test-SteamAppId -AppId 1 } | Should -Throw "Cannot find path*"
    }
    It "Test-SteamUserId" {
        { Test-SteamUserId -UserId 1 } | Should -Throw "Cannot find path*"
    }
}

Describe 'SteamRunning' {
    BeforeAll {
        Install-MockSteam -ProcessId 123123123 -AppIds 456456456 -UserIds 789789789
    }
    It "Get-ActiveProcessId" {
        Get-SteamActiveProcessId | Should -Be 123123123
    }
    It "Get-ActiveUserId" {
        Get-SteamActiveUserId | Should -Be 789789789
    }
    It "Get-SteamExe" {
        Get-SteamExe | Should -Be "TestDrive:\steam\steam.ps1"
    }
    It "Get-SteamPath" {
        Get-SteamPath | Should -Be "TestDrive:\steam"
    }
    It "Get-SteamUserIds" {
        Get-SteamUserIds | Should -Be @(789789789)
    }
    It "Find-SteamAppIdByName-One" {
        Find-SteamAppIdByName "test app" | Should -Be 456456456 
    }
    It "Find-SteamAppIdByName-None" {
        Find-SteamAppIdByName "non-existing app" | Should -Be $null 
    }
    It "Stop-Start-Steam" {
        Get-SteamActiveProcessId | Should -Be 123123123
        Get-SteamActiveUserId | Should -Be 789789789
        Stop-Steam -Milliseconds 0
        Get-SteamActiveProcessId | Should -Be 0
        Get-SteamActiveUserId | Should -Be 0
        Start-Steam -Milliseconds 0
        Get-SteamActiveProcessId | Should -Be 123123123
        Get-SteamActiveUserId | Should -Be 789789789
    }
    It "Test-SteamAppId-True" {
        Test-SteamAppId -AppId 456456456 | Should -BeTrue
    }
    It "Test-SteamAppId-False" {
        Test-SteamAppId -AppId 1 | Should -BeFalse
    }
    It "Test-SteamUserId-True" {
        Test-SteamUserId -UserId 789789789 | Should -BeTrue
    }
    It "Test-SteamUserId-False" {
        Test-SteamUserId -UserId 1 | Should -BeFalse
    }
}
