@echo off
echo [1/3] Compiling Verilog...
iverilog -g2012  -o sim1.vvp -f files1.f
if %errorlevel% neq 0 (
    echo Compilation Failed!
    pause
    exit /b
)

echo [2/3] Running Simulation...
vvp sim1.vvp

echo [3/3] Opening Waveform...
gtkwave wave1.vcd