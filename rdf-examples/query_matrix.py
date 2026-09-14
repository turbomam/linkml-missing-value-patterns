"""Run every pattern query against every pattern file and print the row counts.

Usage (from the repo root):
    .venv/bin/python rdf-examples/query_matrix.py

Rows are queries, columns are data files (base.ttl plus one pattern file). The diagonal is the
pattern each query was written for and must be non-empty. Off-diagonal counts are reported, not
failed: they show which patterns a query cannot tell apart. Exits non-zero only if a diagonal
cell is empty or a file fails to parse.
"""

import sys
from pathlib import Path

from rdflib import Graph

HERE = Path(__file__).resolve().parent
QUERIES = HERE / "queries"


def main() -> int:
    patterns = sorted(p.stem for p in HERE.glob("p[0-9][0-9]_*.ttl") if "contradiction" not in p.name)
    graphs = {}
    for stem in patterns:
        g = Graph()
        g.parse(HERE / "base.ttl", format="turtle")
        g.parse(HERE / f"{stem}.ttl", format="turtle")
        graphs[stem] = g
    short = [s.split("_")[0] for s in patterns]
    counts = {}
    for q in patterns:
        text = (QUERIES / f"{q}.rq").read_text()
        for d in patterns:
            counts[q, d] = len(list(graphs[d].query(text)))

    width = max(len(s) for s in patterns)
    print(f"{'query / data':<{width}}  " + " ".join(f"{s:>4}" for s in short))
    for q in patterns:
        cells = []
        for d in patterns:
            n = counts[q, d]
            cell = str(n) if n else "."
            cells.append(f"{'[' + cell + ']' if q == d else cell:>4}")
        print(f"{q:<{width}}  " + " ".join(cells))

    empty_diagonal = [q for q in patterns if counts[q, q] == 0]
    cross = [(q, d, counts[q, d]) for q in patterns for d in patterns if q != d and counts[q, d]]
    print(f"\n[n] = the pattern the query was written for; . = no rows")
    print(f"off-diagonal hits: {len(cross)}")
    for q, d, n in cross:
        print(f"  {q.split('_')[0]} query matches {d}: {n} row(s)")
    if empty_diagonal:
        print("FAILURES: empty diagonal for " + ", ".join(empty_diagonal))
        return 1
    print(f"OK: all {len(patterns)} queries find their own pattern")
    return 0


if __name__ == "__main__":
    sys.exit(main())
