@echo off
setlocal
cd /d "%~dp0"
set "PUB_CACHE=%CD%\.pub-cache"
echo Preparando dependencias do BluAlert...
call flutter pub get
if errorlevel 1 exit /b %errorlevel%
if exist ".dart-defines.json" goto validateSupabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure-supabase.ps1"
if errorlevel 1 exit /b 1

:validateSupabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure-supabase.ps1" -CheckOnly
if errorlevel 1 exit /b 1
echo Abrindo BluAlert no Chrome...
call flutter run --no-pub -d chrome --dart-define-from-file=.dart-defines.json
