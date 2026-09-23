@echo off
setlocal enabledelayedexpansion

set DO_DUMP=0

for %%A in (%*) do (
    if /I "%%A"=="dump" set DO_DUMP=1
)

echo [run_gap.bat] exporting golden data
py scripts\export_gap_golden.py
if errorlevel 1 (
    echo [run_gap.bat] export_gap_golden.py failed
    exit /b 1
)

set GOLDEN_DIR=tb/golden_gap

copy /Y "%GOLDEN_DIR%\gap_cfg.vh" "rtl\include\gap_cfg.vh" >nul
> rtl\include\golden_dir.vh echo `define GOLDEN_DIR "%GOLDEN_DIR%"

echo [run_gap.bat] compiling with iverilog...
iverilog -g2012 -o sim_gap.vvp -I rtl/include -f files_gap.f
if errorlevel 1 (
    echo [run_gap.bat] iverilog compile failed
    exit /b 1
)

echo [run_gap.bat] running simulation...
if %DO_DUMP%==1 (
    vvp sim_gap.vvp +dump
    where gtkwave >nul 2>nul
    if not errorlevel 1 (
        start "" gtkwave sim.vcd
    ) else (
        echo [run_gap.bat] gtkwave not found in PATH -- VCD written to sim.vcd, open manually
    )
) else (
    vvp sim_gap.vvp
)

endlocal
