#!/usr/bin/env bash
# Write every schema as OWL, gather each option's valid examples into one YAML file, and convert
# that file to TSV and Turtle wherever the conversion works (docs/findings.md lists which), using
# only the standard LinkML command line tools.
# Everything is written under generated/, which this script deletes and rebuilds.
#
# Some options do not survive conversion, and that is a finding rather than a bug in this
# script (see docs/findings.md). Those failures are expected and reported. The script exits
# non-zero if a conversion fails that was expected to work, succeeds when it was expected to
# fail, or fails for a reason other than the documented one, so the TSV and Turtle findings
# cannot go stale silently. The JSON-LD finding in docs/findings.md is not rechecked here.
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

# The union options put a number and a term IRI in the same slot. Neither the TSV nor the Turtle
# writer in linkml 1.11.1 can serialize that; see docs/findings.md. Each expected failure is
# recognized by the text of its final exception, so a different failure in the same conversion
# still counts.
expected_failure() {
  case "$1:$2" in
    option1:tsv|option1b:tsv) echo "which is not a dict" ;;
    option1:ttl|option1b:ttl) echo "Unknown CURIE prefix: @base" ;;
    *) echo "" ;;
  esac
}

rm -rf generated
mkdir -p generated/owl
log=$(mktemp)
surprises=0

report() {  # option, output, succeeded (yes/no)
  local signature final actual=ok note=""
  signature=$(expected_failure "$1" "$2")
  [ "$3" = yes ] || actual=fail
  # The terminal exception is the last Error or Exception line; only that line is compared.
  final=$(grep -E 'Error|Exception' "$log" | tail -1)
  if [ -n "$signature" ]; then
    if [ "$actual" = ok ]; then
      note="UNEXPECTED: expected a failure containing '$signature'"
      surprises=$((surprises+1))
    elif ! printf '%s\n' "$final" | grep -qF "$signature"; then
      note="UNEXPECTED: final error lacks '$signature'"
      surprises=$((surprises+1))
    fi
  elif [ "$actual" = fail ]; then
    note="UNEXPECTED"
    surprises=$((surprises+1))
  fi
  if [ "$actual" = fail ]; then
    note="$note $(printf '%s\n' "$final" | cut -c1-90)"
  fi
  printf '%-9s %-7s %-6s %s\n' "$1" "$2" "$actual" "$note"
}

convert() {  # schema, container class, index slot, format, output, input
  # Run from the schema directory. When writing TSV or RDF, linkml-convert resolves
  # "imports: [common]" against the working directory rather than the schema's own directory.
  local root
  root=$(pwd)
  (cd "$(dirname "$1")" && "$root/$BIN/linkml-convert" -s "$(basename "$1")" -C "$2" \
     --index-slot "$3" -t "$4" -o "$root/$5" "$root/$6") > "$log" 2>&1
}

printf '%-9s %-7s %-6s %s\n' OPTION OUTPUT RESULT NOTE
printf '%.0s-' $(seq 1 78); echo

for opt in option0 option1 option1b option2 option3 option4; do
  schema=$(schema_for "$opt")
  out=generated/$opt
  owl="generated/owl/$(basename "$schema" .yaml).owl.ttl"
  mkdir -p "$out"

  if "$BIN/gen-owl" "$schema" > "$owl" 2> "$log"; then
    report "$opt" owl yes
  else
    rm -f "$owl"
    report "$opt" owl no
  fi

  # Gather the valid examples into one container document, so they become one table and one graph.
  if ! "$BIN/python" - "$opt" "$out/examples.yaml" > "$log" 2>&1 <<'EOF'
import pathlib, sys, yaml
opt, target = sys.argv[1], pathlib.Path(sys.argv[2])
merged = {}
for f in sorted(pathlib.Path("data", opt).glob("valid_*.yaml")):
    doc = yaml.safe_load(f.read_text())
    parts = doc if "samples" in doc else {"samples": [doc]}
    for key, items in parts.items():
        merged.setdefault(key, []).extend(items)
if not merged:
    sys.exit(f"no valid_*.yaml files under data/{opt}")
target.write_text(yaml.safe_dump(merged, sort_keys=False, allow_unicode=True))
EOF
  then
    rm -f "$out/examples.yaml"
    report "$opt" yaml no
    continue
  fi

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
if [ -f generated/option4/examples.yaml ] && convert "$(schema_for option4)" Dataset missing_value_reports tsv \
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
