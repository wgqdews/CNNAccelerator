@echo off
setlocal enabledelayedexpansion

set DO_DUMP=0
set DO_FULL=0

for %%A in (%*) do (
    if /I "%%A"=="dump" set DO_DUMP=1
    if /I "%%A"=="full" set DO_FULL=1
)

set CROP_ARGS=--crop-h 4 --crop-w 4
if %DO_FULL%==1 set CROP_ARGS=

echo [run_chain2.bat] exporting golden data %CROP_ARGS%
py scripts\export_chain2_golden.py %CROP_ARGS%
if errorlevel 1 (
    echo [run_chain2.bat] export_chain2_golden.py failed
    exit /b 1
)

set GOLDEN_DIR=tb/golden_chain2

copy /Y "%GOLDEN_DIR%\chain2_cfg.vh" "rtl\include\chain2_cfg.vh" >nul
> rtl\include\golden_dir.vh echo `define GOLDEN_DIR "%GOLDEN_DIR%"

echo [run_chain2.bat] compiling with iverilog...
iverilog -g2012 -o sim_chain2.vvp -I rtl/include -f files_chain2.f
if errorlevel 1 (
    echo [run_chain2.bat] iverilog compile failed
    exit /b 1
)

echo [run_chain2.bat] running simulation...
if %DO_DUMP%==1 (
    vvp sim_chain2.vvp +dump
    where gtkwave >nul 2>nul
    if not errorlevel 1 (
        start "" gtkwave sim.vcd
    ) else (
        echo [run_chain2.bat] gtkwave not found in PATH -- VCD written to sim.vcd, open manually
    )
) else (
    vvp sim_chain2.vvp
)

endlocal
