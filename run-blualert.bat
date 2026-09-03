@echo off
setlocal
cd /d "%~dp0"
set "PUB_CACHE=%CD%\.pub-cache"
echo Preparando dependencias do BluAlert...
call flutter pub get
if errorlevel 1 exit /b %errorlevel%
echo Abrindo BluAlert no Chrome...
call flutter run -d chrome --dart-define-from-file=.dart-defines.json
