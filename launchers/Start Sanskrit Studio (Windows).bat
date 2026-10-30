@echo off
rem Starts Sanskrit Composer Studio with the Ruby and sqlite3 bundled in app\runtime and opens it in the browser.
setlocal
title Sanskrit Composer Studio
cd /d "%~dp0app"
set "SQLITE3=%~dp0app\runtime\sqlite\sqlite3.exe"
set "OPEN_BROWSER=1"
"%~dp0app\runtime\ruby\bin\ruby.exe" lib\server.rb
if errorlevel 1 (
  echo.
  echo Sanskrit Composer Studio stopped with an error. See the messages above.
  pause
)
