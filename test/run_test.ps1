# Run cocotb tests on Windows (Icarus Verilog + cocotb 2.x)
$ErrorActionPreference = "Stop"

$ossCad = "C:\Tools\oss-cad-suite"
if (Test-Path $ossCad) {
    $env:PATH = "$ossCad\bin;$ossCad\lib;" + $env:PATH
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$libDir = cocotb-config --lib-dir
$env:LIBPYTHON_LOC = cocotb-config --libpython
$env:PYGPI_PYTHON_BIN = (Get-Command python).Source

function Run-Sim {
    param($Vvp, $Top, $Modules)
    $env:TOPLEVEL = $Top
    $env:COCOTB_TEST_MODULES = $Modules
    vvp -M $libDir -m cocotbvpi_icarus $Vvp
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "=== Wrapper tests (tt_um_tensor_mac) ==="
iverilog -o sim.vvp -s tt_um_tensor_mac -g2012 "..\src\tt_um_tensor_mac.v" "..\src\mac_core.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Run-Sim "sim.vvp" "tt_um_tensor_mac" "test_mac"

Write-Host "=== Core tests (mac_core) ==="
iverilog -o sim_core.vvp -s mac_core -g2012 "..\src\mac_core.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Run-Sim "sim_core.vvp" "mac_core" "test_mac_core"

Write-Host "All tests passed."
exit 0
