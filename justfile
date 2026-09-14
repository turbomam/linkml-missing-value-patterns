# Entry points for this repository. The logic lives in the two scripts, which also run
# without just (bash 3.2 or later).

# List the recipes
default:
    @just --list

# Install the pinned linkml into .venv
setup:
    uv sync

# Validate every example against its option's schema; valid_* must pass, invalid_* must fail
check: setup
    ./run_checks.sh

# Rebuild generated/: OWL for every schema, each option's examples as YAML, and TSV and Turtle where conversion works
convert: setup
    ./convert.sh

# Run the checks, then rebuild generated/
all: check convert
