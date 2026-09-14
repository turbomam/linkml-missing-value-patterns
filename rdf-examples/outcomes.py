"""Run queries/any_outcome.rq, one query, against base.ttl plus each pattern file.

Usage (from the repo root):
    .venv/bin/python rdf-examples/outcomes.py

Prints the kinds of outcome found in each file. p01 is expected to find nothing: nothing was said.
Exits non-zero if any other pattern file returns no rows.
"""

import sys
from pathlib import Path

from rdflib import Graph

HERE = Path(__file__).resolve().parent
QUERY = (HERE / "queries" / "any_outcome.rq").read_text()
SILENT = {"p01_nothing_asserted"}


def main() -> int:
    missing = []
    for path in sorted(HERE.glob("p[0-9][0-9]_*.ttl")):
        if "contradiction" in path.name:
            continue
        g = Graph()
        g.parse(HERE / "base.ttl", format="turtle")
        g.parse(path, format="turtle")
        rows = sorted({(str(r.kind), str(r.detail).rsplit("/", 1)[-1]) for r in g.query(QUERY)})
        found = "; ".join(f"{k} ({d})" if d else k for k, d in rows) or "nothing"
        print(f"{path.stem:<30} {found}")
        if not rows and path.stem not in SILENT:
            missing.append(path.stem)
    if missing:
        print("FAILURES: no outcome found in " + ", ".join(missing))
        return 1
    print("OK: one query found an outcome in every pattern except p01, where nothing was said")
    return 0


if __name__ == "__main__":
    sys.exit(main())
