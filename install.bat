@echo off
setlocal EnableDelayedExpansion
title SMTVV Superjump

set "DLL=xinput1_3.dll"
set "EXE=SMT5V-Win64-Shipping.exe"
set "SRC=%~dp0%DLL%"

:menu
cls
echo.
echo   ==========================================================
echo      S M T V V   S U P E R J U M P
echo   ==========================================================
echo      Hold B (controller) or SPACE while airborne to fly
echo      upward and steer. Press F8 in-game to toggle.
echo   ==========================================================
echo.
echo       [1]   Install
echo       [2]   Uninstall
echo       [3]   Exit
echo.
set /p "CHOICE=   Choose (1/2/3): "

if "%CHOICE%"=="1" goto :install
if "%CHOICE%"=="2" goto :uninstall
if "%CHOICE%"=="3" exit /b 0
goto :menu

:: --------------------------------------------------------------------------
:install
if not exist "%SRC%" (
    echo.
    echo   ERROR: %DLL% is missing from this folder.
    goto :done
)
call :locate
if not defined BINDIR goto :nogame

echo.
echo   Found game:
echo     !BINDIR!
echo.
copy /Y "%SRC%" "!BINDIR!\%DLL%" >nul 2>nul
if errorlevel 1 (
    echo   ERROR: copy failed -- is the game running? Close it and retry.
    goto :done
)
echo   [OK] Superjump installed.
echo.
echo   Launch the game, jump, and hold B / SPACE to fly.
goto :done

:: --------------------------------------------------------------------------
:uninstall
call :locate
if not defined BINDIR goto :nogame

if not exist "!BINDIR!\%DLL%" (
    echo.
    echo   Superjump was not installed; nothing to remove.
    goto :done
)
del /Q "!BINDIR!\%DLL%" >nul 2>nul
if exist "!BINDIR!\%DLL%" (
    echo.
    echo   ERROR: could not remove %DLL% -- is the game running? Close it and retry.
) else (
    echo.
    echo   [OK] Superjump removed.
)
goto :done

:: --------------------------------------------------------------------------
:nogame
echo.
echo   Cancelled -- no game folder provided.
goto :done

:done
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
