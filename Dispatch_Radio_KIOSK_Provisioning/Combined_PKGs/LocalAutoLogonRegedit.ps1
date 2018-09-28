Param([Parameter(Mandatory = $true)][string] $userAccount)

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

$DefaultUserName = "DefaultUserName"
$DefaultPassword = "DefaultPassword"
$AutoAdminLogon = "AutoAdminLogon"
$PasswordValue = ""
$AutoAdminLogonValue = "1"

IF(!(Test-Path $registryPath))
{
    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $DefaultUserName -Value $userAccount -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $DefaultPassword -Value $PasswordValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $AutoAdminLogon -Value $AutoAdminLogonValue -PropertyType STRING -Force | Out-Null
}
ELSE 
{
    New-ItemProperty -Path $registryPath -Name $DefaultUserName -Value $userAccount -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $DefaultPassword -Value $PasswordValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $AutoAdminLogon -Value $AutoAdminLogonValue -PropertyType STRING -Force | Out-Null
}
