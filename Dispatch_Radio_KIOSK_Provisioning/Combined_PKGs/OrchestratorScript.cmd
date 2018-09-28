@ECHO OFF
PROMPT PF$G
cls

PUSHD "%~dp0"
for /f "usebackq tokens=3" %%a in (`reg.exe query "HKLM\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" /v PowerShellVersion^|Findstr "REG_SZ"`) do SET intPSver=%%a
IF %intPSver% LSS 2  (@ECHO "* Error: Un-supported Powershell, minimum PS version 2" & Set intRC=197 & GOTO :CLOSE)
IF NOT EXIST "%cd%\Install.xml" (@ECHO "* Error: Install.xml does not exist" & Set intRC=22000 & GOTO :CLOSE)

PowerShell -ExecutionPolicy Bypass -NoProfile -Command ".\Install.ps1" -InstallFile '%cd%\Install.xml'
SET intRC=%ERRORLEVEL%

POPD
PROMPT

GOTO:EOF