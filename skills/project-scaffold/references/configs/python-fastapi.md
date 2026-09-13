# Python FastAPI Configs

Default Python backend choice. Modern, type-driven, async-first, free interactive API docs.

## Critical: package name consistency

When asking for project name in Step 1, also compute the **snake_case package name** (e.g., `my-project` → `my_project`). Use this name everywhere:

- `pyproject.toml` `name` field (with hyphens for PyPI) and the source layout pointer
- The actual package directory: `<package_name>/`
- The `__init__.py` inside that directory: `<package_name>/__init__.py`
- The FastAPI entry point: `<package_name>/main.py`
- The uvicorn command in AGENTS.md and root scripts: `uvicorn <package_name>.main:app`
- Test imports: `from <package_name>.foo import bar`

Without this, hatchling fails on build ("no source layout") and the project has a confusing mismatch between PyPI name and import name.

---

## `pyproject.toml`

Replace `<project_name>` (with hyphens, kebab-case for PyPI) and `<package_name>` (with underscores, snake_case for Python imports). For most projects these will be the same word but different separators.

```toml
[project]
name = "<project_name>"
version = "0.1.0"
description = "<one-liner>"
requires-python = ">=3.12"
dependencies = [
  "fastapi>=0.115",
  "uvicorn[standard]>=0.32",
  "python-dotenv>=1.0",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.0",
  "pytest-cov>=5.0",
  "pytest-asyncio>=0.24",
  "httpx>=0.27",
  "ruff>=0.6",
  "mypy>=1.11",
  "pre-commit>=3.8",
  "build>=1.2",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["<package_name>"]

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = [
  "E",   # pycodestyle errors
  "W",   # pycodestyle warnings
  "F",   # pyflakes
  "I",   # isort
  "B",   # flake8-bugbear
  "UP",  # pyupgrade
  "N",   # pep8-naming
  "SIM", # flake8-simplify
]
ignore = []

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["E501"]  # allow long lines in tests

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
python_version = "3.12"
strict = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

[tool.pytest.ini_options]
minversion = "8.0"
addopts = "-ra -q --strict-markers"
testpaths = ["tests"]
asyncio_mode = "auto"
markers = [
  "integration: integration tests (deselect with '-m \"not integration\"')",
  "e2e: end-to-end tests (deselect with '-m \"not e2e\"')",
]
```

---

## `.python-version`

```
3.12
```

---

## Environment — the file is `.env`

`python-dotenv` is the loader, and **`load_dotenv()` finds `.env` and nothing else** — it has no
notion of `.env.local`. That is why `.env` is the filename for every project this skill
scaffolds, including the ones with a Next.js frontend: Next reads `.env` too, so one name covers
both halves with no per-stack exception. (Next *also* reads `.env.local`, and prefers it — which
is exactly why a stray `.env.local` is dangerous in a fullstack repo: the frontend would use it
while Python could not see it at all.)

Commit a `.env.example` whose first line names the file to create, and keep the real file
gitignored (`gitignores.md` already has the `!.env.example` negation that keeps the template
committed):

```
# Copy this file to `.env` and fill it in.
API_BASE_URL=
```

(Seed it with the vars this service actually reads. In a fullstack scaffold the database lives
on the frontend side with Drizzle, so `DATABASE_URL` usually does **not** belong here.)

Call `load_dotenv()` once at the top of `main.py`. The scaffolded entry point is
`uvicorn <package_name>.main:app`, so there is no `__main__` block — `main.py`'s module scope
*is* the process boundary. This does not violate the repo's lazy-env convention: that rule is
about modules that **throw** at import when a var is unset, and `load_dotenv()` never throws —
it returns `False` when the file is absent and moves on.

For a containerized or systemd deployment the values come from the platform (an
`EnvironmentFile=`, a dashboard), not from this file. The same call is still correct there:
`load_dotenv()` does not overwrite an env var that is already set.

## Stub source files

`<package_name>/__init__.py` (empty file, just makes it a package):
```python
```

`<package_name>/main.py`:
```python
"""FastAPI application entry point."""

from dotenv import load_dotenv
from fastapi import FastAPI

# Reads `.env` (never `.env.local` — python-dotenv has no such concept). No-op when the
# file is absent, and never overrides a var the platform already set.
load_dotenv()

app = FastAPI(title="<project_name>")


@app.get("/")
async def root() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
```

## Stub tests

`tests/__init__.py` (empty)

`tests/test_smoke.py`:
```python
"""Smoke tests — placeholders so CI doesn't fail on first push."""

from fastapi.testclient import TestClient

from <package_name>.main import app

client = TestClient(app)


def test_smoke() -> None:
    """Trivial sanity check."""
    assert 1 == 1


def test_root_endpoint() -> None:
    """Root endpoint returns ok."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

`tests/integration/__init__.py` (empty)

`tests/integration/test_smoke.py`:
```python
"""Integration test stub — replace with real tests as you build features."""

import pytest


@pytest.mark.integration
def test_integration_smoke() -> None:
    assert True
```

`tests/e2e/__init__.py` (empty)

`tests/e2e/test_smoke.py`:
```python
"""E2E test stub — replace with real tests as you build features."""

import pytest


@pytest.mark.e2e
def test_e2e_smoke() -> None:
    assert True
```

---

## For research projects (lighter)

```toml
[project]
name = "<project_name>"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "jupyter",
  "pandas",
  "numpy",
  "matplotlib",
]

[project.optional-dependencies]
dev = [
  "ruff>=0.6",
  "pre-commit>=3.8",
]

[tool.ruff]
line-length = 100
target-version = "py312"
extend-exclude = ["notebooks/*.ipynb"]

[tool.ruff.lint]
select = ["E", "W", "F", "I"]
```
