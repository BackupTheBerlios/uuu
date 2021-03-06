@echo off
REM Setup for compiling with Open Watcom C/C++ 1.0 in 32 bit mode (DOS4GW)

if .%CHECKED%==.1 goto checked_build
SET LIB=%SCITECH_LIB%\LIB\RELEASE\DOS32\OW10;%OW10_PATH%\LIB386;%OW10_PATH%\LIB386\DOS;.
echo Release build enabled.
goto setvars

:checked_build
SET LIB=%SCITECH_LIB%\LIB\DEBUG\DOS32\OW10;%OW10_PATH%\LIB386;%OW10_PATH%\LIB386\DOS;.
echo Checked debug build enabled.
goto setvars

:setvars
SET EDPATH=%OW10_PATH%\EDDAT
SET INCLUDE=INCLUDE;%SCITECH%\INCLUDE;%PRIVATE%\INCLUDE;%OW10_PATH%\H;
SET WATCOM=%OW10_PATH%
SET MAKESTARTUP=%SCITECH%\MAKEDEFS\WC32.MK
call clrvars.bat
SET WC_LIBBASE=ow10
IF .%OS%==.Windows_NT goto Win32_path
IF NOT .%WINDIR%==. goto Win32_path
PATH %SCITECH_BIN%;%OW10_PATH%\BINW;%DJ_PATH%\BIN;%DEFPATH%%WC_CD_PATH%
goto path_set
:Win32_path
PATH %SCITECH_BIN%;%OW10_PATH%\BINNT;%OW10_PATH%\BINW;%DJ_PATH%\BIN;%DEFPATH%%WC_CD_PATH%
:path_set
echo Open Watcom C/C++ 1.0 32-bit DOS compilation environment set up (DOS4GW).
