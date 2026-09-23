@echo off
setlocal enabledelayedexpansion

set DO_DUMP=0

for %%A in (%*) do (
    if /I "%%A"=="dump" set DO_DUMP=1
)

REM No crop support: expand3x3 (pad=1) needs real neighbor context at any crop
REM boundary that isn't a true image edge (see export_seq_chain_golden.py),
REM so this test always runs the full chain at full resolution.
echo [run_seq_chain.bat] exporting golden data (full resolution)
py scripts\export_seq_chain_golden.py
if errorlevel 1 (
    echo [run_seq_chain.bat] export_seq_chain_golden.py failed
    exit /b 1
)

set GOLDEN_DIR=tb/golden_seq_chain

copy /Y "%GOLDEN_DIR%\seq_chain_cfg.vh" "rtl\include\seq_chain_cfg.vh" >nul
copy /Y "%GOLDEN_DIR%\seq_chain_weight_loads.vh" "rtl\include\seq_chain_weight_loads.vh" >nul
copy /Y "%GOLDEN_DIR%\seq_chain_bias_loads.vh" "rtl\include\seq_chain_bias_loads.vh" >nul
> rtl\include\golden_dir.vh echo `define GOLDEN_DIR "%GOLDEN_DIR%"

echo [run_seq_chain.bat] compiling with iverilog...
iverilog -g2012 -o sim_seq_chain.vvp -I rtl/include -f files_seq_chain.f
if errorlevel 1 (
    echo [run_seq_chain.bat] iverilog compile failed
    exit /b 1
)

echo [run_seq_chain.bat] running simulation...
if %DO_DUMP%==1 (
    vvp sim_seq_chain.vvp +dump
    where gtkwave >nul 2>nul
    if not errorlevel 1 (
        start "" gtkwave sim.vcd
    ) else (
        echo [run_seq_chain.bat] gtkwave not found in PATH -- VCD written to sim.vcd, open manually
    )
) else (
    vvp sim_seq_chain.vvp
)

endlocal
