#================================================
#   OSDCloud Task Sequence
#   Windows 11 22H2 Enterprise us Volume
#   No Autopilot
#   No Office Deployment Tool
#================================================
Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"
Start-Sleep -Seconds 5

#Change Display Resolution for Virtual Machine
if ((Get-MyComputerModel) -match 'Virtual') {
Write-Host -ForegroundColor Green "Setting Display Resolution to 1600x"
Set-DisRes 1600
}

#================================================
#   PreOS
#   Install and Import OSD Module
#================================================
Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
Install-Module OSD -Force
Write-Host -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force

#================================================
#   [OS] Start-OSDCloud with Params
#================================================
Write-Host -ForegroundColor Green "Start OSDCloud"
Start-OSDCloud -ZTI -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume

#================================================
#  WinPE PostOS
#  oobe.cmd
#================================================
Write-Host -ForegroundColor Green "Creating Scripts for OOBE phase"
$OOBEcmdTasks = @'
@echo off
TITLE Setting-up OOBE phase
start /wait C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1
del c:\Windows\Setup\scripts\oobe.*
exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#   WinPE PostOS
#   oobe.ps1
#================================================
$OOBEPS1Tasks = @'
$Title = "OOBE installation/update phase"
$host.UI.RawUI.WindowTitle = $Title
# Change the ErrorActionPreference to 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue' 
# Set Environment
Write-Host "Set Environment" -ForegroundColor Green
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
%env:TEMP = "C:\Windows\Temp"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
# Register PS Modules
Write-Host "Register PSGallery" -ForegroundColor Green
Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -PublishLocation https://www.powershellgallery.com/api/v2/package/ -ScriptSourceLocation https://www.powershellgallery.com/api/v2/items/psscript/ -ScriptPublishLocation https://www.powershellgallery.com/api/v2/package/ -InstallationPolicy Trusted -PackageManagementProvider NuGet
Write-Host "Install-Module PackageManagement" -ForegroundColor Green
Install-Module -Name PackageManagement | Out-Null
$Error.Clear()
Write-Host "Install-Module PowerShellGet" -ForegroundColor Green
Install-Module -Name PowerShellGet | Out-Null
Write-Host -ForegroundColor Green "Install OSD Module"
Install-Module OSD | Out-Null
$Error.Clear()
Write-Host -ForegroundColor Green "Install PSWindowsUpdate Module"
Install-Module PSWindowsUpdate -Force | Out-Null
Write-Host -ForegroundColor Green "Install WinSoftwareUpdate  Module"
Install-Module -Name WinSoftwareUpdate -Scope AllUsers -Force | Out-Null
Write-Host -ForegroundColor Green "Remove Builtin Apps"
# Create array to hold list of apps to remove 
$appname = @( 
"*Microsoft.WindowsAlarms*"
"*microsoft.windowscommunicationsapps*"
"*Microsoft.WindowsFeedbackHub*"
"*Microsoft.ZuneMusic*"
"*Microsoft.ZuneVideo*"
"*Microsoft.WindowsMaps*"
"*Microsoft.Messaging*"
"*Microsoft.MicrosoftSolitaireCollection*"
"*Microsoft.MicrosoftOfficeHub*"
"*Microsoft.Office.OneNote*"
"*Microsoft.WindowsSoundRecorder*"
"*Microsoft.OneConnect*"
"*Microsoft.Microsoft3DViewer*"
"*Microsoft.BingWeather*"
"*Microsoft.Xbox.TCUI*"
"*Microsoft.XboxApp*"
"*Microsoft.XboxGameOverlay*"
"*Microsoft.XboxGamingOverlay*"
"*Microsoft.XboxIdentityProvider*"
"*Microsoft.XboxSpeechToTextOverlay*"
"*Microsoft.XboxGameCallableUI*"
"*Microsoft.Print3D*"
"*Microsoft.LanguageExperiencePacken-gb*"
"*Microsoft.SkypeApp*"
"*Clipchamp.Clipchamp*"
"*Microsoft.GamingApp*"
"*Microsoft.BingNews*"
"*Microsoft.YourPhone*"
"*MicrosoftTeams*"
"*MicrosoftCorporationII.QuickAssist*"
) 
 # Remove apps for all users
 ForEach($app in $appname){ Get-AppxPackage -Name $app | Remove-AppxPackage -Allusers -ErrorAction SilentlyContinue | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-RemoveApps.log" -force
         Write-Host -ForegroundColor DarkCyan "$app"
 } 
Write-Host -ForegroundColor Green "Install Winget Updates"
Update-RSWinSoftware | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-Winget.log" -force
Write-Host -ForegroundColor Green "Install .Net Framework 3.x"
$Result = Get-MyWindowsCapability -Match 'NetFX' -Detail
foreach ($Item in $Result) {
    if ($Item.State -eq 'Installed') {
        Write-Host -ForegroundColor DarkGray "$($Item.DisplayName)"
    }
    else {
        Write-Host -ForegroundColor DarkCyan "$($Item.DisplayName)"
        $Item | Add-WindowsCapability -Online -ErrorAction Ignore | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-WindowsCabability.log" -force
    }
}
Write-Host -ForegroundColor Green "Install Drivers from Windows Update"
$UpdateDrivers = $true
if ($UpdateDrivers) {
    Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot  | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-DriversUpdate.log" -force
}
Write-Host -ForegroundColor Green "Install Windows Updates"
$UpdateWindows = $true
if ($UpdateWindows) {
    Write-Host -ForegroundColor DarkCyan 'Add-WUServiceManager -MicrosoftUpdate -Confirm:$false'
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false  | Out-Null
    Write-Host -ForegroundColor DarkCyan 'Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot'
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot  | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -force
}
Write-Host -ForegroundColor Green "OOBE update phase ready, Restarting in 30 seconds!"
Start-Sleep -Seconds 30
Remove-Item C:\Drivers -Force -Recurse
Remove-Item C:\Intel -Force -Recurse
Remove-Item C:\OSDCloud -Force -Recurse
Restart-Computer -Force
'@
$OOBEPS1Tasks | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.ps1' -Encoding ascii -Force

#================================================
#   PostOS
#   Restart-Computer
#================================================
Write-Host -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
