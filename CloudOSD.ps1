#================================================
#   OSDCloud Task Sequence
#   Windows 11 22H2 Enterprise us Volume
#   No Autopilot
#   No Office Deployment Tool
#================================================
$Title = "Windows OSD phase"
$host.UI.RawUI.WindowTitle = $Title
Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"

#================================================
#   Change the ErrorActionPreference
#   to 'SilentlyContinue' Or 'Continue'
#================================================
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = "SilentlyContinue"
#$ErrorActionPreference = 'Continue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If (([Windows.Forms.SystemInformation]::PowerStatus).PowerLineStatus -ne "Online") {
    Write-Host -ForegroundColor Red "Please insert AC Power, installation might fail if on battery"
    Start-Sleep -Seconds 60
}

Start-Sleep -Seconds 5

#================================================
#   [OS] Start-OSDCloud with Params
#================================================
Start-OSDCloud -ZTI -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume

#================================================
#   [OS] Check for WinPE WiFi and export profiles
#================================================ 
$XmlDirectory = "C:\Windows\Setup\Scripts"
$wifilist = $(netsh.exe wlan show profiles)
Install-Module -Name VcRedist -Force | Out-Null
if ($null -ne $wifilist -and $wifilist -like 'Profiles on interface Wi-Fi*') {
    $ListOfSSID = ($wifilist | Select-string -pattern "\w*All User Profile.*: (.*)" -allmatches).Matches | ForEach-Object {$_.Groups[1].Value}
    $NumberOfWifi = $ListOfSSID.count
    foreach ($SSID in $ListOfSSID){
        try {
            Write-Host -ForegroundColor green "Exporting WiFi SSID:$SSID"
            $XML = $(netsh.exe wlan export profile name=`"$SSID`" key=clear folder=`"$XmlDirectory`")
            }
            catch [System.Exception] {
                Write-Host -ForegroundColor Red "Failed export of Wifi on system"
                Write-Host -ForegroundColor Red "The error is: $XML"
            }
        }
    }
    Else {
        Write-Host -ForegroundColor Yellow $wifilist
    }

#================================================
#  WinPE PostOS
#  oobe.cmd
#================================================
Write-Host -ForegroundColor Green "Creating Scripts for OOBE phase"
$OOBEcmdTasks = @'
@echo off
# Import WiFi XML's if they exist
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\wifi.ps1
# Download and Install PowerShell 7
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\ps.ps1
# Download and Install .Net Framework 7
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\net.ps1
# VcRedist Download and install supported versions
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\VcRedist.ps1
# Check IF VM and install things
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\VM.ps1
# Check IF HP and install things en change the HP Recovery
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\bios.ps1
# Below a PS 7 session for debug and testing in system context, # when not needed 
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1
exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  ps.ps1
#================================================
$OOBEpsTasks = @'
$Title = "OOBE PowerShell 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "PowerShell 7 Download and install" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PowerShell.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\ps.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  VcRedist.ps1
#================================================
$OOBEpsTasks = @'
$Title = "OOBE VcRedist Download and install supported versions"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "VcRedist Download and install supported versions" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-VcRedist.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
Install-Module -Name VcRedist -Force | Out-Null
iex "& { $(irm https://vcredist.com/install.ps1) }" | Out-Null
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\VcRedist.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  wifi.ps1
#================================================
$OOBEnetTasks = @'
$Title = "OOBE Add WiFi SSID's to the system if exist"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "Searching for saved WifI networks" -ForegroundColor Green
$XmlDirectory = "C:\Windows\Setup\Scripts"
$XMLExist = Get-ChildItem -Path $XmlDirectory -Filter '*.xml' -File
If (![String]::IsNullOrEmpty($XMLExist)) {
    Start-Service -Name "WlanSvc"
    Get-ChildItem $XmlDirectory | Where-Object {$_.extension -eq ".xml"} | ForEach-Object {
        write-host "Importing WifI network: $_.name" -ForegroundColor Green
        netsh wlan add profile filename=($XmlDirectory+"\"+$_.name)
    }
    Else {
    write-host "No WiFi profiles found to import" -ForegroundColor Yellow
    }
}
Start-Sleep -Seconds 10
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\wifi.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  net.ps1
#================================================
$OOBEnetTasks = @'
$Title = "OOBE .Net Framework 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host ".Net Framework 7 Download and install" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Framework.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
iex "& { $(irm https://dot.net/v1/dotnet-install.ps1) } -Channel STS -Runtime windowsdesktop"
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\net.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  vm.ps1
#================================================
$OOBEpsTasks = @'
$Title = "Check if machine is a VM"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-VM.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If ((Get-CimInstance -ClassName Win32_computersystem).model -like "VMware*") {
    write-host "Checking latest VMware tools" -ForegroundColor Green
    $vmwareTools = "https://packages.vmware.com/tools/esx/latest/windows/x64/index.html"
    $pattern = "[0-9]+\.[0-9]+\.[0-9]+\-[0-9]+\-x86_64"
    
    #get the raw page content
    $pageContent=(Invoke-WebRequest -UseBasicParsing -Uri $vmwareTools).content
    
    #change one big string into many strings, then find only the line with the version number
    $interestingLine = ($pageContent.split("`n") | Select-string -Pattern $pattern).tostring().trim()
 
    #remove the whitespace and split on the assignment operator, then split on the double quote and select the correct item
    $filename = (($interestingLine.Replace(" ","").Split("=") | Select-string -Pattern $pattern).ToString().Trim().Split("`""))[1]
 
    $url = "https://packages.vmware.com/tools/esx/latest/windows/x64/$($filename)"
    write-host "Downloading and installing $url"
    Invoke-WebRequest -Uri $url -OutFile "C:\Windows\Temp\$filename"
    $params = "/S /v /qn REBOOT=R ADDLOCAL=ALL"
    Start-Process -Wait -NoNewWindow -FilePath "C:\Windows\Temp\$filename" -ArgumentList $params
}
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\vm.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  Bios.ps1
#================================================
$OOBEnetTasks = @'
$Title = "Check Bios settings"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-bios.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If ((Get-CimInstance -ClassName Win32_BIOS).Manufacturer -eq "HP") {
    $SPEndorsementKeyPP = '{"timestamp":"\/Date(1674912404044)\/","purpose":"hp:provision:endorsementkey","Data":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,48,130,3,195,48,130,2,171,160,3,2,1,2,2,20,56,35,129,179,16,219,198,92,253,158,254,127,24,138,168,69,114,181,85,151,48,13,6,9,42,134,72,134,247,13,1,1,11,5,0,48,113,49,11,48,9,6,3,85,4,6,19,2,78,76,49,11,48,9,6,3,85,4,8,12,2,90,72,49,18,48,16,6,3,85,4,7,12,9,65,109,115,116,101,114,100,97,109,49,30,48,28,6,3,85,4,10,12,21,68,101,32,78,101,100,101,114,108,97,110,100,115,99,104,101,32,66,97,110,107,49,12,48,10,6,3,85,4,11,12,3,79,114,103,49,19,48,17,6,3,85,4,3,12,10,119,119,119,46,100,110,98,46,110,108,48,30,23,13,50,49,48,50,50,51,49,48,52,49,49,57,90,23,13,51,49,48,50,50,49,49,48,52,49,49,57,90,48,113,49,11,48,9,6,3,85,4,6,19,2,78,76,49,11,48,9,6,3,85,4,8,12,2,90,72,49,18,48,16,6,3,85,4,7,12,9,65,109,115,116,101,114,100,97,109,49,30,48,28,6,3,85,4,10,12,21,68,101,32,78,101,100,101,114,108,97,110,100,115,99,104,101,32,66,97,110,107,49,12,48,10,6,3,85,4,11,12,3,79,114,103,49,19,48,17,6,3,85,4,3,12,10,119,119,119,46,100,110,98,46,110,108,48,130,1,34,48,13,6,9,42,134,72,134,247,13,1,1,1,5,0,3,130,1,15,0,48,130,1,10,2,130,1,1,0,227,89,24,223,93,139,253,61,213,69,9,13,211,243,82,65,28,235,152,162,48,166,149,58,115,39,179,99,181,66,135,21,145,135,203,123,55,216,194,227,49,13,221,62,216,43,98,65,26,163,136,143,118,218,217,188,178,119,168,149,175,122,52,18,221,247,203,0,166,98,4,38,74,207,66,21,46,103,224,215,30,92,0,21,91,36,75,196,59,38,152,37,118,20,83,241,127,201,214,12,20,67,4,138,119,231,89,3,37,187,16,235,227,80,194,70,224,75,77,90,213,84,202,23,64,55,115,117,0,210,200,251,80,241,52,187,68,22,100,95,10,136,109,117,6,137,211,230,142,123,253,206,74,233,109,228,244,158,146,142,133,203,234,164,173,170,23,100,161,209,14,119,79,164,236,157,233,110,131,203,7,134,187,17,124,211,106,97,241,74,170,67,246,221,134,67,144,155,126,53,110,139,12,107,80,70,40,196,170,138,205,41,51,9,190,203,148,249,146,95,59,167,20,172,19,179,99,137,56,237,216,172,15,115,85,211,91,120,7,91,93,175,38,144,233,140,94,224,130,207,27,169,241,199,223,73,2,3,1,0,1,163,83,48,81,48,29,6,3,85,29,14,4,22,4,20,5,69,215,97,42,167,129,209,197,115,158,19,124,79,228,199,142,226,156,34,48,31,6,3,85,29,35,4,24,48,22,128,20,5,69,215,97,42,167,129,209,197,115,158,19,124,79,228,199,142,226,156,34,48,15,6,3,85,29,19,1,1,255,4,5,48,3,1,1,255,48,13,6,9,42,134,72,134,247,13,1,1,11,5,0,3,130,1,1,0,218,72,194,167,113,76,136,24,253,169,0,106,187,234,177,163,72,233,249,17,67,232,217,116,71,158,71,143,94,199,42,138,250,177,210,144,17,233,106,128,82,77,61,154,20,64,130,221,108,79,211,144,131,224,18,117,70,59,99,8,62,148,165,124,146,5,153,60,104,187,143,246,194,163,51,97,143,154,163,249,68,117,137,74,82,172,200,52,219,102,57,52,166,141,253,163,124,38,111,245,84,147,243,91,101,198,72,170,244,90,11,101,73,149,104,246,49,203,72,125,222,34,174,39,91,137,67,105,58,160,28,124,21,226,80,173,66,171,23,0,162,227,170,89,73,126,137,241,141,116,186,164,21,190,227,1,223,86,205,19,163,252,253,123,203,219,15,136,204,179,41,26,94,109,120,95,218,207,219,248,16,167,84,127,157,125,157,108,151,79,26,172,104,218,10,158,0,167,33,29,97,241,200,118,91,63,53,13,245,135,49,200,254,94,200,67,230,222,60,63,125,150,251,190,107,14,192,148,209,212,202,192,205,94,208,139,54,218,108,54,38,98,30,88,222,175,181,27,131,171,110,17,50,150,57,126],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null}'
    $SPSigningKeyPP = '{"timestamp":"\/Date(1674912404113)\/","purpose":"hp:provision:signingkey","Data":[82,139,68,249,96,42,1,116,196,64,169,15,205,89,191,245,254,165,40,103,196,111,94,1,240,53,163,131,103,149,155,112,183,61,14,195,35,204,50,154,75,205,132,178,11,34,235,235,196,15,42,183,14,254,111,120,103,202,241,172,173,237,187,105,60,148,180,250,234,168,112,185,34,252,119,173,37,212,69,226,238,44,83,137,212,92,73,193,167,180,186,96,73,40,166,17,87,103,219,14,157,156,206,26,162,217,197,79,6,183,51,212,31,88,71,197,242,60,65,234,60,68,70,17,200,71,212,217,154,193,120,219,222,131,204,88,202,255,57,135,22,121,129,42,255,110,171,197,179,64,123,77,123,105,25,215,42,32,179,24,205,182,233,0,91,12,179,241,43,202,243,165,99,152,161,190,132,113,40,65,85,2,219,199,170,60,159,70,108,173,61,225,199,170,1,224,200,35,156,70,167,163,76,88,131,161,198,128,83,103,144,180,75,74,216,52,18,133,206,107,96,70,33,189,213,156,213,75,199,107,18,162,178,6,54,207,201,234,97,77,69,20,114,221,5,230,19,172,175,215,3,79,55,118,36,15,148,34,213,99,199,73,133,162,11,154,129,181,142,76,54,177,235,129,216,226,62,141,175,202,239,23,25,99,230,107,17,246,36,29,35,62,202,211,9,186,115,34,173,77,39,125,10,75,150,36,60,107,60,98,41,203,100,253,12,43,158,59,115,207,166,65,221,48,30,53,252,136,188,169,193,212,141,180,35,26,233,107,97,255,142,231,204,175,194,138,34,43,16,142,8,69,126,23,121,41,221,71,227,168,215,172,21,61,126,46,78,252,134,34,236,99,5,51,168,237,150,65,151,90,174,67,37,55,195,133,11,94,89,147,243,71,130,109,203,163,103,50,168,77,200,163,145,64,140,115,77,80,84,43,126,117,223,90,223,143,2,71,25,93,154,76,118,85,77,147,240,220,198,79,204,172,20,171,214,119,81,54,165,189,99,141,1,170,164,158,46,125,44,39,6,102,228,142,40,168,137,143,129,244,185,176,133,1,144,12,11,239,90,221,171,154,174,249,220,202,11,139,205,170,133,3,105,225,1,224,154,204,193,92,234,221,234,189,96,234,158,31,239,90,22,223,25,43,218,82,151,236,184,162,175,207,50,157,162,203],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null'
    $AgentPayload = '{"timestamp":"\/Date(1674912543980)\/","purpose":"hp:surerecover:provision:recovery_image","Data":[137,77,205,170,37,39,147,203,149,191,64,221,122,162,23,138,53,181,90,156,175,22,48,10,154,103,148,25,213,243,182,197,245,136,230,197,224,175,142,232,40,201,192,25,95,201,179,49,15,96,26,236,197,252,10,157,232,209,226,162,37,106,185,215,167,52,53,104,36,66,0,152,11,130,5,22,168,153,117,122,119,54,77,167,180,71,177,128,49,73,251,20,2,6,91,164,83,4,19,45,12,49,12,152,88,40,49,129,178,15,63,92,148,83,106,204,150,85,73,22,170,231,243,5,118,72,205,227,0,32,43,53,194,50,61,203,211,192,144,136,92,235,4,6,101,140,180,127,96,129,151,235,255,120,173,104,69,225,20,228,42,218,179,148,115,13,191,251,60,30,72,31,74,3,255,160,197,125,131,31,163,209,222,161,96,98,48,103,21,4,204,52,195,246,234,66,177,76,244,36,238,179,80,79,153,47,9,79,130,27,113,175,251,225,1,119,56,142,197,149,214,64,84,69,115,241,149,120,46,109,180,216,46,141,180,176,72,166,233,58,240,151,171,64,222,83,104,13,197,77,212,214,145,228,192,154,31,35,213,99,1,0,139,149,128,98,164,239,109,68,253,226,197,228,58,215,69,72,236,150,216,97,211,126,50,247,19,15,123,130,197,201,44,183,168,205,70,29,61,180,79,108,49,103,33,69,105,166,5,93,66,215,114,85,5,26,129,61,164,153,164,12,196,32,207,137,102,173,118,18,146,211,143,16,75,105,200,34,79,231,196,211,205,102,212,129,247,125,217,59,188,40,166,163,28,140,190,172,165,161,150,219,160,140,235,2,46,193,110,78,188,240,107,65,223,157,1,25,57,145,218,154,54,79,247,132,212,139,215,118,5,155,186,39,187,207,255,185,93,213,69,108,214,98,8,253,77,171,211,241,222,108,35,22,56,105,48,29,24,202,3,99,36,245,177,1,44,3,45,117,22,4,138,212,47,230,158,15,124,185,54,168,87,100,12,147,60,102,32,113,197,18,126,4,5,186,208,203,205,44,205,42,111,1,170,203,16,213,160,88,147,242,32,60,71,108,151,27,138,106,155,215,166,237,131,238,145,44,40,175,217,170,240,179,93,29,225,49,135,32,101,98,113,83,233,81,60,189,207,76,26,45,241,37,209,142,211,194,0,0,104,116,116,112,115,58,47,47,115,116,97,119,115,100,101,112,108,111,121,48,48,49,46,98,108,111,98,46,99,111,114,101,46,119,105,110,100,111,119,115,46,110,101,116,47,111,115,100],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null}'
    Write-Host -ForegroundColor Green "Install HPCMSL Module"
    Install-Module -Name HPCMSL -Force -AcceptLicens | Out-Null
    Write-Host "HP Bios settings check recovery settings" -ForegroundColor Green
    If ((Get-HPSecurePlatformState).State -eq "Provisioned") {
        If (((Get-HPSureRecoverState -All).Agent).url -eq "http://ftp.hp.com/pub/pcbios/CPR") {
            write-host "HP Send recovery payload to BIOS" -ForegroundColor Green
            Set-HPSecurePlatformPayload -Payload $AgentPayload  
        }
	    Else {
	        Write-Host = "HP Recovery location already set"
	    }
    }
    Else {
    	Write-Host "HP Send Provisioning, signing and recovery payload to BIOS" -ForegroundColor Green
	Set-HPSecurePlatformPayload -Payload $SPEndorsementKeyPP
        Set-HPSecurePlatformPayload -Payload $SPSigningKeyPP
        Set-HPSecurePlatformPayload -Payload $AgentPayload  
    }
}
Get-HPSureRecoverState -All
Start-Sleep -Seconds 120
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\bios.ps1' -Encoding ascii -Force

#================================================
#   WinPE PostOS
#   oobe.ps1
#================================================
$OOBEPS1Tasks = @'
$Title = "OOBE installation/update phase"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OOBE.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
write-host "Powershell Version: "$PSVersionTable.PSVersion -ForegroundColor Green

# Change the ErrorActionPreference to 'SilentlyContinue'
#$ErrorActionPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# Set Environment
Write-Host "Set Environment" -ForegroundColor Green
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
#Define Icons
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }

# Register Powershell Modules and install tools
Write-Host "Register PSGallery" -ForegroundColor Green
Register-PSRepository -Default | Out-Null
Write-Host "Install PackageManagement Module" -ForegroundColor Green
Install-Module -Name PackageManagement -Force | Out-Null
Write-Host "Install PowerShellGet Module" -ForegroundColor Green
Install-Module -Name PowerShellGet -Force | Out-Null
Write-Host -ForegroundColor Green "Install OSD Module"
Install-Module OSD -Force | Out-Null
Write-Host -ForegroundColor Green "Install PSWindowsUpdate Module"
Install-Module PSWindowsUpdate -Force | Out-Null
Start-Sleep -Seconds 5

Clear-Host
# Remove apps from system
Write-Host -ForegroundColor Green "Remove Builtin Apps"
# Create array to hold list of apps to remove 
$appname = @( 
"Microsoft.BingNews"
"Microsoft.BingWeather"
"Microsoft.GamingApp"
"Microsoft.GetHelp"
"Microsoft.Getstarted"
"Microsoft.MicrosoftOfficeHub"
"Microsoft.MicrosoftSolitaireCollection"
"Microsoft.People"
"Microsoft.PowerAutomateDesktop"
"Microsoft.Todos"
"Microsoft.WindowsAlarm"
"Microsoft.windowscommunicationsapps"
"Microsoft.WindowsFeedbackHub"
"Microsoft.WindowsMaps"
"Microsoft.Xbox.TCUI"
"Microsoft.XboxGameOverlay"
"Microsoft.XboxGamingOverlay"
"Microsoft.XboxIdentityProvider"
"Microsoft.XboxSpeechToTextOverlay"
"Microsoft.YourPhone"
"Microsoft.ZuneMusic"
"Microsoft.ZuneVideo"
"MicrosoftTeams"
) 
ForEach($app in $appname){
    try  {
          # Get Package Name
          $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app } | Select-Object -ExpandProperty PackageName -First 1
          If (![String]::IsNullOrEmpty($AppProvisioningPackageName)) {
            Write-Host "$($AppProvisioningPackageName) found. Attempting removal ... " -NoNewline
          }
          
          # Attempt removeal if Appx is installed
          If (![String]::IsNullOrEmpty($AppProvisioningPackageName)) {
            Write-Host "removing ... " -NoNewline
            $RemoveAppx = Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -AllUsers
          } 
                   
          #Re-check existence
          $AppProvisioningPackageNameReCheck = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $App }
          If ([string]::IsNullOrEmpty($AppProvisioningPackageNameReCheck) -and ($RemoveAppx.Online -eq $true)) {
                   Write-Host @CheckIcon
                   Write-Host " (Removed)"
            }
        }
           catch [System.Exception] {
               Write-Host " (Failed or $App not on system)"
           }
}
Start-Sleep -Seconds 10

Clear-Host 
Write-Host -ForegroundColor Green "Install .Net Framework 3.x"
$Result = Get-MyWindowsCapability -Match 'NetFX' -Detail
foreach ($Item in $Result) {
    if ($Item.State -eq 'Installed') {
        Write-Host -ForegroundColor DarkGray "$($Item.DisplayName)"
    }
    else {
        Write-Host -ForegroundColor Green "$($Item.DisplayName)"
        $Item | Add-WindowsCapability -Online -ErrorAction Ignore | Out-Null
    }
}
Start-Sleep -Seconds 10

Clear-Host
#Install Driver updates
Write-Host -ForegroundColor Green "Install Drivers from Windows Update"
$UpdateDrivers = $true
if ($UpdateDrivers) {
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-DriversUpdate.log" -force
}

Clear-Host
#Install Software updates
Write-Host -ForegroundColor Green "Install Windows Updates"
$UpdateWindows = $true
if ($UpdateWindows) {
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -force
}
Start-Sleep -Seconds 10

Clear-Host
Write-Host -ForegroundColor Green "OOBE update phase ready, Restarting in 30 seconds!"

Start-Sleep -Seconds 30
Remove-Item C:\Drivers -Force -Recurse | Out-Null
Remove-Item C:\Intel -Force -Recurse | Out-Null
Remove-Item C:\OSDCloud -Force -Recurse | Out-Null
Remove-Item C:\Windows\Setup\Scripts\*.* -Force | Out-Null
Restart-Computer -Force
'@
$OOBEPS1Tasks | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.ps1' -Encoding ascii -Force

#================================================
#   [OOBE] Disable Shift F10
#================================================
$Tagpath = "C:\Windows\Setup\Scripts\DisableCMDRequest.TAG"
If(!(test-path $Tagpath))
    {
      New-Item -ItemType file -Force -Path $Tagpath | Out-Null
      Write-Host -ForegroundColor green "OOBE Shift F10 disabled!"
}
#================================================
#   PostOS
#   Restart-Computer
#================================================
Write-Host -ForegroundColor Green "Restarting in 10 seconds!"
Start-Sleep -Seconds 10
wpeutil reboot
