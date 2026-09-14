#!/usr/bin/env bash
# Write every schema as OWL, and every option's valid examples as one YAML file, one TSV table
# and one RDF (Turtle) graph, using only the standard LinkML command line tools.
# Everything is written under generated/, which this script deletes and rebuilds.
#
# Some options do not survive conversion, and that is a finding rather than a bug in this
# script (see docs/findings.md). Those failures are expected and reported. The script exits
# non-zero if a conversion fails that was expected to work, or succeeds when it was expected
# to fail, so the findings cannot go stale silently.
# Written for bash 3.2, which is what macOS ships, so no associative arrays.

set -uo pipefail
cd "$(dirname "$0")"

BIN=./.venv/bin
[ -x "$BIN/linkml-convert" ] || { echo "no linkml-convert in $BIN; run: uv sync"; exit 2; }

schema_for() {
  case "$1" in
    option0) echo src/schema/option0_strict.yaml ;;
    option1) echo src/schema/option1_union.yaml ;;
    option1b) echo src/schema/option1b_exactly_one_of.yaml ;;
    option2) echo src/schema/option2_reified.yaml ;;
    option3) echo src/schema/option3_sibling.yaml ;;
    option4) echo src/schema/option4_out_of_band.yaml ;;
  esac
}

container_for() {
  case "$1" in
    option4) echo Dataset ;;
    *)       echo BiosampleSet ;;
  esac
}

# The union options put a number and a term IRI in the same slot. Neither the TSV nor the RDF
# writer in linkml 1.11.1 can serialize that. See docs/findings.md.
expected_to_fail() {
  case "$1:$2" in
    option1:tsv|option1:ttl|option1b:tsv|option1b:ttl) return 0 ;;
    *) return 1 ;;
  esac
}

rm -rf generated
mkdir -p generated/owl
log=$(mktemp)
surprises=0

report() {  # option, output, succeeded (yes/no)
  local expected=ok actual=ok note=""
  expected_to_fail "$1" "$2" && expected=fail
  [ "$3" = yes ] || actual=fail
  if [ "$expected" != "$actual" ]; then
    note="UNEXPECTED"
    surprises=$((surprises+1))
  fi
  [ "$actual" = fail ] && note="$note $(grep -E 'Error|Exception' "$log" | tail -1 | cut -c1-90)"
  printf '%-9s %-6s %-5s %s\n' "$1" "$2" "$actual" "$note"
}

convert() {  # schema, container class, index slot, format, output, input
  # Run from the schema directory. When writing TSV or RDF, linkml-convert resolves
  # "imports: [common]" against the working directory rather than the schema's own directory.
  local root
  root=$(pwd)
  (cd "$(dirname "$1")" && "$root/$BIN/linkml-convert" -s "$(basename "$1")" -C "$2" \
     --index-slot "$3" -t "$4" -o "$root/$5" "$root/$6") > "$log" 2>&1
}

printf '%-9s %-6s %-5s %s\n' OPTION OUTPUT RESULT NOTE
printf '%.0s-' $(seq 1 78); echo

for opt in option0 option1 option1b option2 option3 option4; do
  schema=$(schema_for "$opt")
  out=generated/$opt
  mkdir -p "$out"

  if "$BIN/gen-owl" "$schema" > "generated/owl/$(basename "$schema" .yaml).owl.ttl" 2> "$log"; then
    report "$opt" owl yes
  else
    report "$opt" owl no
  fi

  # Gather the valid examples into one container document, so they become one table and one graph.
  "$BIN/python" - "$opt" "$out/examples.yaml" <<'EOF'
import pathlib, sys, yaml
opt, target = sys.argv[1], pathlib.Path(sys.argv[2])
merged = {}
for f in sorted(pathlib.Path("data", opt).glob("valid_*.yaml")):
    doc = yaml.safe_load(f.read_text())
    parts = doc if "samples" in doc else {"samples": [doc]}
    for key, items in parts.items():
        merged.setdefault(key, []).extend(items)
target.write_text(yaml.safe_dump(merged, sort_keys=False, allow_unicode=True))
EOF

  for fmt in tsv ttl; do
    if convert "$schema" "$(container_for "$opt")" samples "$fmt" "$out/examples.$fmt" "$out/examples.yaml"; then
      report "$opt" "$fmt" yes
    else
      rm -f "$out/examples.$fmt"
      report "$opt" "$fmt" no
    fi
  done
done

# Option 4 keeps its absence records in a second list, which a samples table cannot show.
if convert "$(schema_for option4)" Dataset missing_value_reports tsv \
     generated/option4/missing_value_reports.tsv generated/option4/examples.yaml; then
  report option4 tsv:mvr yes
else
  report option4 tsv:mvr no
fi

rm -f "$log"
echo
if [ "$surprises" -eq 0 ]; then
  echo "every conversion behaved as expected"
else
  echo "$surprises conversion(s) did not behave as expected"
fi
exit "$surprises"
