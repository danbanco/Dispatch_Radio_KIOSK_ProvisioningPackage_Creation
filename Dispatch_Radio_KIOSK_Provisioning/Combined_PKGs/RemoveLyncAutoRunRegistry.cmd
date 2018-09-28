@ECHO OFF
PROMPT PF$G

cscript .\RegUpdateAllHKCU64.vbs
cscript .\RemoveLyncAutoRunRegistry.vbs

GOTO:EOF

PROMPT