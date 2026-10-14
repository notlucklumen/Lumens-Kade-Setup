@echo off
setlocal
title Kade Tool
set "SELF=%~f0"
fltmc >nul 2>&1
if not errorlevel 1 goto :admin
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 echo Administrator access is required.
if errorlevel 1 pause
exit /b
:admin
cd /d "%~dp0"
if exist "Project.xml" goto :found
if not exist "C:\KadeEngine\Kade-Engine-master\Project.xml" goto :nokade
cd /d "C:\KadeEngine\Kade-Engine-master"
goto :found
:nokade
echo Put this file next to Project.xml.
pause
exit /b
:found
set "BIN=%CD%\export\release\windows\bin"
:menu
cls
set "BW=MAIN"
set "BC=200,255,40,170,120,220"
set "BF=[1] Kade Setup;[2] Kade Loader"
call :banner
set "X="
set /p "X=> "
if "%X%"=="1" goto :setup
if "%X%"=="2" goto :loader
goto :menu
:setup
cls
set "BW=INSTALLER"
set "BC=200,255,40,170,120,220"
set "BF=Installing, please wait..."
call :banner
where haxe >nul 2>&1
if errorlevel 1 set "MSG=Haxe is not installed. Install Haxe 4.2.x from https://haxe.org/download/ then try again."
if errorlevel 1 goto :err
where git >nul 2>&1
if errorlevel 1 set "MSG=Git is not installed. Install it from https://git-scm.com/ then restart this window."
if errorlevel 1 goto :err
if not exist "C:\HaxeToolkit\haxe\lib" mkdir "C:\HaxeToolkit\haxe\lib"
haxelib setup "C:\HaxeToolkit\haxe\lib"
call :hl lime 7.9.0
call :hl openfl 9.1.0
call :hl flixel 4.11.0
call :hl flixel-addons 2.11.0
call :hl flixel-ui 2.3.3
call :hl hscript 2.5.0
call :hl actuate
call :hl polymod 1.6.0
call :hg extension-webm https://github.com/KadeDev/extension-webm
call :hg discord_rpc https://github.com/Aidan63/linc_discord-rpc
call :hg linc_luajit https://github.com/nebulazorua/linc_luajit
call :hg hxvm-luajit https://github.com/nebulazorua/hxvm-luajit
haxelib --always run lime setup -y
call :findvs
if defined VSPATH goto :havevs
winget --version >nul 2>&1
if errorlevel 1 set "MSG=winget is not available. Install Build Tools for Visual Studio 2022 with Desktop development with C++ from visualstudio.microsoft.com, then run Setup again."
if errorlevel 1 goto :err
echo Installing Visual Studio 2022 Build Tools. This can take 10 to 30 minutes...
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
call :findvs
if not defined VSPATH set "MSG=Visual Studio tools were not detected. Make sure you have 10 GB free, restart your PC, then run Setup again."
if not defined VSPATH goto :err
:havevs
call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
set "WEBM=C:\HaxeToolkit\haxe\lib\extension-webm\git\ndll\Windows64\extension-webm.ndll"
if exist "%WEBM%" goto :built
call lime rebuild extension-webm windows
call lime rebuild linc_luajit windows
call lime rebuild discord_rpc windows
:built
if not exist "%WEBM%" set "MSG=Native library build failed. Copy the error text above and send it for help."
if not exist "%WEBM%" goto :err
findstr /i /c:"hscriptPos" "Project.xml" >nul 2>&1
if not errorlevel 1 goto :haspos
if not exist "Project.xml.bak" copy /y "Project.xml" "Project.xml.bak" >nul
powershell -NoProfile -Command "$p='Project.xml'; $t=[IO.File]::ReadAllText($p); $d=[char]34; $add='    <haxedef name='+$d+'hscriptPos'+$d+' />'; $t=$t -replace '</project>', ($add+[Environment]::NewLine+'</project>'); [IO.File]::WriteAllText($p,$t)"
:haspos
echo Building Kade Engine. The first build takes a long time, let it run...
call :compile
if errorlevel 1 set "MSG=Build failed. Copy the error text above and send it for help."
if errorlevel 1 goto :err
echo.
echo Setup complete. Choose 2 on the main page to launch.
pause
goto :menu
:loader
cls
set "BW=LOADER"
set "BC=10,130,110,255,40,150"
set "BF=Enter to launch"
call :banner
set "X="
set /p "X="
echo Checking for changes...
call :findgame
if not defined GAME goto :ldbuild
powershell -NoProfile -Command "$g=Get-Item -LiteralPath '%GAME%'; $f=@(Get-ChildItem -LiteralPath 'source' -Recurse -File | Where-Object { $_.Extension -in '.hx','.lua' }); $f+=Get-Item -LiteralPath 'Project.xml'; $n=$f | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($n.LastWriteTime -gt $g.LastWriteTime) { exit 1 } else { exit 0 }"
if errorlevel 1 goto :ldbuild
goto :ldgo
:ldbuild
echo Changes found, rebuilding. Please wait...
call :compile
if errorlevel 1 set "MSG=Build failed or Setup has not been run. Copy the error text above and send it for help."
if errorlevel 1 goto :err
:ldgo
start "" /d "%BIN%" "%GAME%"
exit /b
:err
echo.
echo %MSG%
pause
goto :menu
:banner
where python >nul 2>&1
if not errorlevel 1 (
    python "%~dp0banner.py"
    if not errorlevel 1 exit /b
)
where py >nul 2>&1
if not errorlevel 1 (
    py -3 "%~dp0banner.py"
    if not errorlevel 1 exit /b
)
echo %BW%
echo %BF%
exit /b
:hl
if "%~2"=="" haxelib --always install %~1
if not "%~2"=="" haxelib --always install %~1 %~2
if not "%~2"=="" haxelib set %~1 %~2
exit /b
:hg
haxelib --always git %~1 %~2
exit /b
:findgame
set "GAME="
for %%F in ("%BIN%\*.exe") do if not defined GAME set "GAME=%%~fF"
exit /b
:findvs
set "VSPATH="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" exit /b 0
del "%TEMP%\kvs.txt" >nul 2>&1
"%VSWHERE%" -products * -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%TEMP%\kvs.txt" 2>nul
if exist "%TEMP%\kvs.txt" set /p VSPATH=<"%TEMP%\kvs.txt"
exit /b 0
:compile
call :findvs
if not defined VSPATH exit /b 1
call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
call lime build windows
if errorlevel 1 exit /b 1
call :findgame
if not defined GAME exit /b 1
exit /b 0
