# Every LinkML exercise in the talk runs from here, on one case: Napoleon's height.
# The records under napoleon/ are invented for illustration. A line starting with "!" is expected
# to fail, and the recipe stops if that command succeeds instead.

bin := ".venv/bin"
validate := ".venv/bin/linkml-validate"
s := "napoleon/schema"
d := "napoleon/data"
build := ".demo-build"

# List the recipes
default:
    @just --list --unsorted

# Install the pinned linkml into .venv
setup:
    uv sync

# Lint every Napoleon schema (linkml-lint with .linkmllint.yaml), validate each against the metamodel,
# and lint every YAML file under napoleon/ (yamllint with .yamllint.yaml)
lint: setup
    {{bin}}/linkml-lint --config .linkmllint.yaml napoleon/schema
    {{bin}}/linkml-lint --config .linkmllint.yaml napoleon/demos/recommended.yaml
    {{bin}}/linkml-lint --config .linkmllint.yaml napoleon/demos/ifabsent.yaml
    # Metamodel validation: with no -s, linkml-validate treats each positional file as a schema and
    # validates it against the LinkML metamodel (see linkml-validate --help, linkml 1.11.1).
    for f in napoleon/schema/*.yaml napoleon/demos/recommended.yaml napoleon/demos/ifabsent.yaml; do {{validate}} "$f" || exit 1; done
    uvx --from yamllint==1.38.0 yamllint -c .yamllint.yaml napoleon

# Fail if any record file under napoleon/data is not named in a recipe, so a new fixture cannot go unchecked
coverage:
    {{bin}}/python -c 'import pathlib,sys; j=pathlib.Path("justfile").read_text(); m=[str(f) for f in sorted(pathlib.Path("napoleon/data").glob("*/*.yaml")) if f.name.startswith(("valid_","invalid_")) and "/".join(f.parts[-2:]) not in j]; print("unchecked:", m) if m else print("every record file is named in a recipe"); sys.exit(1 if m else 0)'

# Run every pattern: each valid_* record must pass and each invalid_* record must fail
check: lint coverage strict union one-of value-object reason-column side-report not-applicable
    @echo "every record behaved as its name claims"

# strict: height_m required and a float, with no way to say why it is missing
strict: setup
    @echo "== strict"
    {{validate}} -s {{s}}/strict.yaml -C HeightRecord {{d}}/strict/valid_measured.yaml
    ! {{validate}} -s {{s}}/strict.yaml -C HeightRecord {{d}}/strict/invalid_height_omitted.yaml
    ! {{validate}} -s {{s}}/strict.yaml -C HeightRecord {{d}}/strict/invalid_feet_and_inches.yaml

# union: height_m is a float or an INSDC term (any_of); a control sample and an uncollected height both fit
union: setup
    @echo "== union"
    {{validate}} -s {{s}}/union.yaml -C HeightRecord {{d}}/union/valid_measured.yaml
    {{validate}} -s {{s}}/union.yaml -C HeightRecord {{d}}/union/valid_control_sample.yaml
    {{validate}} -s {{s}}/union.yaml -C HeightRecord {{d}}/union/valid_not_collected.yaml
    ! {{validate}} -s {{s}}/union.yaml -C HeightRecord {{d}}/union/invalid_made_up_reason.yaml
    ! {{validate}} -s {{s}}/union.yaml -C HeightRecord {{d}}/union/invalid_height_omitted.yaml

# one-of: the same union written with exactly_one_of
one-of: setup
    @echo "== one-of"
    {{validate}} -s {{s}}/one_of.yaml -C HeightRecord {{d}}/one_of/valid_measured.yaml
    {{validate}} -s {{s}}/one_of.yaml -C HeightRecord {{d}}/one_of/valid_human_identifiable.yaml
    ! {{validate}} -s {{s}}/one_of.yaml -C HeightRecord {{d}}/one_of/invalid_made_up_reason.yaml

# value-object: height is an object holding a number or a reason, never both or neither
value-object: setup
    @echo "== value-object"
    {{validate}} -s {{s}}/value_object.yaml -C HeightRecord {{d}}/value_object/valid_measured.yaml
    {{validate}} -s {{s}}/value_object.yaml -C HeightRecord {{d}}/value_object/valid_third_party.yaml
    ! {{validate}} -s {{s}}/value_object.yaml -C HeightRecord {{d}}/value_object/invalid_both.yaml
    ! {{validate}} -s {{s}}/value_object.yaml -C HeightRecord {{d}}/value_object/invalid_neither.yaml
    ! {{validate}} -s {{s}}/value_object.yaml -C HeightRecord {{d}}/value_object/invalid_height_omitted.yaml

# reason-column: optional height_m plus height_m_missing_reason, including "asked, answer unknown" and "asked, declined"
reason-column: setup
    @echo "== reason-column"
    {{validate}} -s {{s}}/reason_column.yaml -C HeightRecord {{d}}/reason_column/valid_measured.yaml
    {{validate}} -s {{s}}/reason_column.yaml -C HeightRecord {{d}}/reason_column/valid_answer_unknown.yaml
    {{validate}} -s {{s}}/reason_column.yaml -C HeightRecord {{d}}/reason_column/valid_declined.yaml
    ! {{validate}} -s {{s}}/reason_column.yaml -C HeightRecord {{d}}/reason_column/invalid_both.yaml
    ! {{validate}} -s {{s}}/reason_column.yaml -C HeightRecord {{d}}/reason_column/invalid_neither.yaml

# side-report: records stay plain; a separate report says a value was lost in transit or is in process
side-report: setup
    @echo "== side-report"
    {{validate}} -s {{s}}/side_report.yaml -C Archive {{d}}/side_report/valid_lost_in_transit.yaml
    {{validate}} -s {{s}}/side_report.yaml -C Archive {{d}}/side_report/valid_in_process.yaml
    ! {{validate}} -s {{s}}/side_report.yaml -C Archive {{d}}/side_report/invalid_made_up_reason.yaml

# not-applicable: the schema forbids height_m on a hair-lock record (value_presence ABSENT)
not-applicable: setup
    @echo "== not-applicable"
    {{validate}} -s {{s}}/not_applicable.yaml -C HairLockRecord {{d}}/not_applicable/valid_hair_lock.yaml
    ! {{validate}} -s {{s}}/not_applicable.yaml -C HairLockRecord {{d}}/not_applicable/invalid_hair_lock_with_height.yaml

# recommended: a missing recommended slot is silent by default, a warning with RecommendedSlotsPlugin
recommended: setup
    @echo "== default validator: nothing reported"
    {{validate}} -s napoleon/demos/recommended.yaml -C HeightRecord napoleon/demos/no_source_type.yaml
    @echo "== with RecommendedSlotsPlugin: a warning"
    {{validate}} --config napoleon/demos/recommended_config.yaml napoleon/demos/no_source_type.yaml

# ifabsent: generated Pydantic fills the default unit; validation and JSON Schema do not
ifabsent: setup
    mkdir -p {{build}}
    @echo "== linkml-validate accepts the record and fills nothing"
    {{validate}} -s napoleon/demos/ifabsent.yaml -C HeightMeasurement napoleon/demos/no_unit.yaml
    @echo "== JSON Schema has no default for has_unit"
    {{bin}}/gen-json-schema napoleon/demos/ifabsent.yaml | {{bin}}/python -c 'import json,sys; print(json.load(sys.stdin)["$defs"]["HeightMeasurement"]["properties"]["has_unit"])'
    @echo "== a generated Pydantic HeightMeasurement built without has_unit gets m"
    {{bin}}/gen-pydantic napoleon/demos/ifabsent.yaml > {{build}}/ifabsent_model.py
    {{bin}}/python -c 'import sys, yaml; sys.path.insert(0, "{{build}}"); from ifabsent_model import HeightMeasurement; print(HeightMeasurement(**yaml.safe_load(open("napoleon/demos/no_unit.yaml"))))'

# open-world: HermiT accepts a missing required height; SHACL and LinkML refuse it
open-world: setup
    mkdir -p {{build}}
    @echo "== HermiT: a required height that is missing is consistent"
    robot reason --reasoner HermiT --input napoleon/demos/open_world/required_height.ofn --output {{build}}/required_height.ofn
    @echo "== HermiT: a height on a hair lock is inconsistent (expected to fail)"
    ! robot reason --reasoner HermiT --input napoleon/demos/open_world/forbidden_height.ofn --output {{build}}/forbidden_height.ofn
    @echo "== SHACL sh:minCount 1: the same missing height does not conform (expected to fail)"
    ! uvx --from pyshacl==0.40.1 pyshacl -s napoleon/demos/open_world/shapes.ttl napoleon/demos/open_world/data.ttl
    @echo "== LinkML required: the same missing height fails (expected to fail)"
    ! {{validate}} -s {{s}}/strict.yaml -C HeightRecord {{d}}/strict/invalid_height_omitted.yaml

# float-type: what height_m, a LinkML float, becomes in the metamodel and five generated artifacts
float-type: setup
    @echo "== linkml:types float"
    {{bin}}/python -c 'from linkml_runtime.utils.schemaview import SchemaView; t = SchemaView("{{s}}/strict.yaml").get_type("float"); print("uri:", t.uri, "| base:", t.base, "| exact_mappings:", t.exact_mappings)'
    @echo "== JSON Schema"
    {{bin}}/gen-json-schema {{s}}/strict.yaml | {{bin}}/python -c 'import json,sys; print(json.load(sys.stdin)["$defs"]["HeightRecord"]["properties"]["height_m"])'
    @echo "== OWL"
    {{bin}}/gen-owl {{s}}/strict.yaml 2>/dev/null | grep -A2 '^nap:height_m a'
    @echo "== SHACL"
    {{bin}}/gen-shacl {{s}}/strict.yaml 2>/dev/null | grep -B6 'sh:path nap:height_m' | grep -E 'sh:datatype|sh:minCount|sh:path'
    @echo "== Pydantic"
    {{bin}}/gen-pydantic {{s}}/strict.yaml 2>/dev/null | grep -E '^ +height_m:' | cut -c1-60
    @echo "== SQL DDL"
    {{bin}}/gen-sqlddl {{s}}/strict.yaml 2>/dev/null | grep -i '^.*height_m [A-Z]'

# tables: the same records as TSV and Turtle; the union cannot be written as either
tables: setup
    mkdir -p {{build}}/tables
    @echo "== reason-column as TSV, then Turtle"
    cd {{s}} && ../../{{bin}}/linkml-convert -s reason_column.yaml -C HeightRecordSet --index-slot records -t tsv -o ../../{{build}}/tables/reason_column.tsv ../data/reason_column/all_valid_records.yaml && cat ../../{{build}}/tables/reason_column.tsv
    cd {{s}} && ../../{{bin}}/linkml-convert -s reason_column.yaml -C HeightRecordSet --index-slot records -t ttl -o ../../{{build}}/tables/reason_column.ttl ../data/reason_column/all_valid_records.yaml && grep -v '^@prefix' ../../{{build}}/tables/reason_column.ttl
    @echo "== value-object as TSV"
    cd {{s}} && ../../{{bin}}/linkml-convert -s value_object.yaml -C HeightRecordSet --index-slot records -t tsv -o ../../{{build}}/tables/value_object.tsv ../data/value_object/all_valid_records.yaml && cat ../../{{build}}/tables/value_object.tsv
    @echo "== side-report as two tables: records, then reports"
    cd {{s}} && ../../{{bin}}/linkml-convert -s side_report.yaml -C Archive --index-slot records -t tsv -o ../../{{build}}/tables/side_report_records.tsv ../data/side_report/valid_lost_in_transit.yaml && cat ../../{{build}}/tables/side_report_records.tsv
    cd {{s}} && ../../{{bin}}/linkml-convert -s side_report.yaml -C Archive --index-slot missing_value_reports -t tsv -o ../../{{build}}/tables/side_report_reports.tsv ../data/side_report/valid_lost_in_transit.yaml && cat ../../{{build}}/tables/side_report_reports.tsv
    @echo "== union as TSV and as Turtle (both expected to fail)"
    ! {{bin}}/python -c 'import subprocess,sys; r=subprocess.run(["../../{{bin}}/linkml-convert","-s","union.yaml","-C","HeightRecordSet","--index-slot","records","-t","tsv","-o","/dev/null","../data/union/all_valid_records.yaml"],cwd="{{s}}",capture_output=True,text=True); print([l for l in r.stderr.splitlines() if "Exception" in l or "Error" in l][-1:]); sys.exit(r.returncode)'
    ! {{bin}}/python -c 'import subprocess,sys; r=subprocess.run(["../../{{bin}}/linkml-convert","-s","union.yaml","-C","HeightRecordSet","--index-slot","records","-t","ttl","../data/union/all_valid_records.yaml"],cwd="{{s}}",capture_output=True,text=True); print([l for l in r.stderr.splitlines() if "Error" in l][-1:]); sys.exit(r.returncode)'

# rdf: Napoleon's height in OBO terms; each query finds its pattern, and HermiT checks every merged file
rdf: setup
    {{bin}}/python rdf-examples/run_queries.py --merged-dir {{build}}/rdf-merged
    @echo "== HermiT: these merged patterns are consistent"
    for p in p00_complete p01_nothing_asserted p03_reason_as_term p04_value_node_without_value p05_failed_assay p06_not_applicable p07_restricted_access p08_bounded_value p09_lost_in_transit p10_negation p11_unknown_but_exists p12_asked_unknown; do robot reason --reasoner HermiT --input {{build}}/rdf-merged/merged_$p.ttl --output {{build}}/rdf-merged/$p.ofn || exit 1; echo "consistent: $p"; done
    @echo "== HermiT: these are inconsistent on purpose (each line is expected to fail)"
    ! robot reason --reasoner HermiT --input {{build}}/rdf-merged/merged_p02_sentinel_literal.ttl --output {{build}}/rdf-merged/p02.ofn
    ! robot reason --reasoner HermiT --input {{build}}/rdf-merged/merged_p05_failed_assay_contradiction.ttl --output {{build}}/rdf-merged/p05c.ofn
    ! robot reason --reasoner HermiT --input {{build}}/rdf-merged/merged_p06_not_applicable_contradiction.ttl --output {{build}}/rdf-merged/p06c.ofn
    ! robot reason --reasoner HermiT --input {{build}}/rdf-merged/merged_p10_negation_contradiction.ttl --output {{build}}/rdf-merged/p10c.ofn

# rdf-matrix: every RDF query against every pattern file; the diagonal must match, off-diagonal hits are listed
rdf-matrix: setup
    {{bin}}/python rdf-examples/query_matrix.py

# rdf-outcomes: one query finds every outcome of trying to record the height, in every pattern file
rdf-outcomes: setup
    {{bin}}/python rdf-examples/outcomes.py

# linkml-matrix: every Napoleon record against every Napoleon schema; writes napoleon/MATRIX.md
linkml-matrix: setup
    {{bin}}/python napoleon/matrix.py

# Rebuild generated/ for the original depth examples under src/ (pull request 2)
convert: setup
    ./convert.sh

# Run every exercise except convert, which rewrites committed generated/ files (their OWL text order changes)
all: check recommended ifabsent open-world float-type tables rdf rdf-matrix rdf-outcomes linkml-matrix

# Render the Marp slide deck to HTML next to its source (needs Node; npx fetches marp-cli)
slides:
    npx -y @marp-team/marp-cli@4.5.1 --no-stdin slides/obi-2026-09-14.md -o slides/obi-2026-09-14.html
