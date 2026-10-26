#!/usr/bin/env bash
# Open the demo notebook in JupyterLab. Cells are plain shell (%%bash), so any
# Python 3 with Jupyter works. With uv installed there is nothing to set up.
set -euo pipefail

cd "$(dirname "$0")"

if command -v uvx >/dev/null; then
  exec uvx --from jupyterlab jupyter lab jobset-demo.ipynb
elif command -v jupyter >/dev/null; then
  exec jupyter lab jobset-demo.ipynb
else
  echo "Install uv (brew install uv) or JupyterLab (pip install jupyterlab), then re-run $0" >&2
  exit 1
fi
