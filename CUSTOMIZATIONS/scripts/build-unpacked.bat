@echo off
chcp 65001 >nul
setlocal

rem ============================================================
rem  chatbox-custom - build unpacked (portable) package
rem  Output: release\build\win-unpacked\ (win-x64)
rem          release\build\win-arm64-unpacked\ (if configured)
rem  Usage:
rem    build-unpacked.bat            build + electron-builder --dir
rem    build-unpacked.bat --skip-build   skip pnpm build, package existing output
rem    build-unpacked.bat <extra args>   passed through to electron-builder
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

echo ============================================================
echo  Build unpacked ^| project : %CD%
echo                     output : release\build\win-unpacked\
echo                     mode   : electron-builder --dir
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
echo [2/2] electron-builder --dir ...
rem UPDATE_CHANNEL: electron-builder.yml publish.channel uses ${env.UPDATE_CHANNEL};
rem pin it to alpha so --publish never does not abort on the missing env var.
call npx cross-env UPDATE_CHANNEL=alpha electron-builder build --publish never --dir --win %EXTRA_ARGS%
if errorlevel 1 goto :PackageFailed

echo.
echo ============================================================
echo  Output:
echo ============================================================
if exist "release\build\win-unpacked\Chatbox.exe" (
  echo   win-unpacked : %CD%\release\build\win-unpacked\Chatbox.exe
) else (
  echo   [WARN] release\build\win-unpacked\Chatbox.exe not found
)
if exist "release\build\win-arm64-unpacked" (
  echo   win-arm64-unpacked : %CD%\release\build\win-arm64-unpacked\
)

echo.
echo [SUCCESS] unpacked build finished.
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
