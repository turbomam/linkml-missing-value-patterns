# Measured behavior

Everything here was run on 2026-08-31 against linkml 1.11.1 (the released version, installed
by `uv sync` from this repository's `pyproject.toml`) on macOS with Python from that venv.
Rerun it yourself with `./run_checks.sh`.

## All 23 example files behave as their names claim

`valid_*` files validate, `invalid_*` files do not, across all six schemas. That is what
`run_checks.sh` asserts, and it exits non-zero if any file disagrees with its name.

## `value_presence` rules compile to JSON Schema if/then

The rules in options 2 and 3 use `value_presence: PRESENT` and `value_presence: ABSENT`. In
the generated JSON Schema these become `allOf` entries of this shape:

```json
{
  "if":   { "not": { "required": ["depth_m"] }, "properties": { "depth_m": {} } },
  "then": { "required": ["depth_m_missing_reason"], "properties": { "depth_m_missing_reason": {} } }
}
```

This works, and it is the only way in LinkML today to say "absent here, required there".

Note the metamodel marks `value_presence` with `status: unstable`. Both options in this
repository that keep a value and a reason mutually exclusive depend on it, so if you adopt one
of them you are depending on an unstable metaslot. That is a real risk and it is stated here
rather than buried.

The sibling metaslot `inapplicable` ("true means that values for this slot must not be
present") carries no status marker, which reads as stable, and is implemented nowhere in the
LinkML codebase. It is not usable, which is why option 3 uses `value_presence: ABSENT`
instead.

## The top-level `required` list does not reflect the rules

In option 3, the generated JSON Schema lists only `sample_id` under `required`. `depth_m` and
`env_broad_scale` appear as optional, with the real constraint living in the `allOf` block.
Anything that reads `required` and stops there (a form builder, a docs page, a summary table)
will report those fields as optional. That is the main cost of option 3.

## `any_of` and `exactly_one_of` both work here, with `range: Any` declared

Option 1 uses `any_of` and option 1b uses `exactly_one_of` over the same two branches. Both
validate correctly, and neither generated JSON Schema shows the stray `"type": "string"`
reported in https://github.com/linkml/linkml/issues/2283:

```json
"depth_m": {
  "$ref": "#/$defs/Any",
  "anyOf": [ {"type": "number"}, {"$ref": "#/$defs/MissingValueReasonEnum"} ]
}
```

```json
"depth_m": {
  "$ref": "#/$defs/Any",
  "oneOf": [ {"type": "number"}, {"$ref": "#/$defs/MissingValueReasonEnum"} ]
}
```

Two things this does **not** show:

1. It does not show that issue 2283 is fixed. That report is about a union over class ranges
   in a schema that imports `linkml:types` and does not declare `range: Any`. These schemas
   declare `range: Any` explicitly, and `$defs/Any` generates as
   `"type": ["null","boolean","object","number","string"]`, which permits everything the union
   needs. Declaring the range appears to be what avoids the leak, and that is worth knowing on
   its own.
2. It does not show that `exactly_one_of` enforces exclusivity, because the two branches are
   disjoint: no value is both a number and a member of the reason value set. To tell `any_of`
   from `exactly_one_of` you would need overlapping branches, which these examples do not have.

## Terms checked against OLS on 2026-08-31

`NCIT:C48655` "Missing Value Reason" has 38 children. Used here:

| Value | Term | Verified under C48655 |
|---|---|---|
| not applicable | `NCIT:C48660` Not Applicable | yes |
| unknown | `NCIT:C157157` Indeterminate or Unknown | yes |
| not available | `NCIT:C126101` Not Available | yes |
| other | none | there is no term for it in that branch |

Rejected, and why:

- `NCIT:C17998` "Unknown" sits under `NCIT:C27993` "General Qualifier", not under Missing
  Value Reason. Using it would break the branch.
- `NCIT:C17649` "Other" sits under General Qualifier for the same reason, which is why "other"
  in this repository's value set has no `meaning:`.

The finer value set uses only verified children of `NCIT:C48655`: Not Asked `C80217`, Not Done
`C49484`, Not Recorded `C185193`, Cannot Be Assessed `C48657`, Insufficient Quantity `C177690`,
Insufficient Quality `C177691`, Response Declined `C51024`, Masked Data `C150904`, Temporarily
Unavailable `C150903`, Source Data Not Available `C67329`.

`OBI:0002199` "reason for lack of data item" was considered and not used. It has four
descendants (`OBI:0002200` cannot be assessed determination, `OBI:0002202` GX, `OBI:0002203`
pTX, `OBI:0002204` pNX) and all of them are cancer staging.

## Conversion to OWL, TSV and RDF

Run on 2026-09-14 with linkml 1.11.1 and linkml-runtime 1.11.1, using `./convert.sh`. It writes
OWL for every schema, and each option's valid examples as one YAML file, one TSV table and one
Turtle graph, all under `generated/`. The OWL 2 DL checks used ROBOT 1.9.10.

| Option | OWL (`gen-owl`) | TSV | RDF (Turtle) |
|---|---|---|---|
| 0 strict | yes | yes | yes |
| 1 union | yes, but the numeric union is lost | no | no |
| 1b union | same as option 1 | no | no |
| 2 reified | yes | yes, the value object flattens to `depth_*` columns | yes, the value node carries the reason |
| 3 sibling | yes | yes, one extra column | yes |
| 4 out-of-band | yes | yes, as two tables | yes |

Side by side, options 2 and 3 show why `meaning:` matters. The TSV writes the reason as the
label `unknown`, and the Turtle writes the same reason as the IRI `NCIT:C157157`.

### The union options validate, but do not leave YAML

Options 1 and 1b are valid under `linkml-validate`, and no standard writer can serialize them.

- **TSV** fails with `Exception: Value of depth_m = {...}, which is not a dict`.
- **Turtle** fails with `Unknown CURIE prefix: @base`. The RDF writer treats a value in a slot
  declared `range: Any` as a reference to another object.
- **JSON-LD** (`linkml-convert -t json-ld`, then parsing the file with rdflib) raises no error,
  but the RDF is wrong: `12.5` gets the datatype `mvp:@id`, and the reason strings become
  `file://` IRIs. That is the worse result, because nothing reports it.

This is the tooling version of a real constraint. In OWL 2 DL, one property cannot be both a
datatype property (a number) and an object property (a term IRI).

### What `gen-owl` does with these schemas

- **The numeric union disappears.** In option 1, `depth_m` stays an `owl:DatatypeProperty`
  with range `xsd:float`. The branch that allows a reason term is dropped, with only the log
  line `Ambiguous type for: depth_m`. ROBOT's OWL 2 DL check then reports
  `Cannot pun between properties` for `depth_m`. The union of two enums on `env_broad_scale`
  does survive, as `owl:unionOf`.
- **Rules become class axioms, but `value_presence` is ignored.** The string `value_presence`
  appears nowhere in `linkml/generators/owlgen.py` in 1.11.1.
  - Every rule condition becomes `someValuesFrom xsd:string`, whether it says `PRESENT` or
    `ABSENT` and whatever the slot's range is.
  - So option 3's two depth rules, "absent requires a reason" and "present forbids a reason",
    both come out as the same axiom:
    `Biosample and (depth_m some xsd:string) SubClassOf (depth_m_missing_reason some xsd:string)`.
    Read literally, that says a present depth requires a reason, which contradicts the schema.
  - `depth_m` is a float, so a real value never matches `xsd:string`. In practice the axiom
    constrains nothing.
  - The same axioms apply data-property syntax to object properties. That is why ROBOT reports
    punning errors in options 2 and 3.
  - Upstream searches for "owlgen rules", "gen-owl preconditions", "value_presence owl" and
    "owlgen value_presence" found no open issue.
- **An external term gains a parent.** Each permissible value with a `meaning:` becomes an
  `owl:Class` at that IRI, asserted as a subclass of the enum:
  `NCIT_C48660 rdfs:subClassOf mvp:MissingValueReasonEnum`. Merging this OWL with NCIT adds a
  parent to an NCIT term. `other` has no `meaning:`, so it gets the local IRI
  `.../MissingValueReasonEnum#other`.
- **None of the six OWL files is in the OWL 2 DL profile.** The findings common to all six are
  undeclared annotation properties (`dcterms:title`, `skos:definition`,
  `linkml:permissible_values`). Option 4 also uses `xsd:date` without declaring it. The
  punning errors above are the only findings specific to missing data.

### Two tooling problems worked around in this repository

- **Prefixes from imports are dropped.** The Python code that `linkml-convert` generates
  ignores prefixes declared only in an imported schema, and fails with
  `NameError: name 'ENVO' is not defined`. This is
  https://github.com/linkml/linkml/issues/3574 (open). Each option schema therefore repeats
  the ENVO, NCIT and SAMP prefixes.
- **Imports are resolved against the working directory.** Run from the repository root,
  `linkml-convert` fails with
  `FileNotFoundError: .../linkml-missing-value-patterns/common.yaml` for Turtle, JSON and YAML
  output alike. `linkml-validate` resolves the same import correctly from the same directory.
  Upstream searches for this found no issue. `convert.sh` runs the converter from `src/schema`.

### Why options 0 to 3 gained a `BiosampleSet` class

`linkml-convert` writes TSV only from a container class, with `--index-slot` naming the list
slot. `BiosampleSet` holds a list of samples and is otherwise unused. `run_checks.sh` still
validates each example against `Biosample` directly.
