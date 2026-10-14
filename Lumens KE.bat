@echo off
setlocal
title Kade Engine 1.4
set "SELF=%~f0"
fltmc >nul 2>&1
if not errorlevel 1 goto :admin
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 echo Administrator access is required.
if errorlevel 1 pause
exit /b
:admin
set "PATH=C:\HaxeToolkit\haxe;C:\HaxeToolkit\neko;C:\Program Files\Git\cmd;%PATH%"
set "HAXEPATH=C:\HaxeToolkit\haxe"
set "KADE=C:\KadeEngine\Kade-Engine-1.4-KE\"
:menu
cls
set "BW=KADE LOADER"
set "BC=10,130,110,255,40,150"
set "BF=[1] Download Kade 1.4;[2] Run Kade 1.4"
call :banner
set "X="
set /p "X=> "
if "%X%"=="1" goto :setup
if "%X%"=="2" goto :run
goto :menu
:setup
cls
echo [1/6] Checking Git...
where git >nul 2>&1
if not errorlevel 1 goto :gitok
winget --version >nul 2>&1
if errorlevel 1 set "MSG=winget is not available. Install Git from git-scm.com, then try again."
if errorlevel 1 goto :err
echo Installing Git...
winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
where git >nul 2>&1
if errorlevel 1 set "MSG=Git install failed. Install Git from git-scm.com, then try again."
if errorlevel 1 goto :err
:gitok
echo [2/6] Checking Haxe...
where haxe >nul 2>&1
if not errorlevel 1 goto :haxeok
echo Installing Haxe 4.2.5...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest 'https://github.com/HaxeFoundation/haxe/releases/download/4.2.5/haxe-4.2.5-win.exe' -OutFile ($env:TEMP+'\haxe-setup.exe') -UseBasicParsing"
start /wait "" "%TEMP%\haxe-setup.exe" /S /D=C:\HaxeToolkit\haxe
where haxe >nul 2>&1
if errorlevel 1 set "MSG=Haxe install failed. Install Haxe 4.2.5 from haxe.org, then try again."
if errorlevel 1 goto :err
:haxeok
if exist "%KADE%Project.xml" goto :havesrc
echo [3/6] Downloading Kade Engine 1.4...
if not exist "C:\KadeEngine" mkdir "C:\KadeEngine"
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; $z='C:\KadeEngine\kade.zip'; Invoke-WebRequest 'https://github.com/KadeArchive/Kade-Engine/archive/refs/tags/1.4-KE.zip' -OutFile $z -UseBasicParsing; Expand-Archive -LiteralPath $z -DestinationPath 'C:\KadeEngine' -Force; Remove-Item $z"
if not exist "%KADE%Project.xml" set "MSG=Could not download Kade Engine 1.4. Check your internet connection and try again."
if not exist "%KADE%Project.xml" goto :err
:havesrc
cd /d "%KADE%"
powershell -NoProfile -Command "Get-ChildItem source -Recurse -Filter *.hx | ForEach-Object { $c=[IO.File]::ReadAllText($_.FullName); $n=[regex]::Replace($c,'(?m)^(\s*)(polymod\.Polymod\.init\([^\r\n]*\);)[ \t]*$','$1//$2'); if($n -ne $c){[IO.File]::WriteAllText($_.FullName,$n)} }"
echo [4/6] Installing libraries in their own folder, your other Kade builds are not touched...
if not exist "C:\HaxeToolkit\haxe\lib" mkdir "C:\HaxeToolkit\haxe\lib"
haxelib setup "C:\HaxeToolkit\haxe\lib"
if not exist ".haxelib" haxelib newrepo
powershell -NoProfile -Command "$t=[IO.File]::ReadAllText('%SELF%'); $a=$t.IndexOf('#'+'#LIBS#'+'#'); $b=$t.IndexOf('#'+'#PS#'+'#'); Invoke-Expression $t.Substring($a,$b-$a)"
call "%TEMP%\kade_libs.bat"
echo [5/6] Checking Visual Studio C++ tools...
call :findvs
if defined VSPATH goto :vsok
winget --version >nul 2>&1
if errorlevel 1 set "MSG=winget is not available. Install Build Tools for Visual Studio 2022 with Desktop development with C++, then try again."
if errorlevel 1 goto :err
powershell -NoProfile -Command "if((Get-PSDrive C).Free -lt 9GB){exit 1}"
if errorlevel 1 set "MSG=Not enough free space on C:. Free up at least 10 GB, then try again."
if errorlevel 1 goto :err
echo Installing Visual Studio 2022 Build Tools. This can take 10 to 30 minutes...
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
call :findvs
if not defined VSPATH set "MSG=Visual Studio tools were not detected. Restart your PC and try again."
if not defined VSPATH goto :err
:vsok
call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
echo Building native libraries...
for %%L in (extension-webm linc_luajit discord_rpc) do if exist ".haxelib\%%L" call haxelib run lime rebuild %%L windows
echo [6/6] Building Kade Engine 1.4. The first build takes a long time, let it run...
call :compile
if errorlevel 1 set "MSG=Build failed. Copy the error text above and send it for help."
if errorlevel 1 goto :err
echo ok> ".kade_ok"
echo.
echo Kade 1.4 is ready. Choose 2 on the menu to run it.
pause
goto :menu
:run
if not exist "%KADE%Project.xml" set "MSG=Kade 1.4 is not downloaded yet. Choose 1 first."
if not exist "%KADE%Project.xml" goto :err
cd /d "%KADE%"
if not exist ".kade_ok" set "MSG=Setup is not finished. Choose 1 first."
if not exist ".kade_ok" goto :err
echo Checking for changes...
call :findgame
if not defined GAME goto :build
powershell -NoProfile -Command "$g=Get-Item -LiteralPath '%GAME%'; $f=@(Get-ChildItem -LiteralPath 'source' -Recurse -File | Where-Object { $_.Extension -in '.hx','.lua' }); $f+=Get-Item -LiteralPath 'Project.xml'; $n=$f | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($n.LastWriteTime -gt $g.LastWriteTime) { exit 1 } else { exit 0 }"
if errorlevel 1 goto :build
goto :launch
:build
echo Changes found, rebuilding. Please wait...
call :compile
if errorlevel 1 set "MSG=Build failed. Copy the error text above and send it for help."
if errorlevel 1 goto :err
:launch
echo Launching the game...
start /wait "" /d "%BIN%" "%GAME%"
echo.
echo The game closed with exit code %ERRORLEVEL%.
pause
goto :menu
:err
echo.
echo %MSG%
pause
goto :menu
:banner
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%SELF%'); Invoke-Expression $t.Substring($t.IndexOf('#'+'#PS#'+'#'))"
exit /b
:findgame
set "GAME="
set "BIN=%CD%\export\debug\windows\bin"
for %%F in ("%BIN%\*.exe") do if not defined GAME set "GAME=%%~fF"
exit /b 0
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
call haxelib run lime build windows -debug
if errorlevel 1 exit /b 1
call :findgame
if not defined GAME exit /b 1
exit /b 0
##LIBS##
$x=[IO.File]::ReadAllText('Project.xml')
$x=[regex]::Replace($x,'(?s)<!--.*?-->','')
$pin=@{lime='7.9.0';openfl='9.1.0';hxcpp='4.3.2';flixel='4.11.0';'flixel-addons'='2.11.0';'flixel-ui'='2.3.3';hscript='2.4.0';polymod='1.3.0';actuate='1.9.0';newgrounds='1.1.5'}
$git=@{discord_rpc='https://github.com/Aidan63/linc_discord-rpc';linc_luajit='https://github.com/nebulazorua/linc_luajit';'hxvm-luajit'='https://github.com/nebulazorua/hxvm-luajit';'extension-webm'='https://github.com/KadeDev/extension-webm'}
$names=@('lime','openfl','hxcpp')
foreach($m in [regex]::Matches($x,'<haxelib\s+name="([^"]+)"([^>]*)>')){if($m.Groups[2].Value -notmatch 'switch'){$names+=$m.Groups[1].Value}}
$out=@()
foreach($n in ($names|Select-Object -Unique)){
if($git.ContainsKey($n)){$out+="haxelib --always git $n $($git[$n])"}
elseif($pin.ContainsKey($n)){$out+="haxelib --always install $n $($pin[$n])";$out+="haxelib set $n $($pin[$n])"}
else{$out+="haxelib --always install $n"}
}
Set-Content -Path "$env:TEMP\kade_libs.bat" -Value $out -Encoding ASCII
##PS##
$ErrorActionPreference='SilentlyContinue'
try{
$s='[DllImport("kernel32.dll")]public static extern IntPtr GetStdHandle(int h);[DllImport("kernel32.dll")]public static extern bool GetConsoleMode(IntPtr h,out uint m);[DllImport("kernel32.dll")]public static extern bool SetConsoleMode(IntPtr h,uint m);'
$k=Add-Type -MemberDefinition $s -Name K -Namespace KL -PassThru
$hd=$k::GetStdHandle(-11);[uint32]$md=0
[void]$k::GetConsoleMode($hd,[ref]$md);[void]$k::SetConsoleMode($hd,($md -bor 4))
}catch{}
try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}
$e=[char]27
$cw=120
try{$cw=[Console]::WindowWidth}catch{}
$art=@{}
$art['KADE']=@('##      ##    ######    ########    ##########','##    ##    ##      ##  ##      ##  ##        ','##  ##      ##      ##  ##      ##  ##        ','####        ##########  ##      ##  ########  ','##  ##      ##      ##  ##      ##  ##        ','##    ##    ##      ##  ##      ##  ##        ','##      ##  ##      ##  ########    ##########')
$art['LOADER']=@('##            ######      ######    ########    ##########  ########  ','##          ##      ##  ##      ##  ##      ##  ##          ##      ##','##          ##      ##  ##      ##  ##      ##  ##          ##      ##','##          ##      ##  ##########  ##      ##  ########    ########  ','##          ##      ##  ##      ##  ##      ##  ##          ##  ##    ','##          ##      ##  ##      ##  ##      ##  ##          ##    ##  ','##########    ######    ##      ##  ########    ##########  ##      ##')
$bc=$env:BC.Split(',')|%{[int]$_}
function Lp($a,$b,$t){[int]($a+($b-$a)*$t)}
function Pad($n){' '*[Math]::Max(0,[int](($cw-$n)/2))}
function Big($w){
$cf="$env:TEMP\kade_$w.txt"
$t=''
if(Test-Path $cf){$t=[IO.File]::ReadAllText($cf)}
else{try{$t=[string](Invoke-RestMethod -Uri "https://asciified.thelicato.io/api/v2/ascii?text=$w&font=Banner3" -TimeoutSec 5)}catch{$t=''}}
$ls=@($t -split "`r?`n"|Where-Object{$_.Trim().Length})
if($ls.Count -ge 5 -and $ls.Count -le 12 -and $t.Contains('#')){
$mw=($ls|Measure-Object -Property Length -Maximum).Maximum
if($mw -le ($cw-2)){
if(-not(Test-Path $cf)){[IO.File]::WriteAllText($cf,$t)}
return ,@($ls|%{$_.PadRight($mw)})
}
}
return ,$art[$w]
}
function Draw($ls){
$mx=($ls|Measure-Object -Property Length -Maximum).Maximum
$n=$ls.Count
$buf=''
for($row=0;$row -lt $n;$row++){
$line=$ls[$row]
$sb=Pad $mx
for($c=0;$c -lt $line.Length;$c++){
if($line[$c] -eq ' '){$sb+=' ';continue}
$t=(($c/[double]$mx)+($row/[double]$n))/2
$sb+="$e[38;2;$(Lp $bc[0] $bc[1] $t);$(Lp $bc[2] $bc[3] $t);$(Lp $bc[4] $bc[5] $t)m$($line[$c])"
}
$buf+=$sb+"$e[0m`n"
}
return $buf
}
try{
$out="`n"
foreach($w in $env:BW.Split(' ')){
$out+=Draw (Big $w)
$out+="`n"
}
$items=$env:BF.Split(';')
$fw=($items|Measure-Object -Property Length -Maximum).Maximum
foreach($it in $items){$out+=(Pad $fw)+"$e[1;38;2;$($bc[1]);$($bc[3]);$($bc[5])m$it$e[0m`n"}
[Console]::Write($out)
}catch{
Write-Host $env:BW
Write-Host $env:BF
}
