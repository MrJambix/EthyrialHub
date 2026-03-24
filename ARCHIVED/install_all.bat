@echo off
REM ================================================================
REM  EthyTool — Full Installer
REM  Does EVERYTHING in one shot. Right-click -> Run as Administrator.
REM ================================================================

setlocal enabledelayedexpansion
title EthyTool — Full Installer
color 0A

:: ── Self-elevate to Admin ──────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "EXE=%SCRIPT_DIR%\EthyTool.exe"
set "DLL=%SCRIPT_DIR%\EthyTool.dll"
set "REQ=%SCRIPT_DIR%\requirements.txt"

echo.
echo  ================================================================
echo    EthyTool  -  Full Installer
echo  ================================================================
echo.
echo    This will:
echo      [1] Install Visual C++ Redistributable (for OpenCV/numpy)
echo      [2] Add Windows Defender exclusion
echo      [3] Add Firewall rules (inbound + outbound)
echo      [4] Install Python + all pip packages
echo      [5] Run quick diagnostics
echo.
echo  ================================================================
echo.
pause

:: ================================================================
::  STEP 1 — Visual C++ Redistributable
:: ================================================================
echo.
echo  [1/5] Visual C++ Redistributable (x64)
echo  -----------------------------------------------
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Installed >nul 2>&1
if not errorlevel 1 (
    echo    Already installed. Skipping.
) else (
    echo    Downloading from Microsoft...
    powershell -NoProfile -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile '%TEMP%\vc_redist.x64.exe' -UseBasicParsing }"
    if errorlevel 1 (
        echo    [ERROR] Download failed. Manual: https://aka.ms/vs/17/release/vc_redist.x64.exe
    ) else (
        echo    Installing silently...
        "%TEMP%\vc_redist.x64.exe" /install /quiet /norestart
        if errorlevel 1 (
            echo    [WARN] Install may have failed. Try manual install.
        ) else (
            echo    Done.
        )
    )
)

:: ================================================================
::  STEP 2 — Windows Defender Exclusion
:: ================================================================
echo.
echo  [2/5] Windows Defender Exclusion
echo  -----------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path = '%SCRIPT_DIR%';" ^
  "try {" ^
  "  $p = Get-MpPreference -ErrorAction Stop;" ^
  "  $hit = $p.ExclusionPath | Where-Object { $_ -eq $path };" ^
  "  if ($hit) { Write-Host '    Already excluded.' }" ^
  "  else { Add-MpPreference -ExclusionPath $path -ErrorAction Stop; Write-Host '    Exclusion added:' $path }" ^
  "} catch { Write-Host '    [WARN] Could not set exclusion. Add manually in Windows Security.' }"

:: ================================================================
::  STEP 3 — Firewall Rules (Inline — no external PS1)
:: ================================================================
echo.
echo  [3/5] Firewall Rules
echo  -----------------------------------------------
if exist "!EXE!" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$exe = '!EXE!';" ^
      "$inR = Get-NetFirewallRule -DisplayName 'EthyTool Inbound' -ErrorAction SilentlyContinue;" ^
      "if ($inR) { Write-Host '    Inbound rule exists.' }" ^
      "else { New-NetFirewallRule -DisplayName 'EthyTool Inbound' -Direction Inbound -Program $exe -Action Allow -Profile Any | Out-Null; Write-Host '    Inbound rule added.' };" ^
      "$outR = Get-NetFirewallRule -DisplayName 'EthyTool Outbound' -ErrorAction SilentlyContinue;" ^
      "if ($outR) { Write-Host '    Outbound rule exists.' }" ^
      "else { New-NetFirewallRule -DisplayName 'EthyTool Outbound' -Direction Outbound -Program $exe -Action Allow -Profile Any | Out-Null; Write-Host '    Outbound rule added.' }"
) else (
    echo    EthyTool.exe not found yet. Firewall rules skipped.
    echo    Re-run after building or placing EthyTool.exe in this folder.
)

:: Also add firewall rule for the game exe if found
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$game = Get-Process -Name '*ethyrial*' -ErrorAction SilentlyContinue | Select-Object -First 1;" ^
  "if ($game) {" ^
  "  $gamePath = $game.Path;" ^
  "  $r = Get-NetFirewallRule -DisplayName 'Ethyrial Game' -ErrorAction SilentlyContinue;" ^
  "  if (-not $r) { New-NetFirewallRule -DisplayName 'Ethyrial Game' -Direction Inbound -Program $gamePath -Action Allow -Profile Any | Out-Null; Write-Host '    Game firewall rule added.' }" ^
  "  else { Write-Host '    Game firewall rule exists.' }" ^
  "} else { Write-Host '    Game not running — game firewall rule skipped.' }"

:: ================================================================
::  STEP 4 — Python + All Pip Packages
:: ================================================================
echo.
echo  [4/5] Python Dependencies
echo  -----------------------------------------------

where python >nul 2>&1
if !errorlevel! neq 0 (
    echo    Python not found on PATH.
    echo    Attempting to install via winget...
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements >nul 2>&1
    if !errorlevel! equ 0 (
        echo    Python installed. You may need to restart this script.
        echo    Refreshing PATH...
        set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts"
    ) else (
        echo    [WARN] Could not auto-install Python.
        echo    Download manually: https://www.python.org/downloads/
        echo    Skipping pip install.
        goto :skip_pip
    )
)

echo    Python found. Upgrading pip...
python -m pip install --upgrade pip >nul 2>&1

if exist "!REQ!" (
    echo    Installing all packages from requirements.txt...
    python -m pip install -r "!REQ!" --upgrade
    if !errorlevel! equ 0 (
        echo    All packages installed successfully.
    ) else (
        echo    [WARN] Some packages had errors. Check output above.
    )
) else (
    echo    [WARN] requirements.txt not found at: !REQ!
)

:skip_pip

:: ================================================================
::  STEP 5 — Quick Diagnostics
:: ================================================================
echo.
echo  [5/5] Quick Diagnostics
echo  -----------------------------------------------

echo    Files:
if exist "!EXE!" (echo      EthyTool.exe .... OK) else (echo      EthyTool.exe .... MISSING)
if exist "!DLL!" (echo      EthyTool.dll .... OK) else (echo      EthyTool.dll .... MISSING)
if exist "!REQ!" (echo      requirements.txt  OK) else (echo      requirements.txt  MISSING)

echo.
echo    Game process:
powershell -NoProfile -Command ^
  "$p = Get-Process -Name '*ethyrial*' -ErrorAction SilentlyContinue;" ^
  "if ($p) { $p | ForEach-Object { Write-Host '      PID' $_.Id '-' $_.ProcessName } }" ^
  "else { Write-Host '      Not running' }"

echo.
echo    Named pipes:
powershell -NoProfile -Command ^
  "$pipes = Get-ChildItem '\\.\pipe\' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'EthyTool*' };" ^
  "if ($pipes) { $pipes | ForEach-Object { Write-Host '      ' $_.Name } }" ^
  "else { Write-Host '      None found (inject DLL first)' }"

:: ================================================================
::  DONE
:: ================================================================
echo.
echo  ================================================================
echo    Install Complete
echo  ================================================================
echo.
echo    Next steps:
echo      1. Launch Ethyrial (the game)
echo      2. Run EthyTool.exe as Administrator
echo      3. Click Inject in the launcher
echo.
echo    Troubleshooting:
echo      - Pipe not found? Make sure DLL is injected
echo      - AV blocking? Check Defender exclusion above
echo      - Run this script again after game is running for
echo        full diagnostics
echo.
echo  ================================================================
echo.
pause
