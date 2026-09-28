@echo off
REM ---------------------------------------------------------------------------
REM build-linux.cmd — Windows launcher for scripts/build-linux.sh
REM
REM build-linux.sh is a bash script. On Windows it must run under Git Bash
REM (or MSYS2/Cygwin). This launcher finds a Git Bash installation and runs the
REM .sh from a plain cmd / PowerShell prompt. All flags are passed through
REM (e.g. --remote ubuntu-arm --debug --fetch).
REM
REM The build itself runs inside the Ubuntu-arm-docker box over SSH, so on
REM Windows you just need: Git for Windows (for the shell) + an OpenSSH client.
REM rsync is optional here — build-linux.sh falls back to tar when it's absent.
REM
REM Usage:
REM   scripts\build-linux.cmd --remote ubuntu-arm --debug --fetch
REM   scripts\build-linux.cmd --help
REM ---------------------------------------------------------------------------
setlocal enabledelayedexpansion

REM Locate Git Bash (Git for Windows installs it in several well-known spots).
set "BASH="
for %%D in (
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles(x86)%\Git\bin\bash.exe"
  "%LocalAppData%\Programs\Git\bin\bash.exe"
  "%USERPROFILE%\AppData\Local\Programs\Git\bin\bash.exe"
  "%ProgramW6432%\Git\bin\bash.exe"
) do (
  if exist "%%~D" set "BASH=%%~D"
)

if not defined BASH (
  echo error: Git Bash not found. Install Git for Windows, or run build-linux.sh
  echo        from inside a Git Bash / MSYS2 / Cygwin terminal instead.
  exit /b 1
)

REM Run the bash script: switch to the script's directory so the .sh resolves
REM the repo root by its own location, and forward every argument.
pushd "%~dp0"
"%BASH%" -l -c 'exec "$0" "$@"' "%~dp0build-linux.sh" %*
set "RC=!ERRORLEVEL!"
popd
exit /b %RC%