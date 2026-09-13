# `scripts/dev.py` — Root Command Runner for Python-only Projects

Equivalent to the root `package.json` scripts for Node projects. Cross-platform (works on Mac, Linux, Windows). Single canonical command: `python scripts/dev.py check:all`.

## File: `scripts/dev.py`

```python
#!/usr/bin/env python3
"""Root commands for the project. Cross-platform replacement for Makefile.

Run from the repo root:
    python scripts/dev.py <command>

Available commands:
    lint        - Run ruff check
    format      - Run ruff format
    format:check - Check formatting without modifying files
    typecheck   - Run mypy
    test        - Run pytest
    build       - Build distribution
    dev         - Start dev server (FastAPI: uvicorn <package>.main:app --reload)
    check:all   - Run lint, format check, typecheck, and tests (build is separate)
"""

from __future__ import annotations

import subprocess
import sys
from typing import Final

# Replace <package_name> with the snake_case Python package name
PACKAGE_NAME: Final[str] = "<package_name>"

COMMANDS: Final[dict[str, list[str]]] = {
    "lint": ["ruff check ."],
    "format": ["ruff format ."],
    "format:check": ["ruff format --check ."],
    "typecheck": ["mypy ."],
    "test": ["pytest"],
    "build": ["python -m build"],
    "dev": [f"uvicorn {PACKAGE_NAME}.main:app --reload"],
    "pre-commit": ["pre-commit run --all-files"],
    "check:all": [
        "ruff check .",
        "ruff format --check .",
        "mypy .",
        "pytest",
    ],
}


def run(cmd: str) -> None:
    """Run a shell command and exit on failure."""
    print(f"\n→ {cmd}")
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        sys.exit(result.returncode)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        commands_list = " | ".join(COMMANDS.keys())
        print(f"Usage: python scripts/dev.py [{commands_list}]")
        print(__doc__)
        sys.exit(1)

    for cmd in COMMANDS[sys.argv[1]]:
        run(cmd)


if __name__ == "__main__":
    main()
```

Make it executable:
```bash
chmod +x scripts/dev.py
```

Then users can run either:
```bash
python scripts/dev.py check:all
# or
./scripts/dev.py check:all
```

## Why not just use a `Makefile`?

Make isn't installed on Windows by default. WSL works but adds setup friction. Python is already required for any Python project, so using a Python script keeps the dependency surface flat.

For research projects, this script is overkill — a 2-line README pointing at the canonical commands is fine.
