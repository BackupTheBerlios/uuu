@echo off
REM Setup for compiling with Borland C++ 5.0 in 32 bit mode.

if .%CHECKED%==.1 goto checked_build
SET LIB=%SCITECH_LIB%\LIB\RELEASE\RTT32\BC5;%RTOS32_PATH%\LIBBC;%BC5_PATH%\LIB;.
echo Release build enabled.
goto setvars

:checked_build
SET LIB=%SCITECH_LIB%\LIB\DEBUG\RTT32\BC5;%RTOS32_PATH%\LIBBC;%BC5_PATH%\LIB;.
echo Checked debug build enabled.
goto setvars

:setvars
SET C_INCLUDE=%RTOS32_PATH%\INCLUDE;%BC5_PATH%\INCLUDE
SET INCLUDE=INCLUDE;%SCITECH%\INCLUDE;%PRIVATE%\INCLUDE;%C_INCLUDE%
SET MAKESTARTUP=%SCITECH%\MAKEDEFS\BC32.MK
call clrvars.bat
SET USE_RTTARGET=1
SET USE_BC5=1
SET BC_LIBBASE=BC5
PATH %SCITECH_BIN%;%RTOS32_PATH%\BIN;%BC5_PATH%\BIN;%DEFPATH%%BC5_CD_PATH%

:createfiles
REM: Create Borland compile/link configuration scripts
echo -I%INCLUDE% > %BC5_PATH%\BIN\bcc32.cfg
echo -L%LIB% >> %BC5_PATH%\BIN\bcc32.cfg
echo -L%LIB% > %BC5_PATH%\BIN\tlink32.cfg

echo Borland C++ 5.0 RTTarget-32 compilation configuration set up.
