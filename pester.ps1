$config = New-PesterConfiguration
$config.Output.Verbosity = "Detailed"
$config.CodeCoverage.Enabled = $true
Invoke-Pester -Configuration $config
