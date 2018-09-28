On Error Resume Next 
' Option Explicit  
' AUTHOR: Mick Grove 
' http://micksmix.wordpress.com 
' 
' Last Updated: 5-4-2013 
' 
' Tested and works on Windows XP and Windows 7 (x64) 
' Should work fine on Windows 2000 and newer OS' 
' 
' Script name: RegUpdateAllHKCU.vbs 
' Run with cscript to suppress dialogs:   cscript.exe RegUpdateAllHKCU.vbs 
   
Dim WshShell, RegRoot 
Set WshShell = CreateObject("WScript.shell") 
Const HKEY_CLASSES_ROOT 	= &H80000000
Const HKEY_CURRENT_USER 	= &H80000001
Const HKEY_LOCAL_MACHINE 	= &H80000002
Const HKEY_USERS 		    = &H80000003
Const HKEY_CURRENT_CONFIG 	= &H80000005

   
'============================================== 
' SCRIPT BEGINS HERE 
'============================================== 
' 
'This is where our HKCU is temporarily loaded, and where we need to write to it 
RegRoot = "HKLM\TEMPHIVE" ' You don't really need to change this, but you can if you want 
   
Call Load_Registry_For_Each_User()      'Loads each user's "HKCU" registry hive 
   
WScript.Echo vbCrLf & "Processing complete!" 
WScript.Quit(0) 
'                                                                   | 
'                                                                   | 
'==================================================================== 

Sub KeysToSet(sRegistryRootToUse) 
    '============================================== 
    ' Change variables here, or add additional keys 
    '============================================== 
    ' 
    Dim strRegPathParent01 
    Dim strRegPathParent02 
'	Dim strRegPathParent03
	'  Software\Microsoft\Windows\CurrentVersion\RunOnce  
    strRegPathParent01 = "Software\Microsoft\Windows\CurrentVersion\RunOnce" 
    strRegPathParent02 = "Software\Microsoft\Windows\CurrentVersion\Run" 
'  	strRegPathParent03 = "Software\_Test\MyTestBinarySubkey"
'	"C:\Program Files\Microsoft Office 15\office15\lync.exe" /fromrunkey   
'    WshShell.RegWrite sRegistryRootToUse & "\" & strRegPathParent01 & "\DisablePasswordCaching", "00000001", "REG_DWORD"  
    WshShell.RegDelete sRegistryRootToUse & "\" & strRegPathParent01 & "\Lync"
	
	'===
	'REG_BINARY values are special
	'===
	'
	' 1st step is to create subkey path 
'	WshShell.RegWrite sRegistryRootToUse & "\" & strRegPathParent03 & "\", ""
'	SetBinaryRegKeys sRegistryRootToUse, strRegPathParent03, "My Test Binary Value","hex:23,00,41,00,43,00,42,00,6c,00"
    ' 
    ' You can add additional registry keys here if you would like 
    ' 
End Sub
'
'
'
'
'
' NO CHANGES NECESSARY BELOW THIS LINE
'
'
'
'
'
'
'
'
Function SetBinaryRegKeys(sRegistryRootToUse, strRegPathParent, sKeyName, sHexString)

	Dim sBinRegRoot
	Dim sBinRegPartialPath
	Dim arrBinRegRoot

	arrBinRegRoot = GetRegRootToUseForBinaryValues(sRegistryRootToUse)
	sBinRegRoot = arrBinRegRoot(0)
	sBinRegPartialPath = arrBinRegRoot(1)
	
	If Len(sBinRegPartialPath) > 0 Then
		sBinRegPartialPath = sBinRegPartialPath & "\"
	End If
	
	WriteBinaryValue sBinRegRoot, sBinRegPartialPath & strRegPathParent, sKeyName, sHexString
End Function

Function WriteBinaryValue(RegHive, strKeyPath, strValueName, strHexValues)
	Dim objRegistry
	Dim arrHexValues, arrDecValues

	Set objRegistry = GetObject("Winmgmts:root\default:StdRegProv")
	
	'Example:   strHexData = "hex:23,00,41,00,43,00,42,00,6c,00"
	arrHexValues = Split(Replace(strHexValues, "hex:", ""), ",")
	arrDecValues = DecimalNumbers(arrHexValues)

	Dim iResult
	iResult = objRegistry.SetBinaryValue (RegHive, _
	   strKeyPath, strValueName, arrDecValues)
	   
	If (iResult = 0) Then
		'Wscript.Echo "Binary value added successfully"
	Else
		Wscript.Echo "*** Error adding binary value at " & strKeyPath & "\" & strValueName
	End If  		
End Function

Function GetRegRootToUseForBinaryValues(sRegRoot)
	Dim sNewRoot
	Dim sPartialPath
	sRegRoot = UCase(sRegRoot)
	
	
'HKEY_CURRENT_USER
'	
	If Left(sRegRoot,Len("HKCU\")) = "HKCU\" Then
		sNewRoot = HKEY_CURRENT_USER	
		sPartialPath = Replace(sRegRoot,"HKCU\",1, Len("HKCU\") + 1)
	ElseIf Left(sRegRoot,Len("HKCU")) = "HKCU" Then
		sNewRoot = HKEY_CURRENT_USER	
		sPartialPath = Replace(sRegRoot,"HKCU",1, Len("HKCU") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_CURRENT_USER\")) = "HKEY_CURRENT_USER\" Then
		sNewRoot = HKEY_CURRENT_USER	
		sPartialPath = Replace(sRegRoot,"HKEY_CURRENT_USER\",1, Len("HKEY_CURRENT_USER\") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_CURRENT_USER")) = "HKEY_CURRENT_USER" Then
		sNewRoot = HKEY_CURRENT_USER	
		sPartialPath = Replace(sRegRoot,"HKEY_CURRENT_USER",1, Len("HKEY_CURRENT_USER") + 1)
'HKEY_LOCAL_MACHINE
'
	ElseIf Left(sRegRoot,Len("HKLM\")) = "HKLM\" Then
		sNewRoot = HKEY_LOCAL_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKLM\",1, Len("HKLM\") + 1)
	ElseIf Left(sRegRoot,Len("HKLM")) = "HKLM" Then
		sNewRoot = HKEY_LOCAL_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKLM",1, Len("HKLM") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_LOCAL_MACHINE\")) = "HKEY_LOCAL_MACHINE\" Then
		sNewRoot = HKEY_LOCAL_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKEY_LOCAL_MACHINE\",1, Len("HKEY_LOCAL_MACHINE\") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_LOCAL_MACHINE")) = "HKEY_LOCAL_MACHINE" Then
		sNewRoot = HKEY_LOCAL_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKEY_LOCAL_MACHINE",1, Len("HKEY_LOCAL_MACHINE") + 1)
'HKEY_USERS
'
	ElseIf Left(sRegRoot,Len("HKEY_USERS\")) = "HKEY_USERS\" Then
		sNewRoot = HKEY_USERS	
		sPartialPath = Replace(sRegRoot,"HKEY_USERS\",1, Len("HKEY_USERS\") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_USERS")) = "HKEY_USERS" Then
		sNewRoot = HKEY_CURRENT_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKEY_USERS",1, Len("HKEY_USERS") + 1)
'HKEY_CLASSES_ROOT
'
	ElseIf Left(sRegRoot,Len("HKEY_CLASSES_ROOT\")) = "HKEY_CLASSES_ROOT\" Then
		sNewRoot = HKEY_CLASSES_ROOT	
		sPartialPath = Replace(sRegRoot,"HKEY_CLASSES_ROOT\",1, Len("HKEY_CLASSES_ROOT\") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_CLASSES_ROOT")) = "HKEY_CLASSES_ROOT" Then
		sNewRoot = HKEY_CURRENT_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKEY_CLASSES_ROOT",1, Len("HKEY_CLASSES_ROOT") + 1)
'HKEY_CURRENT_CONFIG
'
	ElseIf Left(sRegRoot,Len("HKEY_CURRENT_CONFIG\")) = "HKEY_CURRENT_CONFIG\" Then
		sNewRoot = HKEY_CURRENT_CONFIG	
		sPartialPath = Replace(sRegRoot,"HKEY_CURRENT_CONFIG\",1, Len("HKEY_CURRENT_CONFIG\") + 1)
	ElseIf Left(sRegRoot,Len("HKEY_CURRENT_CONFIG")) = "HKEY_CURRENT_CONFIG" Then
		sNewRoot = HKEY_CURRENT_MACHINE	
		sPartialPath = Replace(sRegRoot,"HKEY_CURRENT_CONFIG",1, Len("HKEY_CURRENT_CONFIG") + 1)
	End If

	GetRegRootToUseForBinaryValues = Array(sNewRoot,sPartialPath)
End Function 

Function DecimalNumbers(arrHex)
	' from: http://www.petri.co.il/forums/showthread.php?t=46158
	Dim i, strDecValues
	For i = 0 to Ubound(arrHex)
		If isEmpty(strDecValues) Then
			strDecValues = CLng("&H" & arrHex(i))
		Else
			strDecValues = strDecValues & "," & CLng("&H" & arrHex(i))
		End If
	Next
	
	DecimalNumbers = split(strDecValues, ",")
End Function

Function GetDefaultUserPath
	Dim objRegistry
	Dim strKeyPath
	Dim strDefaultUser
	Dim strDefaultPath
	Dim strResult

	Set objRegistry = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
	strKeyPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 

	objRegistry.GetExpandedStringValue HKEY_LOCAL_MACHINE,strKeyPath,"Default",strDefaultUser
	objRegistry.GetExpandedStringValue HKEY_LOCAL_MACHINE,strKeyPath,"ProfilesDirectory",strDefaultPath

	strResult =  strDefaultUser
	GetDefaultUserPath = strResult
End Function

Function RetrieveUsernameFromPath(sTheProfilePath) 
    Dim lstPath 
    Dim sTmp 
    Dim sUsername 
   
    lstPath = Split(sTheProfilePath,"\") 
    For each sTmp in lstPath 
        sUsername = sTmp 
        'last split is our username 
    Next 
   
    RetrieveUsernameFromPath = sUsername 
End Function 

Sub LoadProfileHive(sProfilePath, sCurrentUser)
	Dim intResultLoad, intResultUnload, sUserSID

	'Load user's HKCU into temp area under HKLM 
	intResultLoad = WshShell.Run("reg.exe load " & RegRoot & " " & chr(34) & sProfilePath & "\NTUSER.DAT" & chr(34), 0, True) 

	If intResultLoad <> 0 Then 
		' This profile appears to already be loaded...lets update it under the HKEY_USERS hive 
		Dim objRegistry2, objSubKey2 
		Dim strKeyPath2, strValueName2, strValue2 
		Dim strSubPath2, arrSubKeys2 

		Set objRegistry2 = GetObject("winmgmts:\\.\root\default:StdRegProv") 
		strKeyPath2 = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 
		objRegistry2.EnumKey HKEY_LOCAL_MACHINE, strKeyPath2, arrSubkeys2 
		sUserSID = "" 

		For Each objSubkey2 In arrSubkeys2 
			strValueName2 = "ProfileImagePath" 
			strSubPath2 = strKeyPath2 & "\" & objSubkey2 
			objRegistry2.GetExpandedStringValue HKEY_LOCAL_MACHINE,strSubPath2,strValueName2,strValue2 
			If Right(UCase(strValue2),Len(sCurrentUser)+1) = "\" & UCase(sCurrentUser) Then 
				'this is the one we want 
				sUserSID = objSubkey2 
			End If 
		Next 

		If Len(sUserSID) > 1 Then 
			WScript.Echo "  Updating another logged-on user: " & sCurrentUser & vbcrlf 
			Call KeysToSet("HKEY_USERS\" & sUserSID) 
		Else 
			WScript.Echo("  *** An error occurred while loading HKCU for this user: " & sCurrentUser) 
		End If 
	Else 
		WScript.Echo("  HKCU loaded for this user: " & sCurrentUser) 
	End If 

	'' 
	If sUserSID = "" then 'check to see if we just updated this user b/c they are already logged on 
		Call KeysToSet(RegRoot) ' update registry settings for this selected user 
	End If 
	'' 

	If sUserSID = "" then 'check to see if we just updated this user b/c they are already logged on 
		intResultUnload = WshShell.Run("reg.exe unload " & RegRoot,0, True) 'Unload HKCU from HKLM 
		If intResultUnload <> 0 Then 
			WScript.Echo("  *** An error occurred while unloading HKCU for this user: " & sCurrentUser & vbCrLf) 
		Else 
			WScript.Echo("  HKCU UN-loaded for this user: " & sCurrentUser & vbCrLf) 
		End If 
	End If 
End Sub

Sub Load_Registry_For_Each_User() 
       
    Dim sUserRunningScript, sComputerName 
    Dim objRegistry, objSubkey 
    Dim strKeyPath, strValueName, strValue, strSubPath, arrSubKeys 
    Dim sCurrentUser, sProfilePath, sNewUserProfile
   
    sUserRunningScript = WshShell.ExpandEnvironmentStrings("%USERNAME%") 'Holds name of current logged on user running this script 
    sComputerName = UCase(WshShell.ExpandEnvironmentStrings("%COMPUTERNAME%")) 
   
    If sUserRunningScript = "%USERNAME%" or sUserRunningScript = sComputerName & "$"  Then 
        ' This script might be run by the SYSTEM account or a service account 
        Dim sTheProfilePath 
        sTheProfilePath = WshShell.ExpandEnvironmentStrings("%USERPROFILE%") 'Holds name of current logged on user running this script 
  
        sUserRunningScript = RetrieveUsernameFromPath(sTheProfilePath) 
    End If 
      
    WScript.Echo "Updating the logged-on user: " & sUserRunningScript & vbcrlf 
    '' 
    Call KeysToSet("HKCU") 'Update registry settings for the user running the script 
    '' 
    WScript.Echo "Updating the DEFAULT user profile which affects newly created profiles." & vbcrlf 
	sNewUserProfile = GetDefaultUserPath
	WScript.Echo " This is the new user profile path: " & sNewUserProfile
	Call LoadProfileHive(sNewUserProfile, "Default User Profile")
    '' 
	
    Set objRegistry = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    strKeyPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 
    objRegistry.EnumKey HKEY_LOCAL_MACHINE, strKeyPath, arrSubkeys 
   
    For Each objSubkey In arrSubkeys 
        strValueName = "ProfileImagePath" 
        strSubPath = strKeyPath & "\" & objSubkey 
        objRegistry.GetExpandedStringValue HKEY_LOCAL_MACHINE,strSubPath,strValueName,strValue 
        sProfilePath = strValue 
        sCurrentUser = RetrieveUsernameFromPath(strValue) 
   
        If ((UCase(sCurrentUser) <> "ALL USERS") and _ 
            (UCase(sCurrentUser) <> UCase(sUserRunningScript)) and _ 
            (UCase(sCurrentUser) <> "LOCALSERVICE") and _ 
            (UCase(sCurrentUser) <> "SYSTEMPROFILE") and _ 
            (UCase(sCurrentUser) <> "NETWORKSERVICE")) then 
   
            WScript.Echo "Preparing to update the user: " & sCurrentUser 
			Call LoadProfileHive(sProfilePath, sCurrentUser)
        End If 
    Next 
End Sub
