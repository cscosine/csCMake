$ErrorActionPreference = "Stop"

python -m venv .venv

.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
pip install -e ".[dev]"
# TODO remove this once csOrchestrator is available in pip
pip install -e ../../../csOrchestrator

pre-commit install

Write-Host "Setup complete."
Write-Host ""
Write-Host "Next:"
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  code ."
Write-Host ""
Write-Host "Or: "
Write-Host ""
Write-Host ".\open-code.ps1"
