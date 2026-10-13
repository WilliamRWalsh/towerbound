#!/usr/bin/env bash
# Runs the GUT unit and integration tests headless. Extra arguments go to GUT, e.g.
#   ./run_tests.sh -gselect=test_deck.gd
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# Import first so new scripts and assets have class names and .import files.
godot --headless --path "$ROOT" --import >/dev/null 2>&1 || true
exec godot --headless --fixed-fps 60 --path "$ROOT" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
