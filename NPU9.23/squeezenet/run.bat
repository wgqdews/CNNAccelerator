@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: run.bat ^<layer^> [dump] [full]
    echo   layer : conv1 ^| fire2_squeeze
    echo   dump  : enable VCD dump ^(sim.vcd^) and try to open GTKWave when the sim finishes
    echo   full  : export the real full-size layer instead of the default 6x6 debug crop
    exit /b 1
)

set LAYER=%~1
set DO_DUMP=0
set DO_FULL=0

for %%A in (%*) do (
    if /I "%%A"=="dump" set DO_DUMP=1
    if /I "%%A"=="full" set DO_FULL=1
)

set CROP_ARGS=--crop-h 6 --crop-w 6
if %DO_FULL%==1 set CROP_ARGS=

echo [run.bat] exporting golden data for layer=%LAYER% %CROP_ARGS%
py scripts\export_golden.py --layer %LAYER% %CROP_ARGS%
if errorlevel 1 (
    echo [run.bat] export_golden.py failed
    exit /b 1
)

set GOLDEN_DIR=tb/golden/%LAYER%

REM iverilog on this Windows setup mis-parses quoted string macros passed via -D
REM (breaks once -o is also present), so instead generate small fixed-name .vh
REM files that rtl/include/layer_select.vh always `includes.
copy /Y "%GOLDEN_DIR%\%LAYER%_cfg.vh" "rtl\include\layer_cfg.vh" >nul
> rtl\include\golden_dir.vh echo `define GOLDEN_DIR "%GOLDEN_DIR%"

echo [run.bat] compiling with iverilog...
iverilog -g2012 -o sim.vvp -I rtl/include -f files.f
if errorlevel 1 (
    echo [run.bat] iverilog compile failed
    exit /b 1
)

echo [run.bat] running simulation...
if %DO_DUMP%==1 (
    vvp sim.vvp +dump
    where gtkwave >nul 2>nul
    if not errorlevel 1 (
        start "" gtkwave sim.vcd
    ) else (
        echo [run.bat] gtkwave not found in PATH -- VCD written to sim.vcd, open manually
    )
) else (
    vvp sim.vvp
)

endlocal
