@ECHO OFF
PROMPT PF$G
::cls

FTYPE CSoftFile=C:\Program Files (x86)\Telex Communications\C-Soft\csoftruntime.exe %1

ASSOC .veg=CSoftFile

GOTO:EOF

PROMPT