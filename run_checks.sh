#!/usr/bin/env bash
# Validate every data file against its option's schema and compare the outcome with the
# expectation encoded in the filename: valid_* must pass, invalid_* must fail.
# Exits non-zero if any file behaves differently from its name.
# Written for bash 3.2, which is what macOS ships, so no associative arrays.

set -uo pipefail
cd "$(dirname "$0")"

VALIDATE="./.venv/bin/linkml-validate"
[ -x "$VALIDATE" ] || { echo "no linkml-validate at $VALIDATE; run: uv sync"; exit 2; }

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

target_for() {
  case "$1" in
    option4) echo Dataset ;;
    *)       echo Biosample ;;
  esac
}

fails=0
printf '%-42s %-9s %-7s %s\n' FILE EXPECTED ACTUAL RESULT
printf '%.0s-' $(seq 1 78); echo

for opt in option0 option1 option1b option2 option3 option4; do
  for f in data/$opt/*.yaml; do
    base=$(basename "$f")
    case "$base" in
      valid_*)   expected=pass ;;
      invalid_*) expected=fail ;;
      *)         echo "unnamed expectation: $f"; fails=$((fails+1)); continue ;;
    esac
    if out=$("$VALIDATE" -s "$(schema_for "$opt")" -C "$(target_for "$opt")" "$f" 2>&1); then
      actual=pass
    else
      actual=fail
    fi
    if [ "$expected" = "$actual" ]; then
      result=ok
    else
      result=MISMATCH
      fails=$((fails+1))
    fi
    printf '%-42s %-9s %-7s %s\n' "$opt/$base" "$expected" "$actual" "$result"
    if [ "$result" = MISMATCH ]; then
      echo "$out" | sed 's/^/      /' | head -8
    fi
  done
done

echo
if [ "$fails" -eq 0 ]; then
  echo "all files behaved as their names claim"
else
  echo "$fails file(s) did not behave as their names claim"
fi
exit "$fails"
