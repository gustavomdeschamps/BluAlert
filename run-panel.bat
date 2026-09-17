@echo off
setlocal
cd /d "%~dp0operator-panel"
powershell.exe -NoProfile -Command "try { $page = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:5173/' -TimeoutSec 2; if ($page.Content -match 'BluAlert') { exit 0 }; exit 1 } catch { exit 1 }"
if not errorlevel 1 (
  start "" "http://127.0.0.1:5173/"
  exit /b 0
)
if not exist "node_modules" (
  call npm.cmd ci
  if errorlevel 1 exit /b 1
)
call npm.cmd run dev -- --host 127.0.0.1 --port 5173 --strictPort --open
