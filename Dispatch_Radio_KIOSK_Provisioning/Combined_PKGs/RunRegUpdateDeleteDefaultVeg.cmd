@ECHO OFF
PROMPT PF$G
PUSHD "%~dp0"

cscript %cd%\RegUpdateDeleteDefault.vbs

POPD

GOTO:EOF

PROMPT