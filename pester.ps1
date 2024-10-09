$config = New-PesterConfiguration
$config.Output.Verbosity = "Detailed"
$config.CodeCoverage.Path = "SteamScreenshotUtils.psm1"
$config.CodeCoverage.Enabled = $true
Invoke-Pester -Configuration $config
