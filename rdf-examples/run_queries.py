"""Load base.ttl plus each pattern file, run the matching query, and check the result.

Usage (from the repo root):
    .venv/bin/python rdf-examples/run_queries.py

For each pattern pNN_name.ttl:
  - base.ttl + pNN_name.ttl must parse, and queries/pNN_name.rq must return at least one row;
  - as a negative control, the same query against base.ttl + p00_complete.ttl must return zero
    rows (except for p00 itself), so a query that matches everything cannot pass.
The *_contradiction.ttl files are only parsed here; their inconsistency is shown with ROBOT.
Exits non-zero on any parse failure, empty expected result, or non-empty control result.
"""

import sys
from pathlib import Path

from rdflib import Graph

HERE = Path(__file__).resolve().parent
QUERIES = HERE / "queries"


def load(*names: str) -> Graph:
    g = Graph()
    for name in names:
        g.parse(HERE / name, format="turtle")
    return g


def main() -> int:
    failures = []
    # Optional: --merged-dir DIR writes base+pattern(+contradiction) as single Turtle files.
    # ROBOT needs one merged file: `robot merge --input a --input b` parses each file alone, so
    # properties declared only in base.ttl become annotation assertions in the pattern file.
    merged_dir = None
    if "--merged-dir" in sys.argv:
        merged_dir = Path(sys.argv[sys.argv.index("--merged-dir") + 1])
        merged_dir.mkdir(parents=True, exist_ok=True)
    patterns = sorted(p.name for p in HERE.glob("p[0-9][0-9]_*.ttl") if "contradiction" not in p.name)
    contradictions = sorted(p.name for p in HERE.glob("p[0-9][0-9]_*contradiction.ttl"))

    for name in contradictions:
        # p06 and p10 contradictions extend their main pattern; p05's replaces it.
        prefix = name.split("_")[0] + "_"
        extra = [] if prefix == "p05_" else [n for n in patterns if n.startswith(prefix)]
        try:
            g = load("base.ttl", *extra, name)
            print(f"parsed  {name} (with base.ttl {' '.join(extra)}): {len(g)} triples")
            if merged_dir:
                g.serialize(merged_dir / f"merged_{name}", format="turtle")
        except Exception as exc:  # noqa: BLE001
            failures.append(f"{name}: parse error {exc}")

    control = load("base.ttl", "p00_complete.ttl")

    for name in patterns:
        stem = name[:-4]
        qfile = QUERIES / f"{stem}.rq"
        try:
            g = load("base.ttl", name)
        except Exception as exc:  # noqa: BLE001
            failures.append(f"{name}: parse error {exc}")
            continue
        if merged_dir:
            g.serialize(merged_dir / f"merged_{name}", format="turtle")
        if not qfile.exists():
            failures.append(f"{name}: missing query {qfile.name}")
            continue
        query = qfile.read_text()
        rows = list(g.query(query))
        print(f"\n{stem}: {len(rows)} row(s) on base+pattern ({len(g)} triples)")
        for row in rows[:3]:
            print("   ", " | ".join("" if v is None else str(v) for v in row))
        if not rows:
            failures.append(f"{stem}: expected non-empty result, got 0 rows")
        if stem != "p00_complete":
            n_control = len(list(control.query(query)))
            print(f"    control base+p00: {n_control} row(s)")
            if n_control:
                failures.append(f"{stem}: control (base+p00) returned {n_control} rows, expected 0")

    print()
    if failures:
        print("FAILURES:")
        for f in failures:
            print("  ", f)
        return 1
    print(f"OK: {len(patterns)} patterns, {len(contradictions)} contradiction files parsed, all queries as expected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
