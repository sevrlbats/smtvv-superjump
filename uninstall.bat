@echo off
setlocal EnableDelayedExpansion
title SMTVV Superjump - Uninstall

set "DLL=xinput1_3.dll"
set "EXE=SMT5V-Win64-Shipping.exe"

echo.
echo   ============================================================
echo    SMTVV Superjump - Uninstall
echo   ============================================================
echo.

call :locate
if not defined BINDIR (
    echo.
    echo   Cancelled -- no game folder provided.
    echo.
    pause
    exit /b 1
)

if not exist "!BINDIR!\%DLL%" (
    echo.
    echo   %DLL% was not present; nothing to remove.
    echo.
    pause
    exit /b 0
)

del /Q "!BINDIR!\%DLL%" >nul 2>nul
if exist "!BINDIR!\%DLL%" (
    echo  ERROR: could not remove %DLL% -- is the game running? Close it and retry.
) else (
    echo   Removed %DLL% from:
    echo     !BINDIR!
)
echo.
pause
exit /b 0

:: ==========================================================================
:: :locate -- sets BINDIR to the game's ...\Project\Binaries\Win64 folder.
:: Tries common Steam locations, then asks the user to paste the path.
:: Leaves BINDIR undefined only if the user cancels (blank input).
:: ==========================================================================
:locate
set "BINDIR="
for %%D in (C D E F G H) do (
    for %%P in (
        "%%D:\SteamLibrary\steamapps\common\SMT5V"
        "%%D:\Program Files (x86)\Steam\steamapps\common\SMT5V"
        "%%D:\Program Files\Steam\steamapps\common\SMT5V"
    ) do (
        if exist "%%~P\Project\Binaries\Win64\%EXE%" (
            set "BINDIR=%%~P\Project\Binaries\Win64"
            exit /b 0
        )
    )
)
for %%R in ("%~dp0.." "%~dp0..\.." "%~dp0..\..\..") do (
    if exist "%%~R\Project\Binaries\Win64\%EXE%" (
        set "BINDIR=%%~R\Project\Binaries\Win64"
        exit /b 0
    )
)

echo.
echo   Could not find SMT5V automatically.
echo   In Steam: right-click SMT5V ^> Manage ^> Browse local files,
echo   then copy that folder's path from the address bar and paste it here.
echo.

:locate_ask
set "USERPATH="
set /p "USERPATH=   SMT5V folder (or blank to cancel): "
if not defined USERPATH exit /b 1
set USERPATH=%USERPATH:"=%
if /i "!USERPATH:~-4!"==".exe" for %%I in ("!USERPATH!") do set "USERPATH=%%~dpI"
if "!USERPATH:~-1!"=="\" set "USERPATH=!USERPATH:~0,-1!"
if exist "!USERPATH!\%EXE%" (
    set "BINDIR=!USERPATH!"
    exit /b 0
)
if exist "!USERPATH!\Project\Binaries\Win64\%EXE%" (
    set "BINDIR=!USERPATH!\Project\Binaries\Win64"
    exit /b 0
)
echo.
echo   That folder doesn't contain %EXE%. Paste the SMT5V folder
echo   (or its Project\Binaries\Win64 folder), or press Enter to cancel.
echo.
goto :locate_ask
