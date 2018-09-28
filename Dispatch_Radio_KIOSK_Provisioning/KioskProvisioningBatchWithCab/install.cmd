@ECHO OFF
@ECHO OFF
PROMPT PF$G

PUSHD "%~dp0"

set source=%cd%\Kiosk_Provisioning.cab
set destination=.

Expand %source% -F:* %destination%

CALL OrchestratorScript.cmd

PROMPT