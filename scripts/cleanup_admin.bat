@echo off
chcp 65001 >nul
setlocal enableextensions

REM ============================================================
REM  cleanup_admin.bat  --  TEMPLATE
REM
REM  Use this template for cleanup steps that require administrator
REM  rights, which a normal (non-elevated) session cannot do:
REM    * delete folders owned by BUILTIN\Administrators
REM    * delete HKLM / HKCR registry keys
REM    * stop / delete services and drivers
REM    * uninstall MSI packages
REM
REM  HOW TO USE
REM    1. Replace every __PLACEHOLDER__ below with the real names
REM       reported by the survey step. Keep one item per line.
REM    2. Save the file.
REM    3. Right-click it -> "Run as administrator".
REM
REM  WARNING: deleting the wrong path or registry key can break
REM  Windows or destroy data. Review every line before running.
REM  The final step empties the Recycle Bin - after that the
REM  deleted items are GONE.
REM ============================================================

echo ==========================================================
echo   Administrator cleanup  --  review the lists first
echo ==========================================================
echo.

net session >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Not running as administrator.
  echo         Close this window, right-click the file and
  echo         choose "Run as administrator".
  echo.
  pause
  exit /b 1
)
echo [OK] Administrator privileges confirmed.
echo.

REM ------------------------------------------------------------
REM [1/6] Kill processes that may lock the folders below.
REM       List process names WITHOUT .exe, one per line,
REM       separated by spaces. Replace __PLACEHOLDER__.
REM       Example:  for %%P in (MyApp MyAppHelper) do (
REM ------------------------------------------------------------
echo [1/6] Killing processes...
for %%P in (__PLACEHOLDER__) do (
  taskkill /F /IM %%P.exe >nul 2>&1
)
echo     done.
echo.

REM ------------------------------------------------------------
REM [2/6] Stop and delete services / drivers.
REM       List service names, one per line. Replace __PLACEHOLDER__.
REM       Example:  for %%S in (MyAppService MyAppDriver) do (
REM ------------------------------------------------------------
echo [2/6] Stopping and deleting services...
for %%S in (__PLACEHOLDER__) do (
  sc stop %%S >nul 2>&1
  sc delete %%S >nul 2>&1
)
echo     done.
echo.

REM ------------------------------------------------------------
REM [3/6] Take ownership and delete folders.
REM       Needed when the owner is BUILTIN\Administrators.
REM       Put each full path in double quotes. Replace the example.
REM       Example:  "C:\ProgramData\VendorName"
REM ------------------------------------------------------------
echo [3/6] Removing folders...
for %%D in (
  "__PLACEHOLDER_PATH_1__"
  "__PLACEHOLDER_PATH_2__"
) do (
  if exist %%D (
    echo     removing %%D
    takeown /F %%D /R /D Y >nul 2>&1
    icacls %%D /grant "*S-1-5-32-544":F /T /C >nul 2>&1
    icacls %%D /grant "%USERNAME%":F /T /C >nul 2>&1
    rmdir /S /Q %%D >nul 2>&1
    if exist %%D (echo       [!] still present) else (echo       [ok] removed)
  )
)
echo.

REM ------------------------------------------------------------
REM [4/6] Delete registry keys (HKCU / HKLM / HKCR).
REM       Back them up first if unsure:
REM         reg export "HKLM\SOFTWARE\Vendor" "D:\backup.reg" /y
REM       Replace the example keys.
REM ------------------------------------------------------------
echo [4/6] Deleting registry keys...
for %%K in (
  "__PLACEHOLDER_KEY_1__"
  "__PLACEHOLDER_KEY_2__"
) do (
  reg delete %%K /f >nul 2>&1
)
echo     done.
echo.

REM ------------------------------------------------------------
REM [5/6] Remove scheduled tasks and shortcuts.
REM       In this block "VendorName" is kept inside a command,
REM       so it is safe. Replace it with the real product name.
REM ------------------------------------------------------------
echo [5/6] Removing scheduled tasks and shortcuts...
schtasks /query /fo list >"%TEMP%\tasks_dump.txt" 2>nul
for /f "tokens=1,* delims=:" %%A in ('findstr /i "VendorName" "%TEMP%\tasks_dump.txt"') do (
  echo %%B | findstr /i "\\" >nul && schtasks /delete /tn "%%B" /f >nul 2>&1
)
del "%TEMP%\tasks_dump.txt" >nul 2>&1
del /F /Q "%USERPROFILE%\Desktop\*VendorName*.lnk" >nul 2>&1
del /F /Q "%PUBLIC%\Desktop\*VendorName*.lnk" >nul 2>&1
del /F /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\*VendorName*.lnk" >nul 2>&1
del /F /Q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\*VendorName*.lnk" >nul 2>&1
echo     done.
echo.

REM ------------------------------------------------------------
REM [6/6] Empty the Recycle Bin.
REM       REQUIRED to actually free space: deletion on Windows only
REM       moves items to the Recycle Bin. After this step they are
REM       unrecoverable, so make sure the backup is done.
REM ------------------------------------------------------------
echo [6/6] Emptying Recycle Bin...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo     done.
echo.

echo ==========================================================
echo   Finished.
echo   Re-run the survey to confirm the freed space.
echo ==========================================================
echo.
pause
