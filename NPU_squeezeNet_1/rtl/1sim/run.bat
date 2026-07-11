@echo off
echo [1/3] Compiling Verilog...
iverilog -g2012  -o sim.vvp -f files.f
if %errorlevel% neq 0 (
    echo Compilation Failed!
    pause
    exit /b
)

echo [2/3] Running Simulation...
vvp sim.vvp

echo [3/3] Opening Waveform...
gtkwave wave.vcd