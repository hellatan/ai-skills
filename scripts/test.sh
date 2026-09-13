#!/usr/bin/env bash
# Run the local validation suite from the repository root.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bash -n scripts/install.sh scripts/validate.sh scripts/test.sh \
  scripts/test-install.sh scripts/test-validate.sh scripts/test-instruction-templates.sh
./scripts/validate.sh
./scripts/test-validate.sh
./scripts/test-install.sh
./scripts/test-instruction-templates.sh
