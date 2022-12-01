$DebugPreference = 'Continue'
$ErrorActionPreference = "Stop"
$VerbosePreference = 'SilentlyContinue'
#$VerbosePreference = 'Continue'
$conf = Import-PowerShellDataFile .\conf.psd1

Import-Module .\modules\GitsLogger\GitsLogger.psm1 -Force
Write-LogInfo ("$($conf.Name) start")

Import-Module .\modules\Notifier\Notifier.psm1 -Force -ArgumentList $conf.Notifier
Start-LoadData

Write-LogInfo ("$($conf.Name) finish")