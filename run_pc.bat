@echo off

nim c -d:ssl -d:release --opt:speed --hints:off -o:bin\nautilus.exe src\nautilus.nim
if errorlevel 1 (
    echo Build failed, aborting.
    pause
    exit /b 1
)

bin\nautilus.exe
