@echo off
setlocal
cd /d "%~dp0"
set "PUB_CACHE=%CD%\.pub-cache"
echo Preparando dependencias do BluAlert...
call flutter pub get
if errorlevel 1 exit /b %errorlevel%
if exist ".dart-defines.json" goto withSupabase
echo Configuracao Supabase ausente. O login precisa da URL e da chave publica do projeto.
echo Abrindo BluAlert no Chrome...
call flutter run -d chrome
exit /b %errorlevel%

:withSupabase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure-supabase.ps1" -CheckOnly
if errorlevel 1 exit /b 1
echo Abrindo BluAlert no Chrome...
call flutter run -d chrome --dart-define-from-file=.dart-defines.json
