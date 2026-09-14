# Entry points for this repository. Every example is exercised here directly.
# A line starting with "!" is expected to fail: the recipe stops if that command succeeds.

bin := ".venv/bin"
validate := ".venv/bin/linkml-validate"
build := ".demo-build"

# List the recipes
default:
    @just --list --unsorted

# Install the pinned linkml into .venv
setup:
    uv sync

# Validate every example: each valid_* file must pass and each invalid_* file must fail
check: option0 option1 option1b option2 option3 option4
    @echo "all examples behaved as their names claim"

# Option 0, strict: depth_m and env_broad_scale required, no way to give a reason
option0: setup
    @echo "== option 0: strict, no escape hatch"
    {{validate}} -s src/schema/option0_strict.yaml -C Biosample data/option0/valid_complete.yaml
    ! {{validate}} -s src/schema/option0_strict.yaml -C Biosample data/option0/invalid_depth_omitted.yaml
    ! {{validate}} -s src/schema/option0_strict.yaml -C Biosample data/option0/invalid_sentinel_smuggled.yaml

# Option 1, union: the slot takes its real range or a reason from MissingValueReasonEnum (any_of)
option1: setup
    @echo "== option 1: any_of real range or reason"
    {{validate}} -s src/schema/option1_union.yaml -C Biosample data/option1/valid_real_values.yaml
    {{validate}} -s src/schema/option1_union.yaml -C Biosample data/option1/valid_depth_reason.yaml
    {{validate}} -s src/schema/option1_union.yaml -C Biosample data/option1/valid_env_reason.yaml
    ! {{validate}} -s src/schema/option1_union.yaml -C Biosample data/option1/invalid_bogus_reason.yaml
    ! {{validate}} -s src/schema/option1_union.yaml -C Biosample data/option1/invalid_depth_omitted.yaml

# Option 1b, union written with exactly_one_of instead of any_of
option1b: setup
    @echo "== option 1b: exactly_one_of real range or reason"
    {{validate}} -s src/schema/option1b_exactly_one_of.yaml -C Biosample data/option1b/valid_real_values.yaml
    {{validate}} -s src/schema/option1b_exactly_one_of.yaml -C Biosample data/option1b/valid_depth_reason.yaml
    ! {{validate}} -s src/schema/option1b_exactly_one_of.yaml -C Biosample data/option1b/invalid_bogus_reason.yaml

# Option 2, value object: depth is an object holding a number or a reason, never both or neither
option2: setup
    @echo "== option 2: value object with a value or a reason"
    {{validate}} -s src/schema/option2_reified.yaml -C Biosample data/option2/valid_measured.yaml
    {{validate}} -s src/schema/option2_reified.yaml -C Biosample data/option2/valid_reason.yaml
    ! {{validate}} -s src/schema/option2_reified.yaml -C Biosample data/option2/invalid_both.yaml
    ! {{validate}} -s src/schema/option2_reified.yaml -C Biosample data/option2/invalid_neither.yaml
    ! {{validate}} -s src/schema/option2_reified.yaml -C Biosample data/option2/invalid_depth_omitted.yaml

# Option 3, sibling column: optional depth_m plus depth_m_missing_reason, tied together by rules
option3: setup
    @echo "== option 3: sibling reason slot enforced by rules"
    {{validate}} -s src/schema/option3_sibling.yaml -C Biosample data/option3/valid_measured.yaml
    {{validate}} -s src/schema/option3_sibling.yaml -C Biosample data/option3/valid_reason.yaml
    ! {{validate}} -s src/schema/option3_sibling.yaml -C Biosample data/option3/invalid_both.yaml
    ! {{validate}} -s src/schema/option3_sibling.yaml -C Biosample data/option3/invalid_neither.yaml

# Option 4, out of band: the sample stays plain and a separate MissingValueReport says why
option4: setup
    @echo "== option 4: separate missing-value report"
    {{validate}} -s src/schema/option4_out_of_band.yaml -C Dataset data/option4/valid_with_report.yaml
    {{validate}} -s src/schema/option4_out_of_band.yaml -C Dataset data/option4/valid_pipeline_loss.yaml
    ! {{validate}} -s src/schema/option4_out_of_band.yaml -C Dataset data/option4/invalid_bogus_reason.yaml

# A missing recommended slot: silent by default, a warning with RecommendedSlotsPlugin
recommended: setup
    @echo "== default validator: nothing reported"
    {{validate}} -s demos/recommended/schema.yaml -C Biosample demos/recommended/no_depth.yaml
    @echo "== with RecommendedSlotsPlugin: a warning"
    {{validate}} --config demos/recommended/config.yaml demos/recommended/no_depth.yaml

# ifabsent: generated Pydantic classes fill the default; validation and JSON Schema do not
ifabsent: setup
    mkdir -p {{build}}
    @echo "== linkml-validate accepts the file and fills nothing"
    {{validate}} -s demos/ifabsent/schema.yaml -C Biosample demos/ifabsent/no_unit.yaml
    @echo "== the generated JSON Schema has no default for depth_unit"
    {{bin}}/gen-json-schema demos/ifabsent/schema.yaml | {{bin}}/python -c 'import json,sys; print(json.load(sys.stdin)["$defs"]["Biosample"]["properties"]["depth_unit"])'
    @echo "== a generated Pydantic Biosample created without depth_unit gets the default"
    {{bin}}/gen-pydantic demos/ifabsent/schema.yaml > {{build}}/ifabsent_model.py
    {{bin}}/python -c 'import sys, yaml; sys.path.insert(0, "{{build}}"); from ifabsent_model import Biosample; print(Biosample(**yaml.safe_load(open("demos/ifabsent/no_unit.yaml"))))'

# OWL reasoning accepts a missing required value; SHACL and LinkML validation reject it
open-world: setup
    mkdir -p {{build}}
    @echo "== HermiT: a required depth that is missing is consistent"
    robot reason --reasoner HermiT --input demos/open-world/required_depth.ofn --output {{build}}/required_depth.reasoned.ofn
    @echo "== HermiT: a depth that is forbidden but present is inconsistent (expected to fail)"
    ! robot reason --reasoner HermiT --input demos/open-world/forbidden_depth.ofn --output {{build}}/forbidden_depth.reasoned.ofn
    @echo "== SHACL sh:minCount 1: the same missing depth does not conform (expected to fail)"
    ! uvx --from pyshacl==0.40.1 pyshacl -s demos/open-world/shapes.ttl demos/open-world/data.ttl
    @echo "== LinkML required: the same missing depth fails (expected to fail)"
    ! {{validate}} -s src/schema/option0_strict.yaml -C Biosample data/option0/invalid_depth_omitted.yaml

# What the LinkML float type becomes: the metamodel entry, then depth_m in five generated artifacts
float-type: setup
    @echo "== linkml:types float"
    {{bin}}/python -c 'from linkml_runtime.utils.schemaview import SchemaView; t = SchemaView("src/schema/option0_strict.yaml").get_type("float"); print("uri:", t.uri, "| base:", t.base, "| exact_mappings:", t.exact_mappings)'
    @echo "== JSON Schema"
    {{bin}}/gen-json-schema src/schema/option0_strict.yaml | {{bin}}/python -c 'import json,sys; print(json.load(sys.stdin)["$defs"]["Biosample"]["properties"]["depth_m"])'
    @echo "== OWL"
    {{bin}}/gen-owl src/schema/option0_strict.yaml 2>/dev/null | grep -A3 '^mvp:depth_m a'
    @echo "== SHACL"
    {{bin}}/gen-shacl src/schema/option0_strict.yaml 2>/dev/null | grep -B6 'sh:path mvp:depth_m' | grep -E 'sh:datatype|sh:minCount|sh:path'
    @echo "== Pydantic"
    {{bin}}/gen-pydantic src/schema/option0_strict.yaml 2>/dev/null | grep -E '^ +depth_m:'
    @echo "== SQL DDL"
    {{bin}}/gen-sqlddl src/schema/option0_strict.yaml 2>/dev/null | grep -i 'depth_m'

# Rebuild generated/: OWL for every option schema, each option's examples as YAML, and TSV and Turtle where conversion works
convert: setup
    ./convert.sh

# Run every demonstration, then rebuild generated/
all: check recommended ifabsent open-world float-type convert

# Render the Marp slide deck to HTML next to its source (needs Node; npx fetches marp-cli)
slides:
    npx -y @marp-team/marp-cli@4.5.1 --no-stdin slides/obi-2026-09-14.md -o slides/obi-2026-09-14.html
