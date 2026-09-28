@echo off
REM ---------------------------------------------------------------------------
REM android-autogen.cmd — Windows launcher for scripts/Android/android-autogen.sh
REM
REM android-autogen.sh is a bash script. On Windows it must run under Git Bash
REM (or MSYS2/Cygwin). This launcher finds a Git Bash installation and runs the
REM .sh from a plain cmd / PowerShell prompt. All flags are passed through
REM (e.g. --build).
REM
REM Usage:
REM   scripts\Android\android-autogen.cmd            regenerate gen/android
REM   scripts\Android\android-autogen.cmd --build    + build debug APK
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
  echo error: Git Bash not found. Install Git for Windows, or run android-autogen.sh
  echo        from inside a Git Bash / MSYS2 / Cygwin terminal instead.
  exit /b 1
)

REM Run the bash script: switch to the script's directory so the .sh resolves
REM the repo root by its own location, and forward every argument.
pushd "%~dp0"
"%BASH%" -l -c 'exec "$0" "$@"' "%~dp0android-autogen.sh" %*
set "RC=!ERRORLEVEL!"
popd
exit /b %RC%