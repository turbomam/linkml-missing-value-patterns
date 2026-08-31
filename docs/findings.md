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
