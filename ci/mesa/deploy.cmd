@echo off
@cd /d "%~dp0"
rem @set "ERRORLEVEL="
rem @CMD /C EXIT 0
rem @"%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system" >nul 2>&1
rem @if NOT "%ERRORLEVEL%"=="0" (
rem @powershell -Command Start-Process ""%0" "%1"" -Verb runAs 2>nul
rem @exit
rem )

:--------------------------------------
@echo Mesa3D system-wide deployment utility
@echo -------------------------------------

@set mesaloc=%~dp0
@IF "%mesaloc:~-1%"=="\" set mesaloc=%mesaloc:~0,-1%

@set mesainstalled=1
@IF NOT EXIST "%windir%\System32\mesadrv.dll" IF NOT EXIST "%windir%\System32\graw.dll" IF NOT EXIST "%windir%\System32\osmesa.dll" set mesainstalled=0

rem desktopgl
@if "%deploychoice%"=="2" if /I NOT %PROCESSOR_ARCHITECTURE%==AMD64 echo Invalid choice. swr driver is only supported on X64/AMD64 systems.
@if "%deploychoice%"=="2" if /I NOT %PROCESSOR_ARCHITECTURE%==AMD64 pause
@if "%deploychoice%"=="2" if /I NOT %PROCESSOR_ARCHITECTURE%==AMD64 GOTO deploy
@if "%deploychoice%"=="2" if /I %PROCESSOR_ARCHITECTURE%==AMD64 IF NOT EXIST "%mesaloc%\x64\swr*.dll" echo Invalid choice. swr driver is not included in MSYS2 Mingw-w64 build of Mesa3D.
@if "%deploychoice%"=="2" if /I %PROCESSOR_ARCHITECTURE%==AMD64 IF NOT EXIST "%mesaloc%\x64\swr*.dll" pause
@if "%deploychoice%"=="2" if /I %PROCESSOR_ARCHITECTURE%==AMD64 IF NOT EXIST "%mesaloc%\x64\swr*.dll" GOTO deploy
@IF /I %PROCESSOR_ARCHITECTURE%==X86 copy "%mesaloc%\x86\opengl32.dll" "%windir%\System32\mesadrv.dll"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x86\opengl32.dll" "%windir%\SysWOW64\mesadrv.dll"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x64\opengl32.dll" "%windir%\System32\mesadrv.dll"
@IF /I %PROCESSOR_ARCHITECTURE%==X86 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\System32"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\SysWOW64"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x64\libglapi.dll" copy "%mesaloc%\x64\libglapi.dll" "%windir%\System32"
@if "%deploychoice%"=="2" IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x64\swr*.dll" "%windir%\System32"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "DLL" /t REG_SZ /d "mesadrv.dll" /f
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "DriverVersion" /t REG_DWORD /d "1" /f
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "Flags" /t REG_DWORD /d "1" /f
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "Version" /t REG_DWORD /d "2" /f
@REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "DLL" /t REG_SZ /d "mesadrv.dll" /f
@REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "DriverVersion" /t REG_DWORD /d "1" /f
@REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "Flags" /t REG_DWORD /d "1" /f
@REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL" /v "Version" /t REG_DWORD /d "2" /f
@echo.
@echo Desktop OpenGL drivers deploy complete.


rem osmesa 
@if "%deploychoice%"=="3" IF /I %PROCESSOR_ARCHITECTURE%==X86 IF EXIST "%mesaloc%\x86\osmesa.dll" copy "%mesaloc%\x86\osmesa.dll" "%windir%\System32"
@if "%deploychoice%"=="3" IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x86\osmesa.dll" copy "%mesaloc%\x86\osmesa.dll" "%windir%\SysWOW64"
@if "%deploychoice%"=="3" IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x64\osmesa.dll" copy "%mesaloc%\x64\osmesa.dll" "%windir%\System32"
@if "%deploychoice%"=="4" IF EXIST %mesaloc%\x86\osmesa.dll IF EXIST %mesaloc%\x64\osmesa.dll echo Mesa3D was built with Meson so osmesa swrast is not available.
@if "%deploychoice%"=="4" IF EXIST %mesaloc%\x86\osmesa.dll IF EXIST %mesaloc%\x64\osmesa.dll pause
@if "%deploychoice%"=="4" IF EXIST %mesaloc%\x86\osmesa.dll IF EXIST %mesaloc%\x64\osmesa.dll GOTO deploy
@IF /I %PROCESSOR_ARCHITECTURE%==X86 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\System32"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\SysWOW64"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x64\libglapi.dll" copy "%mesaloc%\x64\libglapi.dll" "%windir%\System32"
@if "%deploychoice%"=="3" set osmesatype=gallium
@if "%deploychoice%"=="4" set osmesatype=swrast
@IF /I %PROCESSOR_ARCHITECTURE%==X86 copy "%mesaloc%\x86\osmesa-%osmesatype%\osmesa.dll" "%windir%\System32"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x86\osmesa-%osmesatype%\osmesa.dll" "%windir%\SysWOW64"
@IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x64\osmesa-%osmesatype%\osmesa.dll" "%windir%\System32"
@echo.
@echo Off-screen render driver deploy complete.
}

rem graw 
rem @IF /I %PROCESSOR_ARCHITECTURE%==X86 copy "%mesaloc%\x86\graw.dll" "%windir%\System32"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x86\graw.dll" "%windir%\SysWOW64"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 copy "%mesaloc%\x64\graw.dll" "%windir%\System32"
rem @IF /I %PROCESSOR_ARCHITECTURE%==X86 IF EXIST "%mesaloc%\x86\graw_null.dll" copy "%mesaloc%\x86\graw_null.dll" "%windir%\System32"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x86\graw_null.dll" copy "%mesaloc%\x86\graw_null.dll" "%windir%\SysWOW64"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x64\graw_null.dll" copy "%mesaloc%\x64\graw_null.dll" "%windir%\System32"
rem @IF /I %PROCESSOR_ARCHITECTURE%==X86 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\System32"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x86\libglapi.dll" copy "%mesaloc%\x86\libglapi.dll" "%windir%\SysWOW64"
rem @IF /I %PROCESSOR_ARCHITECTURE%==AMD64 IF EXIST "%mesaloc%\x64\libglapi.dll" copy "%mesaloc%\x64\libglapi.dll" "%windir%\System32"
rem @echo.
rem @echo graw framework deploy complete.

echo All done
exit
