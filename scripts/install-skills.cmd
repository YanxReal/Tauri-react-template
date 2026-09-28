@echo off
REM ---------------------------------------------------------------------------
REM install-skills.cmd — Windows launcher for scripts/install-skills.sh
REM
REM install-skills.sh is a bash script. On Windows it must run under Git Bash
REM (or MSYS2/Cygwin). This launcher finds a Git Bash installation and runs the
REM .sh from a plain cmd / PowerShell prompt, so you don't have to open Git Bash
REM by hand. All flags are passed through (e.g. --global, --verify, --list).
REM
REM Usage:
REM   scripts\install-skills.cmd                    install into this project
REM   scripts\install-skills.cmd --global           install for all your projects
REM   scripts\install-skills.cmd --verify           check installs match source
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
  echo error: Git Bash not found. Install Git for Windows, or run install-skills.sh
  echo        from inside a Git Bash / MSYS2 / Cygwin terminal instead.
  exit /b 1
)

REM Run the bash script: switch to the script's directory so the .sh resolves
REM the repo root by its own location, and forward every argument.
pushd "%~dp0"
"%BASH%" -l -c 'exec "$0" "$@"' "%~dp0install-skills.sh" %*
set "RC=!ERRORLEVEL!"
popd
exit /b %RC%