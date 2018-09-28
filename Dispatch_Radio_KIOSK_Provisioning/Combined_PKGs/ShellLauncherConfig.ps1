Param([Parameter(Mandatory = $true)][string] $userAccount,
									[switch] $Enable,
									[switch] $Disable,
									[switch] $Remove)
# Check if shell launcher license is enabled

function Main()
{
	function Check-ShellLauncherLicenseEnabled
	{
		[string]$source = @"
		using System;
		using System.Runtime.InteropServices;

		static class CheckShellLauncherLicense
		{
		const int S_OK = 0;

		public static bool IsShellLauncherLicenseEnabled()
		{
			int enabled = 0;

			if (NativeMethods.SLGetWindowsInformationDWORD("EmbeddedFeature-ShellLauncher-Enabled", out enabled) != S_OK) {
				enabled = 0;
			}

			return (enabled != 0);
		}

		static class NativeMethods
		{
			[DllImport("Slc.dll")]
			internal static extern int SLGetWindowsInformationDWORD([MarshalAs(UnmanagedType.LPWStr)]string valueName, out int value);
		}

	}
"@

		$type = Add-Type -TypeDefinition $source -PassThru

		return $type[0]::IsShellLauncherLicenseEnabled()
	}

	[bool]$result = $false

	$result = Check-ShellLauncherLicenseEnabled
	"`nShell Launcher license enabled is set to " + $result
	if (-not($result))
	{
		"`nThis device doesn't have required license to use Shell Launcher"
		exit
	}

	$COMPUTER = "localhost"
	$NAMESPACE = "root\standardcimv2\embedded"

	# Create a handle to the class instance so we can call the static methods.
	try {
		$ShellLauncherClass = [wmiclass]"\\$COMPUTER\${NAMESPACE}:WESL_UserSetting"
		} catch [Exception] {
		write-host $_.Exception.Message; 
		write-host "Make sure Shell Launcher feature is enabled"
		exit
		}

	# This well-known security identifier (SID) corresponds to the BUILTIN\Administrators group.

	$Admins_SID = "S-1-5-32-544"

	# Create a function to retrieve the SID for a user account on a machine.

	function Get-UsernameSID($AccountName) 
	{

		$NTUserObject = New-Object System.Security.Principal.NTAccount($AccountName)
		$NTUserSID = $NTUserObject.Translate([System.Security.Principal.SecurityIdentifier])

		return $NTUserSID.Value

	}

	# Get the SID for a user account named "Cashier". Rename "Cashier" to an existing account on your system to test this script.

	$Account_SID = Get-UsernameSID($userAccount)

	# Define actions to take when the shell program exits.

	$restart_shell = 0
	$restart_device = 1
	$shutdown_device = 2

	# Examples. You can change these examples to use the program that you want to use as the shell.

	# This example sets the command prompt as the default shell, and restarts the device if the command prompt is closed. 
	#$ShellLauncherClass.SetDefaultShell("cmd.exe", $restart_shell)

	# Display the default shell to verify that it was added correctly.
	#$DefaultShellObject = $ShellLauncherClass.GetDefaultShell()
	#"`nDefault Shell is set to " + $DefaultShellObject.Shell + " and the default action is set to " + $DefaultShellObject.defaultaction
	
    # Set Explorer as the shell for administrators.
    $ShellLauncherClass.SetCustomShell($Admins_SID, "explorer.exe")

    # Set Internet Explorer as the shell for "RadioOp", and restart the machine if Internet Explorer is closed.
    $ShellLauncherClass.SetCustomShell($Account_SID, "C:\Program Files (x86)\Telex Communications\C-Soft\csoftruntime.exe", ($null), ($null), $restart_shell)	

    if ($Enable)
    {
	    Enable-Shell
    }

    if ($Disable)
    {
	    Disable-Shell
    }
    if ($Remove)
    {
   	    Remove-Shell
    }

	# View all the custom shells defined.
	"`nCurrent settings for custom shells:"
	Get-WmiObject -ErrorAction SilentlyContinue -namespace $NAMESPACE -computer $COMPUTER -class WESL_UserSetting | Select Sid, Shell, DefaultAction
}

# Enable Shell Launcher
function Enable-Shell()
{
    $ShellLauncherClass.SetEnabled($TRUE)
    
    $IsShellLauncherEnabled = $ShellLauncherClass.IsEnabled()

    "`nEnabled is set to " + $IsShellLauncherEnabled.Enabled    
}

# Remove the new custom shells.
function Remove-Shell()
{
    $ShellLauncherClass.RemoveCustomShell($Admins_SID)

    $ShellLauncherClass.RemoveCustomShell($Account_SID)
}

# Disable Shell Launcher
function Disable-Shell()
{
    $ShellLauncherClass.SetEnabled($FALSE)

    $IsShellLauncherEnabled = $ShellLauncherClass.IsEnabled()

    "`nEnabled is set to " + $IsShellLauncherEnabled.Enabled
}

Main