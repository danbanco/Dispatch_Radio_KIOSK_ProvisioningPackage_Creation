Param([Parameter(Mandatory = $true)][string] $userAccount)

New-LocalUser -Name $userAccount -NoPassword -AccountNeverExpires -UserMayNotChangePassword | Set-LocalUser -PasswordNeverExpires $true

Add-LocalGroupMember -Group Users -Member $userAccount