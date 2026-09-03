@echo off
chcp 65001 >nul
setlocal

rem ============================================================
rem  chatbox-custom - build NSIS Setup installer
rem  Output: release\build\Chatbox-<version>-Setup.exe (+ .blockmap)
rem          version comes from release\app\package.json
rem  Usage:
rem    build-setup.bat               build + electron-builder NSIS
rem    build-setup.bat --skip-build  skip pnpm build, package existing output
rem    build-setup.bat <extra args>  passed through to electron-builder
rem    (--skip-build may be combined; all other args go to electron-builder)
rem ============================================================

rem Project root: script lives at <repo>\CUSTOMIZATIONS\scripts\
set "ROOT=%~dp0..\.."
pushd "%ROOT%"

set "SKIP_BUILD="
set "EXTRA_ARGS="
if /I "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
)
:ParseArgs
if "%~1"=="" goto :ArgsDone
set "EXTRA_ARGS=%EXTRA_ARGS% %~1"
shift
goto :ParseArgs
:ArgsDone

rem Read version (release/app/package.json version drives artifact names)
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Get-Content -Raw 'release\app\package.json' | ConvertFrom-Json).version"`) do set "APP_VERSION=%%V"
if "%APP_VERSION%"=="" (
  echo [ERROR] Could not read version from release\app\package.json.
  goto :Fail
)

echo ============================================================
echo  Build Setup  ^| project : %CD%
echo                version : %APP_VERSION%
echo                artifact: Chatbox-%APP_VERSION%-Setup.exe
echo                target  : NSIS x64 + arm64
echo ============================================================

where pnpm >nul 2>&1
if errorlevel 1 goto :NoPnpm

rem 7za shim check (CUSTOM-20260902-003): on machines without symlink
rem permission, extracting the winCodeSign cache aborts packaging.
rem Presence of 7za-real.exe means the shim is installed.
if not exist "node_modules\7zip-bin\win\x64\7za-real.exe" (
  if exist "node_modules\7zip-bin\win\x64\7za.exe" (
    if exist "CUSTOMIZATIONS\scripts\7za-shim.exe" (
      echo [INFO] installing 7za shim...
      move /Y "node_modules\7zip-bin\win\x64\7za.exe" "node_modules\7zip-bin\win\x64\7za-real.exe" >nul
      copy /Y "CUSTOMIZATIONS\scripts\7za-shim.exe" "node_modules\7zip-bin\win\x64\7za.exe" >nul
    ) else (
      echo [WARN] 7za shim missing; if packaging fails during winCodeSign extraction, install it per registry.md CUSTOM-20260902-003.
    )
  ) else (
    echo [ERROR] node_modules\7zip-bin\win\x64\7za.exe not found. Run pnpm install first.
    goto :Fail
  )
) else (
  echo [INFO] 7za shim already installed.
)

rem Kill resident instances so output files are not locked
echo Stopping any running Chatbox instances...
taskkill /IM Chatbox.exe /F >nul 2>&1

if not "%SKIP_BUILD%"=="1" (
  echo.
  echo [1/2] Building main + preload + renderer...
  call pnpm run build
  if errorlevel 1 goto :BuildFailed
) else (
  echo.
  echo [1/2] Skipping build ^(--skip-build^).
)

echo.
echo [2/2] electron-builder NSIS ...
rem UPDATE_CHANNEL: electron-builder.yml publish.channel uses ${env.UPDATE_CHANNEL};
rem pin it to alpha so --publish never does not abort on the missing env var.
call npx cross-env UPDATE_CHANNEL=alpha electron-builder build --publish never --win %EXTRA_ARGS%
if errorlevel 1 goto :PackageFailed

echo.
echo ============================================================
echo  Output:
echo ============================================================
if exist "release\build\Chatbox-%APP_VERSION%-Setup.exe" (
  echo   setup : %CD%\release\build\Chatbox-%APP_VERSION%-Setup.exe
  for %%F in ("release\build\Chatbox-%APP_VERSION%-Setup.exe") do echo   size  : %%~zF bytes
) else (
  echo   [WARN] release\build\Chatbox-%APP_VERSION%-Setup.exe not found
)
if exist "release\build\Chatbox-%APP_VERSION%-Setup.exe.blockmap" (
  echo   blockmap : Chatbox-%APP_VERSION%-Setup.exe.blockmap
)

echo.
echo [SUCCESS] Setup build finished.
echo   Use the chatbox-release skill for a full GitHub release.
popd
exit /b 0

:NoPnpm
echo [ERROR] pnpm CLI not found. Install Node.js 20-22 and pnpm first.
popd
exit /b 1

:BuildFailed
echo.
echo [FAILED] pnpm run build failed.
popd
exit /b 1

:PackageFailed
echo.
echo [FAILED] electron-builder packaging failed.
popd
exit /b 1
