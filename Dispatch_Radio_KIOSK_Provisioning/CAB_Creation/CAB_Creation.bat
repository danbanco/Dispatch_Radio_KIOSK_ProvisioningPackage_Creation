@ECHO OFF
PROMPT PF$G
cls

set source="X:\Combined_PKGs"
set destination="X:\KioskProvisioningBatchWithCab"
set outputFile="Kiosk_Provisioning.cab"

PUSHD "%~dp0"

PowerShell -ExecutionPolicy Bypass -NoProfile -Command ".\CreateCAB.ps1" -source %source% -destination %destination% -outputFile %outputFile%
SET intRC=%ERRORLEVEL%

:CLOSE
POPD
PROMPT
EXIT %intRC%