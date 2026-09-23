@echo off
setlocal enabledelayedexpansion

set DO_DUMP=0
set DO_FULL=0

for %%A in (%*) do (
    if /I "%%A"=="dump" set DO_DUMP=1
    if /I "%%A"=="full" set DO_FULL=1
)

set CROP_ARGS=--crop-h 6 --crop-w 6
if %DO_FULL%==1 set CROP_ARGS=

echo [run_maxpool.bat] exporting golden data %CROP_ARGS%
py scripts\export_maxpool_golden.py %CROP_ARGS%
if errorlevel 1 (
    echo [run_maxpool.bat] export_maxpool_golden.py failed
    exit /b 1
)

set GOLDEN_DIR=tb/golden_maxpool

copy /Y "%GOLDEN_DIR%\maxpool_cfg.vh" "rtl\include\maxpool_cfg.vh" >nul
> rtl\include\golden_dir.vh echo `define GOLDEN_DIR "%GOLDEN_DIR%"

echo [run_maxpool.bat] compiling with iverilog...
iverilog -g2012 -o sim_maxpool.vvp -I rtl/include -f files_maxpool.f
if errorlevel 1 (
    echo [run_maxpool.bat] iverilog compile failed
    exit /b 1
)

echo [run_maxpool.bat] running simulation...
if %DO_DUMP%==1 (
    vvp sim_maxpool.vvp +dump
    where gtkwave >nul 2>nul
    if not errorlevel 1 (
        start "" gtkwave sim.vcd
    ) else (
        echo [run_maxpool.bat] gtkwave not found in PATH -- VCD written to sim.vcd, open manually
    )
) else (
    vvp sim_maxpool.vvp
)

endlocal
