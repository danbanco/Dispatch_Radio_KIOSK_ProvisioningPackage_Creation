#---------------------------- INSTALL SCRIPT ----------------------------
# DESCRIPTION:	Script designed to install packaged applications
#------------------------------------------------------------------------
Param($InstallFile, [switch] $Uninstall, [switch] $UninstallCurrent, [switch] $Install, [switch] $Repair, [switch] $debug, [switch] $restart, [switch] $SuppressForcedReboot)
$ErrorActionPreference = "Stop"
$intPSver = $host.version.major
IF (!($intPSver -ge 2)) {$intRC=197 ; [System.Environment]::Exit($intRC)}
#Disable file security prompts
[Environment]::SetEnvironmentVariable("SEE_MASK_NOZONECHECKS","1","Process")
#-------------------------- VERSION HISTORY -------------------------
# $version = "XX.XXX" #YYYY-MM-DD - Author Initials - Description
# $version = "02.041" #2014-04-16 - KR - Fixed issue with array add item on PowerShell 4.0.
# $version = "02.042" #2014-05-20 - KR - Fixed issue with arrays not working the same between PowerShell 2.0 and PowerShell 4.0 by making the all arrays global.
# $version = "02.043" #2015-02-03 - JSB - Added GUID as a check for validation.
# $version = "02.044" #2015-04-01 - JSB - Allowed script to continue on 1605 error for items in UninstallStrings.
# $version = "02.045" #2015-08-19 - RW - Updated version comparison to work in Windows 10.
# $version = "02.046" #2015-08-19 - JSB - Alow ANY in the SuccessCodes field.
# $version = "02.047" #2015-08-19 - JSB - Allow XML file to actually be specified with the $InstallFile variable (defaults to install.xml if not specified).
# $version = "02.048" #2015-11-12 - JSB - Added $SuppressForcedReboot switch to skip forced reboots for 1641 exit codes.
$version = "02.049" #2016-01-06 - JSB - Fixed an error in the boolean logic for windows versions.
#------------------------------ SET-UP GUI ------------------------------
Clear-Host
#-------------------------- RETURN CODE VALUES --------------------------
#- SYSTEM ERRORS - http://msdn.microsoft.com/en-us/library/ms681381(v=VS.85).aspx
#- Error -	-	Description
#- 0		-	The operation completed successfully
#- 1012 	- 	The configuration registry key could not be read - Error reading registry
#- 3010	-	The requested operation is successful. Changes will not be effective until the system is rebooted
#- 8344	- 	Insufficient access rights to perform the operation - No administrative rights
#- 14041	- 	XML Manifest Parse Error : Internal error - Error reading XML
#------------------------- CUSTOM ERRORS ------------------------- 
#- Error	-	Description
#- 22000	-	Install.xml could not be found
#- 24001	-	One of the tasks failed
#------------------------- Variables -------------------------
$intRC=" " ; $GLOBAL:arrRC = @() ; $GLOBAL:arrMSIExitCode = @() ; $GLOBAL:arrXMLSectionExitCodes = @()
$GLOBAL:arrProcPkg = @() ; $GLOBAL:arrSuccessCodes = @() ; $strComputer = "." ; $GLOBAL:arrRestartCode = @()
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptPath = split-path $ScriptPath
$ScriptName = [system.io.path]::GetFilenameWithoutExtension($ScriptPath)
$strCompName = $Env:Computername ; $strWinDir=$Env:windir
$quote = [char]34 ; $tab= [char]9 ; $plus=[char]43
[Environment]::SetEnvironmentVariable("SEE_MASK_NOZONECHECKS","1","Process")
#------------------------- DYNAMICALLY POPULATED GLOBAL VARIABLES -------------------------
$strMyDir="" ; $intArch="" ; $intRFC="" ; $strDESC="" ; $intProductVer="" ; $dCachePKG="" ; $LOGFILE="" ; $intRC=197
#********************** FUNCTIONS **********************
#------------------------- Find the location that the script is running from -------------------------
Function fGetLocation ($ScriptPath) {
	$currdir=[system.environment]::CurrentDirectory
	IF (!($currdir -eq $ScriptPath)){$currdir=$ScriptPath}
	IF ($currdir.EndsWith("\")) { $currdir = $currdir -replace ".$"}
	IF (Test-Path "$currdir\PKG\") { $currdir = "$currdir\PKG" }
	Set-Location $currdir
	Return $currdir
}
#------------------------- Get OS Name -------------------------
Function fGetOSName {
	Try {
		$Result = Get-WmiObject -Query "Select Caption From Win32_OperatingSystem"        
		Return $Result.Caption
	} Catch { Return "Operating System Unknown" }
}
#------------------------- Check Processor Architecture -------------------------
Function fGetArch {
	$Processor = Get-WmiObject Win32_Processor | Where { $_.deviceID -eq "CPU0" }	
	Try {If ($Processor.addresswidth -eq "64") {Return "64"} Else {Return "32"} } Catch {Return "32"} 	
}
#------------------------- Find Windows Version -------------------------
Function fGetWinVer {
	$intMajor = [System.Environment]::OSVersion.Version.Major
	$intMinor = [System.Environment]::OSVersion.Version.Minor
	Return "$intMajor.$intMinor"	
}
#------------------------- Find Domain Role ------------------------
Function fFndDomainRole () {
	## Find domain Role of system - "0 = Standalone workstation," "1 = Member workstation," "2 = Standalone server," "3 = Member Server," "4 = Backup Domain Controller," "5 = Primary Domain Controller"
	$arrWin32CompSystem = Get-WmiObject Win32_Computersystem
	$intDR = $arrWin32CompSystem.DomainRole
	Return "$intDR"
}
#------------------------- Subroutine for standard Output to Console and Logfile -------------------------
Function fSTDOUT($text, $Color) {
	If(-Not (Test-Path "$strLog")) { Md "$strLog" -Force > $Null }
	$DateNow = Get-Date	
	IF ($text -eq "") {
		Write-Host
		" " | Out-File $LOGFILE -Append
	} ELSE {	
		If($Color -eq 0) { Write-Host " * $text" -backgroundcolor "Black" }
		ElseIf($Color -eq 1) { Write-Host " * $text"  -backgroundcolor "Black" -ForegroundColor Green }
		ElseIf($Color -eq 2) { Write-Host " * $text" -backgroundcolor "Black" -ForegroundColor Yellow }
		ElseIf($Color -eq 3) { Write-Host " * $text" -backgroundcolor "Black" -ForegroundColor Red }
		ElseIf($Color -eq 4) { Write-Host " *** $text *** " -backgroundcolor "DarkGray" -ForegroundColor White }
		Else { Write-Host " * $text" -backgroundcolor "Black" }
		"$DateNow - $text" | Out-File $LOGFILE -Append
	}	
}
#------------------------- Get XML Attributes -------------------------
Function fGetXmlAtt($XmlPath, $XmlAttribute) {
	Try {
		if (-not $InstallFile) {
			$XmlData = [xml](Get-Content "$strMyDir\Install.xml")
		} else {
			$XmlData = [xml](Get-Content $InstallFile)
		}
		Return $XmlData.SelectSingleNode($XmlPath).GetAttribute($XmlAttribute)
	} Catch {
		fSTDOUT "Fatal Exception: Getting xml attribute, $XmlAttribute - $_" 3 ; $intRC = 14041 ; fFindReturnCodes $intRC
	}
}
#------------------------- Get computer product type -------------------------
Function fProdType ($intDR) {
# Find domain Role of system - "0 = Standalone workstation," "1 = Member workstation," "2 = Standalone server," "3 = Member Server," "4 = Backup Domain Controller," "5 = Primary Domain Controller"	
	TRY {		
		If (($intDR -eq 0) -or ($intDR -eq 1)) { fSTDOUT "Product Type: Workstation"; Return "W" }
		Else { fSTDOUT "Product Type: Server"; Return "S" }
	} CATCH { fSTDOUT "Error: Getting product type - $_" 3 }
}
#------------------------- Check for Install.xml -------------------------
Function fCheckIdb {
	If((-Not(Test-Path $InstallFile)) -and (-Not(Test-Path "$strMyDir\Install.xml")))
		{ fSTDOUT "Fatal Exception: Install.xml could not be found" 3 ; $intRC = 22000 ; fFindReturnCodes $intRC }
}
#------------------------ Administrative Rights check -------------------------
Function fCheckAdminRights {
    $strUSERNAME = $Env:Username
	IF ($strUSERNAME -eq $null) {$strUSERNAME = "NT AUTHORITY\SYSTEM"} else {$strUSERNAME = $Env:Username}
	If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        fSTDOUT "Error: $strUSERNAME does not have administrative rights" 3; $intRC = 8344; fFindReturnCodes
    } ELSE { fSTDOUT "$strUSERNAME does have administrative rights" 1 }
}
#------------------------- Cache Package -------------------------
Function fCachePkg {
	Try {
		If($dCachePKG -eq $True) {
			fSTDOUT "******************* CACHING PACKAGE ************************************"         
			fSTDOUT "Caching package to $strPkgCache\$intRFC\ " 1
			If(-Not (Test-Path "$strPkgCache\$intRFC\")) { Md "$strPkgCache\$intRFC\" -Force > $Null }
			$Parent = $strMyDir |Split-Path
			Copy-Item "$Parent\*" "$strPkgCache\$intRFC" -Rec -Force > $Null            
			# Reset the package source location to the cache for installation
			IF (Test-Path  "$strPkgCache\$intRFC\PKG") { $strMyDir = "$strPkgCache\$intRFC\PKG" ; Set-Location "$strPkgCache\$intRFC\PKG" } ELSE {$strMyDir = "$strPkgCache\$intRFC" ; Set-Location "$strPkgCache\$intRFC"}
		}
	} Catch { fSTDOUT "Error: Caching Package $_" 3 }
}
#------------------------ Process Uninstall, Install, and Repair sections of XML -------------------------
Function fProcPkg {
	#Process the uninstall current section
	#$GLOBAL:arrProcPkg = @()
	If($UninstallCurrent) {   
		fSTDOUT "******************* PACKAGE UNINSTALL CURRENT **************************"
		$intExit1 = fParseXMLSections "Framework/Package/Uninstalls/Uninstall[@Current = 'True']" "Uninstall current"
		$GLOBAL:arrProcPkg += $intExit1
		IF($debug) {fSTDOUT "$tab Process Package - Array Return Codes = $GLOBAL:arrProcPkg"}
		If($Install -ne $True) {fRemoveChgInfoReg $strDept $strAgency $intRFC ; fRemoveCachePkg  $intRFC }
	}
	#Process the uninstall section
	If($Uninstall) {
		fSTDOUT "******************* PACKAGE UN-INSTALL *********************************"
		$intExit1 = fParseXMLSections "Framework/Package/Uninstalls/Uninstall" "Uninstall"
		IF (Test-Path "$strMyDir\UninstallStrings.txt") { $intExit2=fUninstallOLD; $GLOBAL:arrProcPkg += $intExit2}
		$GLOBAL:arrProcPkg += $intExit1
		IF($debug) {fSTDOUT "$tab Process Package - Array Return Codes = $GLOBAL:arrProcPkg"}
		If($Install -ne $True) {fRemoveChgInfoReg $strDept $strAgency $strBranch $intRFC ; fRemoveCachePkg  $intRFC}
	}
	#Process the install section
	If($Install) {
		fSTDOUT "******************* PACKAGE INSTALLATION *******************************"
		$intExit1 = fParseXMLSections "Framework/Package/Installs/Install" "Install"
		If($intExit1 -eq 0){ fWriteChgInfoReg $strDept $strAgency $strBranch $intRFC }
		$GLOBAL:arrProcPkg += $intExit1
		IF($debug) {fSTDOUT "$tab Process Package - Array Return Codes = $GLOBAL:arrProcPkg"}
	}    
	#Process the repair section
	If($Repair) {
		fSTDOUT "******************* PACKAGE REPAIR *************************************"
		$intExit1 = fParseXMLSections "Framework/Package/Repairs/Repair" "Repair"
		$GLOBAL:arrProcPkg += $intExit1
		IF($debug) {fSTDOUT "$tab Process Package - Array Return Codes = $GLOBAL:arrProcPkg"}
	}
	Return ,$GLOBAL:arrProcPkg
}
#------------------------ Process Cleanup section of XML -------------------------
Function fCleanup {
	Try {
		$strCached = fGetXmlAtt "Framework/Cleanup/PkgRemove" "Cache"
		IF (!($strCached -eq "")) {
			$arrCached = $strCached.split(";")
			ForEach ($intRemove in $arrCached) { fRemoveCachePkg $intRemove }
		}
	} Catch { fSTDOUT "Error: Cleaning during cleanup $_" 3 }
}
#------------------------- Remove Cache -------------------------
Function fRemoveCachePkg ($intRemove) {
    Try {
	If (Test-Path "$strPkgCache\$intRemove\") {
		fSTDOUT "******************* CLEAN UP CACHE *************************************"
		Set-Location "C:"
		Remove-Item "$strPkgCache\$intRemove" -Recurse -Force > $Null
		fSTDOUT "Removed Cached package from $strPkgCache\$intRemove\" 1
		#Reset the package source location to the place the script started from
		$strMyDir = fGetLocation $ScriptPath
		Set-Location "$strMyDir"
        }
    } Catch { fSTDOUT "Error: Removing cached package - $_" 3 }
}
#------------------------ Uninstall old software reading from Uninstallstrings.txt -------------------------
Function fUninstallOLD {
	Try {
		IF ($debug) {fSTDOUT "Parsing Product IDs from UninstallStrings.txt ..."}
		$arrUninstallStrings = Get-Content "$strMyDir\UninstallStrings.txt"
		$strUninstallLocations = "HKLM:\software\Microsoft\Windows\CurrentVersion\uninstall;HKLM:\software\Wow6432Node\Microsoft\Windows\CurrentVersion\uninstall" 
		$arrUninstallLocations = $strUninstallLocations.split(";")
		Foreach ($strGUID in $arrUninstallStrings) {			
			IF ($debug) {fSTDOUT "$tab Uninstall Product ID: $strGUID"}
			FOREACH ($uninstallkey in $arrUninstallLocations) {			
				$Uninstallkey="$uninstallkey\$strGUID"
				If((fCheckVal "REGISTRY" $Uninstallkey $True) -eq $True) {fStdOut "$strGUID will be un-installed"; $MSIExitCode = fUninst $strGUID ; $GLOBAL:arrMSIExitCode += $MSIExitCode}
			}		
		}
		Return ,$GLOBAL:arrMSIExitCode
	} Catch {fSTDOUT "Error: Running uninstalls from uninstallstrings.txt - $_" 3 ; Return -1}
}

Function fUninst ($strGUID) {
	# MsiExec.exe /X %strGUID% /qn /norestart /l* $strArchive\%CMICR%\%RFC%-%SCR%.%strGUID%.msi.Uninst.log
	$Executable = "msiexec.exe"
	$Arguments = "/X $strGUID /qn /norestart /l* $strLog\$strGUID.msi.Uninst.log"
	$err9 = (Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -Passthru -WindowStyle Minimized).ExitCode
	$intRC = $err9	
	$strUninstallLocations2 = "HKLM:\software\Microsoft\Windows\CurrentVersion\uninstall;HKLM:\software\Wow6432Node\Microsoft\Windows\CurrentVersion\uninstall" 
	$arrUninstallLocations2 = $strUninstallLocations2.split(";")
	IF ($debug) {fSTDOUT "$tab Uninstall Start Process Error: $err9"}
	IF (($err9 -eq 0) -OR ($err9 -eq 3010) -OR ($err9 -eq 1641) -OR ($err9 -eq 1605)) {
		FOREACH ($uninstallkey2 in $arrUninstallLocations2) {
			$Uninstallkey2="$uninstallkey2\$strGUID"
			If((fCheckVal "REGISTRY" $Uninstallkey2 $True) -eq $True) {Remove-Item "$Uninstallkey2" -force}
		}
		fStdOut "Info: $strGUID was uninstalled, exited with a $err9"
	} ELSE {
		fSTDOUT "Error: Uninstall of $strGUID FAILED with $err9" 3
		fFindReturnCodes $err9
	}
	Return $err9
}
#------------------------ Parse XML sections -------------------------
Function fParseXMLSections($XmlPath, $Task) {
	Try {
		if (-Not $InstallFile) {
			$XmlData = [xml](Get-Content "$strMyDir\Install.xml")
		} else {
			$XmlData = [xml](Get-Content $InstallFile)
		}
		$XmlNodes = $XmlData.SelectNodes($XmlPath)        
		ForEach ($XmlNode In $XmlNodes) {
			# Get the global section attribute values
			$Name = $XmlNode.GetAttribute("Name")
			$strProdWanted = $XmlNode.GetAttribute("ProdType")
			$Platform = $XmlNode.GetAttribute("Platform")
			$arrPlatforms = $Platform.Split(" ")
			$Architecture = $XmlNode.GetAttribute("Architecture")
        
			#Get the section node values
			$ValidateType = $XmlNode.ValidateType
			$ValidationBoolean = $XmlNode.ValidationBoolean
			IF ($ValidationBoolean -eq "True"){$ValidationBoolean = $True} ELSE {$ValidationBoolean = $False}
			$ValidateValue = $XmlNode.ValidateValue           
			$Executable = $XmlNode.Executable
			$Arguments = $XmlNode.Arguments
			$SuccessCodes = $XmlNode.SuccessCodes
			$arrSC = $SuccessCodes.split(", ")
			FOREACH ($SC in $arrSC) {$SC = $SC.Trim(); $GLOBAL:arrSuccessCodes += $SC}
			$WaitAfter = $XmlNode.WaitAfter
			$WaitType = $XmlNode.WaitType
			$WaitValue = $XmlNode.WaitValue
			$WaitTimeOut = $XmlNode.WaitTimeOut
			
			#Replace items in information from XML nodes
			$Executable = $Executable -replace "LDIR", "$strLog"
			$Executable = $Executable -replace "CDIR", "$strPkgCache"
			$Executable = $Executable -replace "RFC", "$intRFC"
			$Executable = $Executable -replace "WINDIR", "$strWinDir"
			$Executable = $Executable -replace "PKGDIR", "$strMyDir"
			$Arguments = $Arguments -replace "LDIR", "$strLog"
			$Arguments = $Arguments -replace "CDIR", "$strPkgCache"
			$Arguments = $Arguments -replace "RFC", "$intRFC"
			$Arguments = $Arguments -replace "WINDIR", "$strWinDir"
			$Arguments = $Arguments -replace "PKGDIR", "$strMyDir"			
 
			#Test System Architecture
			IF(($intArch -eq $Architecture) -OR ($Architecture -eq "B") -OR ($Architecture -eq "")){
				#Test Product Type
				IF (($strProdWanted -eq $strProdType) -OR ($strProdWanted -eq "B") -OR ($strProdWanted -eq "")){
					#Test platform
					IF ($debug) {fSTDOUT "$tab Platforms listed: $Platform"}
					IF ($debug) {fSTDOUT "$tab OS Ver: $intVer"}
					FOREACH ($num in $arrPlatforms){
						IF ($debug) {fSTDOUT "$tab Num being checked: $num"}
						IF ($num.contains("+")){
							# Perform Minimum OS Check - Is the current platform of the system greater than or equal to the OS listed in the XML
							$num = $num -replace "[/\+/g]", ""
						    [double]$intnum = $num -as [double]
                            [double]$intVer = $intVer -as [double]
                            IF ($debug) {fSTDOUT "$tab Num after replace: $num"}
							IF($intVer -ge $intnum){$bValidOS=$True} ELSE {$bValidOS=$False ; $logtext = "Skipping $Name $Task (Un-supported OS, minimum OS version $intnum)..."}
						}ELSE{
                            [double]$intnum = $num -as [double]
                            [double]$intVer = $intVer -as [double]
							# Perform Absolute OS Check - Is the current platform of the system equal to the OS listed in the XML
							IF($intVer -eq $intnum){$bValidOS=$True} ELSE {$bValidOS=$False ; $logtext = "Skipping $Name $Task (Does not apply to $intnum)..."}
						}					
					}
					IF($bValidOS) {
					#Validate the validation entry
					If(((fCheckVal $ValidateType $ValidateValue $ValidationBoolean) -eq $ValidationBoolean)) {
						fSTDOUT "Performing $Task of $Name" 4
						$Arguments = $Arguments.Trim()						
						#For Windows XP, append path to "Setup.exe"
						If($Executable.ToUpper() -eq "SETUP.EXE") { $Executable = "$strMyDir\$Executable" }						
						fSTDOUT "Executing executable: $Executable"
						fSTDOUT "with arguments: $Arguments"
						# If(!(test-path $Executable)) {fSTDOUT "Fatal Exception: Executable File $Executable does not exist..." 3 ; $intRC = 2 ; fFindReturnCodes $intRC}
						If($Arguments) { $ExitCode = (Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -Passthru -WindowStyle Minimized).ExitCode } Else { [string] $ExitCode = (Start-Process -FilePath $Executable -Wait -Passthru -WindowStyle Minimized).ExitCode }						
						#Set the last returned code
						$GLOBAL:arrXMLSectionExitCodes += ,$ExitCode						
						If(fCheckSuccessCodes $SuccessCodes $ExitCode) {
							fSTDOUT "$Task completed SUCCESSFULLY with exit code: $ExitCode" 1
							$GLOBAL:arrXMLSectionExitCodes += ,0
						} Else {
							fSTDOUT "Fatal Exception: $Task FAILED with exit code: $ExitCode" 3                        
							fFindReturnCodes $ExitCode
						}										   
						#Run the wait routine
						If ($Validate) {
							$Validate = fCheckVal $ValidateType $ValidateValue $ValidationBoolean
							If($Validate -eq $True) { fSTDOUT "Install validation reported: $Validate" 1 } Else { fSTDOUT "Install validation reported: $Validate" 3 }
						}
						If($WaitAfter -eq $True) { fStartWait $WaitType $WaitValue $WaitTimeOut }
					} Else { fSTDOUT "Skipping $Name $Task (Validation passed)..." 2 ; $GLOBAL:arrXMLSectionExitCodes += ,0}                
				} Else { fSTDOUT $logtext 2 ; $GLOBAL:arrXMLSectionExitCodes += ,0}
				} ELSE {fSTDOUT "Skipping $Name $Task (Un-supported product type, product should be type=$strProdWanted)..." 2 ; $GLOBAL:arrXMLSectionExitCodes += ,0}
			} ElSE {fSTDOUT "Skipping $Name $Task (Un-supported system architecture, Architecture should be $Architecture)..." 2 ; $GLOBAL:arrXMLSectionExitCodes += ,0}
		}
		IF($debug) {fSTDOUT "$tab Parse XML Function - Array XML Section Exit Codes = $GLOBAL:arrXMLSectionExitCodes"}
		Return ,$GLOBAL:arrXMLSectionExitCodes
	}
	Catch { fSTDOUT "Fatal Exception: Processing $Name $Task  $_" 3 ; $intRC = 24001 ; fFindReturnCodes $intRC }
}
#------------------------- Write Change Information into Registry -------------------------
Function fWriteChgInfoReg ($strDept, $strAgency, $strBranch, $intRFC) {
	IF ($dAdminCheck){
		Try {
			$RegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $Env:Computername)
			$NumInstall = $RegKey.OpenSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC").GetValue("NumTimesInstalled")
			$NumInstall = [int]$NumInstall + 1
		} Catch {
			$RegKey.CreateSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC") > $Null
			$NumInstall = 1
		}    
		Try {
			$RegKey.OpenSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC", $True).SetValue("Date Installed", [string] (Get-Date).ToShortDateString(), [Microsoft.Win32.RegistryValueKind]::String)
			$RegKey.OpenSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC", $True).SetValue("Description", [string] $strDESC, [Microsoft.Win32.RegistryValueKind]::String)
			$RegKey.OpenSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC", $True).SetValue("NumTimesInstalled", [int] $NumInstall, [Microsoft.Win32.RegistryValueKind]::String)
			$RegKey.OpenSubKey("Software\$strDept\$strAgency\$strBranch\Changes\$intRFC", $True).SetValue("Version", [string] $intProductVer, [Microsoft.Win32.RegistryValueKind]::String)
			fSTDOUT "Wrote Change information into HLKM\Software\$strDept\$strAgency hive..." 1
		} Catch {
			fSTDOUT "Fatal Exception: Adding Change Info to Registry -Error: $_" 3 ; $intRC = 1013 ; fFindReturnCodes $intRC
		}
	} ELSE {fSTDOUT "This is being run without administrative rights change information is not being recorded in the registry"}
}
#------------------------- Remove Change Information from Registry -------------------------
Function fRemoveChgInfoReg ($strDept, $strAgency, $strBranch, $intRFC) {
	IF ($dAdminCheck){
		Try {
			$strUninstallLocations2 = "HKLM:\Software\$strDept\$strAgency\$strBranch\Changes\$intRFC;HKLM:\software\Wow6432Node\$strDept\$strAgency\$strBranch\Changes\$intRFC" 
			$arrUninstallLocations2 = $strUninstallLocations2.split(";")
			FOREACH ($uninstallkey2 in $arrUninstallLocations2) {
				If((fCheckVal "REGISTRY" $Uninstallkey2 $True) -eq $True) {Remove-Item "$Uninstallkey2" -force ; fSTDOUT "Removed Change information from HLKM\Software\$strDept\$strAgency hive..." 1}
			}
		} Catch {
			fSTDOUT "Fatal Exception: Removing Change Info from Registry -Error: $_" 3 ; $intRC = 1011 ; fFindReturnCodes $intRC	
		}
	} ELSE {fSTDOUT "This is being run without administrative rights change information is not being removed from the registry"}
}
#------------------------------------------------------------------------
Function fRestartSystem ($intRFC) {
$ErrorActionPreference = "Stop"
Try {
		$Timeout=10
		$Comment="The system, $strCompName, is being rebooted for project $intRFC"
		$Flag=6
		$strFlagDescription="Forceful Reboot"
		$OS  = Get-WMIObject -Class Win32_OperatingSystem
		fByPassBDE
		fByPassMEE
		IF ($intVer -lt "6.0") {
			IF ($debug) {fSTDOUT "Use Win32Shutdown"}
			fSTDOUT "$strCompName will perform a $strFlagDescription"
			fSTDOUT "Comment: $Comment"
			Sleep 5
			$OS.psbase.Scope.Options.EnablePrivileges = $true
			$OS.Win32Shutdown($Flag) > $Null
			$intRC = 1641 ; Return ,1641
		} ELSEIF ($intVer -ge "6.0") {
			IF ($debug) {fSTDOUT "Use Win32ShutdownTracker"}
			fSTDOUT "$strCompName will perform a $strFlagDescription"
			fSTDOUT "Comment: $Comment"
			Sleep 5
			$OS.psbase.Scope.Options.EnablePrivileges = $true
			$OS.Win32ShutdownTracker($Timeout,$Comment,2147745794,$Flag) > $Null
			$intRC = 1641 ; Return 1641
		} ELSE { IF ($debug) {fSTDOUT "Failed to match OS version"} ; Return }
	} Catch { fSTDOUT "Error: Reboot was not initiated - $_" 3 }
}
#------------------------- Bypass BitLocker Device Encryption PIN screen -------------------------
Function fByPassBDE {
	Try {
		fWriteRegValue "HKLM:\Software\USDA" "BypassBde" 1 "DWord"
		IF ($Env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {$SystemPath="Sysnative"} else {$SystemPath="System32"}
		$Executable="$Env:Windir\$SystemPath\CMD.EXE"
		$Arguments=" /C $Env:Windir\System32\Manage-bde.exe -protectors -disable c:"
		IF ($debug) {fSTDOUT "Executable = $Executable"}
		IF ($debug) {fSTDOUT "Arguments = $Arguments"}
		If((Test-Path("C:\Program Files\Microsoft\MDOP MBAM\MBAMAgent.exe")) -OR (Test-Path("C:\Program Files (x86)\Microsoft\MDOP MBAM\MBAMAgent.exe"))) {
			fSTDOUT "Running BDE Bypass..."
			$ExitCode = (Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -Passthru -WindowStyle Normal).ExitCode
			IF ($debug) {fSTDOUT "Manage-BDE exit code: $ExitCode"}
			IF ($ExitCode -eq 0) {
				# Success
			} ElseIF ($ExitCode -eq -2144845809) {fSTDOUT "Warning: A compatible TPM security device cannot be found on this computer" }
			ELSE {
				fSTDOUT "Error: BDE PIN has NOT been disabled"
			}
		}
	} Catch { fSTDOUT "Error: Creating BDE Bypass - $_" 3 }
}
#------------------------- Bypass McAfee Endpoint Encryption pre-boot login -------------------------
Function fByPassMEE {
	Try {
		fWriteRegValue "HKLM:\Software\USDA" "SFDeny" "1" "String"
		If(Test-Path("C:\Program Files\McAfee\Endpoint Encryption for PC\SbAdmcl.exe")) {$Executable="C:\Program Files\McAfee\Endpoint Encryption for PC\SbAdmcl.exe"}
		ELSEIf(Test-Path("C:\Program Files(x86)\McAfee\Endpoint Encryption for PC\SbAdmcl.exe")) {$Executable="C:\Program Files(x86)\McAfee\Endpoint Encryption for PC\SbAdmcl.exe"}
		ELSE { Return }
		$Arguments=" -command:disablesecurity"
		IF ($debug) {fSTDOUT "Executable = $Executable"}
		IF ($debug) {fSTDOUT "Arguments = $Arguments"}
		fSTDOUT "Running MEE Bypass..."
		$ExitCode = (Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -Passthru -WindowStyle Normal).ExitCode
		IF ($debug) {fSTDOUT "MEE bypass exit code: $ExitCode"}
		IF ($ExitCode -eq 0) {
			# Success
		} ELSEIF ($ExitCode -eq -536543178) {
			fSTDOUT "Warning: Autoboot user already exists"
		} ELSE {
				fSTDOUT "Error: MEE pre-boot NOT disabled, $ExitCode"
		}	
	} Catch { fSTDOUT "Error: Creating MEE Bypass - $_" 3 }
}
#------------------------- Get Registry Value -------------------------
Function fGetRegValue($Key, $Value) {
	Try { Return (Get-ItemProperty $Key $Value).$Value
	} Catch { Return "-1" }
}
#------------------------- Write Registry Value -------------------------
Function fWriteRegValue($KeyPath, $Key, $Value, $Type) {
	Try {
		If((fGetRegValue $KeyPath $Key) -eq "-1") {
			If(-Not (Test-Path $KeyPath)) { Md $KeyPath }            
			New-ItemProperty $KeyPath -Name $Key -Value $Value -PropertyType $Type
		} Else { Set-ItemProperty $KeyPath -Name $Key -Value $Value }
	} Catch {
		fSTDOUT "Fatal Exception: $_" 3 ; $intRC = 1013 ; fFindReturnCodes $intRC   
	}
}
#------------------------- Check Success Codes -------------------------
Function fCheckSuccessCodes($SplitCodes, $ExitCode) {
	Try {
		If($SplitCodes.Trim() -eq "ANY") { Return $True }
		
		$CodeArray = $SplitCodes.Split(",")
		ForEach ($Code In $CodeArray) {
			If($Code.Trim() -eq $ExitCode.ToString()) { Return $True }
		}
		Return $False
	} Catch {
		Return $False
	}
}
#------------------------- Check Values -------------------------
Function fCheckVal($ValueType, $Value, $Default) {
	Try {
		If($ValueType.ToUpper() -eq "REGISTRY") { $Value = $Value.Replace("HKLM\", "HKLM:\") }
		If($ValueType.ToUpper() -eq "REGISTRY") { $Value = $Value.Replace("HKCU\", "HKCU:\") }
		If($ValueType.ToUpper() -eq "REGISTRY") { $Value = $Value.Replace("HKCR\", "HKCR:\") }
		# $test = fCheckFreeSpace $Value
		# write-host "Check freespace evaluated to $test"
		Switch($ValueType.ToUpper()) {
			"FILE" { Test-Path $Value }
			"FILEVERSION" { fCheckFileVer $Value }
			"FREESPACE" { fCheckFreeSpace $Value }			
			"DIRECTORY" { Test-Path $Value }
			"REGISTRY" { Test-Path $Value }
			"REGVALUE" {fFindRegValue $Value}
			"GUID" { fCheckGUID $Value }
			"PROCESS" { fCheckPrcExist $Value }
			"SERVICE" { fCheckService $Value }			
			default { $Default }
		}
	} Catch {
		Return $False
	}
}
#------------------------- Check for file version -------------------------
Function fCheckFileVer($SplitFile) {
	Try {
		$FileArray = $SplitFile.Split("|")
		If($FileArray.Count -gt 1) {
			If((Get-Command $FileArray[0]).FileVersionInfo.FileVersion -eq $FileArray[1]) { Return $True }
		}        
		Return $False
	} Catch {
		Return $False
	}
}
#------------------------- Check for Process existence -------------------------
Function fCheckPrcExist($ProcessName) {
	Try {
		If((Get-Process $ProcessName).ID) { Return $True }
		Return $False
	} Catch {
		Return $False
	}
}
#------------------------- Wait for item before continuing -------------------------
Function fStartWait($WaitType, $WaitValue, $TimeOut) {
	Try{	
		fSTDOUT "Waiting on $WaitType for $WaitValue..."
		#Fix any bad registry feeds
		If($WaitType.ToUpper() -eq "REGISTRY") { $WaitValue = $WaitValue.Replace("HKLM\", "HKLM:\") }
		If($WaitType.ToUpper() -eq "REGISTRY") { $WaitValue = $WaitValue.Replace("HKCU\", "HKCU:\") }
		If($WaitType.ToUpper() -eq "REGISTRY") { $WaitValue = $WaitValue.Replace("HKCR\", "HKCR:\") }
		$Counter = 0
		Do {
			Switch($WaitType.ToUpper()) {
				"FILE" { If(Test-Path $WaitValue) { $Counter = $TimeOut } }
				"DIRECTORY" { If(Test-Path $WaitValue) { $Counter = $TimeOut } }
				"REGISTRY" { If(Test-Path $WaitValue) { $Counter = $TimeOut } }
				"REGVALUE" { If(fFindRegValue $WaitValue) { $Counter = $TimeOut } }
				"PROCESSSTART" { If(fCheckPrcExist $WaitValue) { $Counter = $TimeOut } }
				"PROCESSEND" { If((fCheckPrcExist $WaitValue) -eq $False) { $Counter = $TimeOut } }
				"SERVICE" { If(fCheckService $WaitValue) { $Counter = $TimeOut } }
				default { $Counter = $TimeOut }
			}           
			Sleep 1       
			$Counter += 1
		} While ( $Counter -lt $TimeOut )
	}Catch { fSTDOUT "Wait Failed: Processing $WaitValue - $_" 3 ; $intRC = 24061 ; fFindReturnCodes $intRC }
}
#------------------------- Find registry value -------------------------
Function fFindRegValue($Value){
	TRY {
		fSTDOUT "Checking for Registry value, $Value ..."
		$arrRegistryValue = $Value.split(";")
		$strRegistryPath = $arrRegistryValue[0]
		$strValueName = $arrRegistryValue[1]
		$strValueData = $arrRegistryValue[2]	
		$strRegistryPath = $strRegistryPath.Replace("HKLM\", "HKLM:\")
		$strRegistryPath = $strRegistryPath.Replace("HKCU\", "HKCU:\")	
		$strRegistryPath = $strRegistryPath.Replace("HKCR\", "HKCR:\")
		IF (Test-Path $strRegistryPath) {
			$strActualValueData = fGetRegValue $strRegistryPath $strValueName
			IF ($strActualValueData -eq $strValueData) {fSTDOUT "Success: $Value was found!" ; Return $True} else {Return $False}	
		} ELSE { Return $False}
	} CATCH {
		fSTDOUT "Check Registry value Failed: Processing $Value - $_" 3
	}
}
#------------------------- Find registry GUID -------------------------
Function fCheckGUID ($strGUID) {
	Try {
		fSTDOUT "Checking for Registry GUID, $Value ..."
		$strUninstallLocations = "HKLM:\software\Microsoft\Windows\CurrentVersion\uninstall;HKLM:\software\Wow6432Node\Microsoft\Windows\CurrentVersion\uninstall" 
		$arrUninstallLocations = $strUninstallLocations.split(";")
		FOREACH ($uninstallkey in $arrUninstallLocations) {			
			$Uninstallkey="$uninstallkey\$strGUID"
			If((fCheckVal "REGISTRY" $Uninstallkey $True) -eq $True) {
				fSTDOUT "Success: $Value was found!";
				Return $True;
			}
		}
		Return $False
	} Catch {
		fSTDOUT "Check GUID value Failed: Processing $Value - $_" 3
	}
}
#------------------------- Check service existence and status -------------------------
Function fCheckService ($Value){
	TRY {
		fSTDOUT "Checking for service, $Value ..."
		$Value = $Value.ToUpper()
		$arrServiceInfo = $Value.split(";")
		$strServiceName = $arrServiceInfo[0]
		$strServiceStatus = $arrServiceInfo[1]
		$AllServiceInfo = get-service
		FOREACH ($service in $AllServiceInfo) {
			$CurrServiceName = $service.ServiceName
			$CurrServiceName = $CurrServiceName.ToString()
			$CurrServiceName = $CurrServiceName.ToUpper()			
			$CurrServiceStatus = $service.Status
			$CurrServiceStatus = $CurrServiceStatus.ToString()
			$CurrServiceStatus = $CurrServiceStatus.ToUpper()
			IF (($CurrServiceName -eq $strServiceName) -and ($CurrServiceStatus -eq $strServiceStatus)) {fSTDOUT "Success: $Value was found!" ; Return $True}	
		}
		Return $False
	} CATCH {
		fSTDOUT "Check Service Failed: Processing $Value - $_" 3
	}
}
#------------------------- Find free space -------------------------
Function fCheckFreeSpace($Value) {
	TRY {
		fSTDOUT "Checking freespace, $Value ..."
		$arrSpaceValues = $Value.split(";")
		$strDriveLetter = $arrSpaceValues[0]
		$strDriveLetter = $strDriveLetter + ":"
		$strSpaceWanted = $arrSpaceValues[1]
		$strSpaceWanted = [int]$strSpaceWanted	
		$strMeasure = $arrSpaceValues[2]
		#Find actual free space on drive specified
		IF (test-path $strDriveLetter) {
			$strDiskInfo = Get-WmiObject -Class Win32_LogicalDisk |Where {$_.DeviceID -eq "$strDriveLetter"}
			$strFreespace1 = $strDiskInfo.FreeSpace
			IF ($strMeasure -eq "GB") {$spaceconstant = "1GB"} ELSE {$spaceconstant = "1MB"}
			$strFreespace = $strFreespace1/$spaceconstant
			$Actualspace = "{0:N2}" -f $strFreespace
			# write-host "$tab Actual freespace on $strDriveLetter = $Actualspace"
			$Actualspace = [int]$Actualspace	
			IF ($Actualspace -ge $strSpaceWanted) {fSTDOUT "Success: Freespace requested, $Value, was found!" ; Return $True} 
			ELSE {fSTDOUT "Error: Requested freespace on $strDriveLetter is $strSpaceWanted $strMeasure; actual drive space on $strDriveLetter is $Actualspace $strMeasure"; Return $False}
		
		} ELSE {fSTDOUT "Error: Drive letter, $strDriveLetter, does not exist"; Return $False}
	} CATCH {
		fSTDOUT "Check Freespace Failed: Processing $Value - $_" 3
	}
}
#------------------------- EXIT Script Subroutine with Return Code -------------------------
Function fFindReturnCodes($GLOBAL:arrRC) {
	IF ($debug) {fSTDOUT "$tab Return Codes: $GLOBAL:arrRC"}
	IF ($GLOBAL:arrRC -Contains "1641"){
		IF ($SuppressForcedReboot) {
			IF ($debug) {fSTDOUT "$tab 1641 was found within return code array, but forced reboots have been supressed.  The system will have the bypass setup so that i can be restarted by the user."}
			$intRC = 1641; fByPassBDE; fByPassMEE
			fClose $intRC
		} ELSE {
			IF ($debug) {fSTDOUT "$tab 1641 was found within return code array.  The system will be restared."}
			$GLOBAL:arrRestartCode += fRestartSystem $intRFC
			$intRC = 1641
			fClose $intRC
		}
	} 
	ELSEIF ($GLOBAL:arrRC -Contains "3010"){
		IF ($debug) {fSTDOUT "$tab 3010 was found within return code array.  The system will have the bypass setup so that it can be restarted by the user."}
		$intRC = 3010 ; fByPassBDE; fByPassMEE
		fClose $intRC
	} 
	ELSEIF ($GLOBAL:arrRC -Contains "0") {
		IF ($debug) {fSTDOUT "$tab 0 was found within return code array, checking the XML and command line for restarts..."}
		IF (($drestartXML -eq "True") -OR ($restart)) {$intRestartCode = fRestartSystem $intRFC}
		IF($intRestartCode -ne $null){$intRC = $intRestartCode; fClose $intRC} ELSE {$intRC = 0;fClose $intRC}
	} ELSE {
		IF ($debug) {fSTDOUT "$tab No success codes were found."}
		FOREACH ($item in $GLOBAL:arrRC){
			$intRC = $item
			IF ($debug) {fSTDOUT "$tab intRC: $intRC"}
			fClose $intRC
		}
	}
}
Function fClose($intRC) {
	IF ($debug) {fSTDOUT "$tab intRC: $intRC"}
	fSTDOUT "************************************************************************" 
	fSTDOUT "Returning Final Exit Code: $intRC"    
	fSTDOUT "************************************************************************"    
	Sleep 5	
	$intRC=[int]$intRC
	[System.Environment]::Exit($intRC)	
	Exit
}
#------------------------- This is the main subroutine that runs all of the functions  -------------------------
Function fMain {    
	fSTDOUT ""
	fSTDOUT "************************************************************************"
	fSTDOUT "$strBranch Installation Wrapper v$version" 1
	fSTDOUT "******************** PACKAGE INFORMATION *******************************"
	fSTDOUT "Description: $strDESC $intProductVer"	
	fSTDOUT "Change: $intRFC"
	fSTDOUT "Log File: $LOGFILE"
	fSTDOUT "Script Dir: $strMyDir"
	fSTDOUT "******************** SYSTEM INFORMATION ********************************"
	fSTDOUT "System Name: $strCompName"
	fSTDOUT "OS Name: $strOSname"	
	fSTDOUT "OS Version: $intVer"	
	fSTDOUT "OS Architecture: $intArch"
	fSTDOUT "PowerShell Version: $intPSver"
	$strProdType = fProdType $intDR	
	fCheckIdb
	IF ($dAdminCheck){fCheckAdminRights}
	If(($Install -eq $True) -or ($Repair -eq $True)) { fCachePkg }
	$arrPrpcPkg = fProcPkg
	$GLOBAL:arrRC += $arrPrpcPkg
	fCleanup
	IF ($debug) {fSTDOUT "$tab Array of Success Codes: $GLOBAL:arrSuccessCodes"}
	fFindReturnCodes $GLOBAL:arrRC
}
#********************** END FUNCTIONS **********************
#-------------------------  Find System Information -------------------------
$strMyDir = fGetLocation $ScriptPath
$strOSname = fGetOSName
$intArch = fGetArch
$intVer = fGetWinVer
$intDR = fFndDomainRole
#-------------------------  Get Environment info from XML file -------------------------
$strDept = fGetXmlAtt "Framework/Environment/EnvInfo" "Dept"
$strAgency = fGetXmlAtt "Framework/Environment/EnvInfo" "Agency"
$strBranch = fGetXmlAtt "Framework/Environment/EnvInfo" "Branch"
$dAdminCheck = fGetXmlAtt "Framework/Environment/EnvInfo" "CheckAdminRights"
IF ($dAdminCheck -eq "True"){$dAdminCheck = $True} ELSE {$dAdminCheck = $False}
#-------------------------  Create Log and Cache Directories -------------------------
$strPkgCache = "C:\$strDept\$strAgency\$strBranch\Cache\C-Soft"
$strLog = "C:\$strDept\$strAgency\$strBranch\Logs\C-Soft"
If(-Not (Test-Path "$strLog")) { Md "$strLog" -Force > $Null }
If(-Not (Test-Path "$strPkgCache")) { Md "$strPkgCache" -Force > $Null }
$attribute = [io.fileattributes]::compressed
IF(!((Get-ItemProperty -Path $strLog).attributes -band $attribute)) { compact /c /s:$strLog  > $Null}
#-------------------------  Get Package info from XML file -------------------------
$intRFC =	fGetXmlAtt "Framework/Package/PKGInfo" "RFC"
$strLog = "$strLog\$intRFC"
$strDESC = fGetXmlAtt "Framework/Package/PKGInfo" "Description"
$intProductVer = fGetXmlAtt "Framework/Package/PKGInfo" "Version"
$dCachePKG = fGetXmlAtt "Framework/Package/PKGInfo" "Cache"
$drestartXML = fGetXmlAtt "Framework/Package/PKGInfo" "Reboot"
If($intRFC -eq $Null) {$LOGFILE = "C:\temp\PSFramework_InstallLog.txt"} Else {$LOGFILE = "$strLog\$intRFC.ps1.log"}  
#Set the default methods if no switches were passed
If(-Not($Uninstall) -And -Not($UninstallCurrent) -And -Not($Install) -And -Not($Repair) -And -Not($debug) -And -Not($restart)) { $Uninstall = $True ; $Install = $True }
If(-Not($Uninstall) -And -Not($UninstallCurrent) -And -Not($Install) -And -Not($Repair) -And -Not($debug) -And ($restart)) { $Uninstall = $True ; $Install = $True ; $restart = $True }
If(-Not($Uninstall) -And -Not($UninstallCurrent) -And -Not($Install) -And -Not($Repair) -And ($debug) -And ($restart)) { $Uninstall = $True ; $Install = $True ; $dDEBUG="TRUE" ; $restart = $True }
If(-Not($Uninstall) -And -Not($UninstallCurrent) -And -Not($Install) -And -Not($Repair) -And ($debug) -And -Not($restart)) { $Uninstall = $True ; $Install = $True ; $dDEBUG="TRUE" ; $restart = $False }
fMain