@echo off
REM Setup for compiling with Watcom C/C++ 10.0a in 32 bit mode

if .%CHECKED%==.1 goto checked_build
SET LIB=%SCITECH_LIB%\LIB\RELEASE\WIN32\WC10A;%WC10A_PATH%\LIB386;%WC10A_PATH%\LIB386\NT;.
echo Release build enabled.
goto setvars

:checked_build
SET LIB=%SCITECH_LIB%\LIB\DEBUG\WIN32\WC10A;%WC10A_PATH%\LIB386;%WC10A_PATH%\LIB386\NT;.
echo Checked debug build enabled.
goto setvars

:setvars
SET EDPATH=%WC10A_PATH%\EDDAT
SET INCLUDE=INCLUDE;%SCITECH%\INCLUDE;%PRIVATE%\INCLUDE;%WC10A_PATH%\H;%WC10A_PATH%\H\NT;
SET WATCOM=%WC10A_PATH%
SET MAKESTARTUP=%SCITECH%\MAKEDEFS\WC32.MK
call clrvars.bat
SET USE_WIN32=1
SET WC_LIBBASE=WC10A
IF .%OS%==.Windows_NT goto Win32_path
IF NOT .%WINDIR%==. goto Win32_path
PATH %SCITECH_BIN%;%WC10A_PATH%\BINW;%DJ_PATH%\BIN;%DEFPATH%%WC_CD_PATH%
goto path_set
:Win32_path
PATH %SCITECH_BIN%;%WC10A_PATH%\BINNT;%WC10A_PATH%\BINW;%DJ_PATH%\BIN;%DEFPATH%%WC_CD_PATH%
:path_set

echo Watcom C/C++ 10.0a Win32 console compilation environment set up
