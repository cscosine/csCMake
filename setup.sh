#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "Do not source this script. Run: ./setup.sh"
  return 1
fi
python3 -m venv .venv

source .venv/bin/activate

python -m pip install --upgrade pip
pip install -e ".[dev]"
# TODO remove this once csOrchestrator is available in pip
pip install -e ../../../csOrchestrator

pre-commit install

echo "Setup complete."
echo ""
echo "Next: "
echo "  source .venv/bin/activate"
echo "  code ."
echo ""
echo "Or: "
echo "  ./open-code.sh"
echo ""
echo "Or: "
echo "  source ./open-code.sh"
