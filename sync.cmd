@echo off
REM Convert current directory to Cygwin path

set cygwin64=C:\Dev\cygwin64\
for /f "usebackq tokens=*" %%i in (`%cygwin64%\bin\cygpath.exe "%CD%"`) do set CYGDIR=%%i
echo running cygwin bash script...
%cygwin64%\bin\bash.exe  -lc "%CYGDIR%/sync-cygwin.sh"
