# LinkML options for "mandatory, strongly typed, and sometimes legitimately absent"

A slot you really want to be mandatory and strongly typed, plus a way for a submitter to say
"we are not providing this, and here is the reason". Those two wishes pull against each other,
and LinkML has no single metaslot that grants both.

This repository holds six schemas that grant them in different ways, with example data for
each and a script that checks every example actually behaves the way its filename claims.

## The problem

A schema author marks `depth_m` as `required: true` with `range: float`. A submitter has a
negative control sample collected in a lab, where depth does not apply. They have three moves:

1. Omit the record. The sample disappears from the dataset.
2. Put a code in the field: `depth_m: not collected`. It fails validation, or worse, the range
   was `string` and it passes and poisons every downstream consumer.
3. Leave it blank and hope. Now nobody can tell "not applicable" from "we forgot".

INSDC standardised a vocabulary for the third problem
(https://www.insdc.org/technical-specifications/missing-value-reporting/) and MIxS carries it
as `InsdcMissingValueEnum`, but in the MIxS source schema that value set is referenced by no
slot and mapped to no ontology term, so nothing enforces or resolves it.

## The options

| Option | Shape | Slot stays required | Strong range survives | Flat table survives |
|---|---|---|---|---|
| 0 strict | `required: true`, no escape hatch | yes | yes | yes |
| 1 union | `any_of: [real range, reason value set]` | yes | no | yes |
| 1b union | same with `exactly_one_of` | yes | no | yes |
| 2 reified | value object holding a value or a reason | yes | yes | no |
| 3 sibling | optional value plus a reason slot, tied by rules | no, rules do it | yes | yes, one extra column |
| 4 out-of-band | absence recorded in a separate report object | no | yes | yes |

Option 0 is the baseline that shows why the others exist.

Only option 2 keeps the slot required and the range strong at the same time. It pays for that
by nesting every value in an object, which is the same trade NMDC's `QuantityValue` already
makes for units.

Option 4 is the only one that can record a cause the others cannot express: a value that
existed, was submitted, and was lost in transit through a mapping with no target slot or a
failed conversion. That is a fact about the pipeline rather than about the sample, and it does
not belong in the sample record. It is also the weakest, because a LinkML rule cannot reach
across objects, so the pairing has to be checked by code.

## Reasons, and where they point

Both value sets live in `src/schema/common.yaml`.

`MissingValueReasonEnum` has four values: `not applicable`, `unknown`, `not available`,
`other`. Three of them carry a `meaning:` pointing at a child of `NCIT:C48655` "Missing Value
Reason". `other` does not, because that branch has no term for it.

`DetailedMissingValueReasonEnum` has ten finer values, every one a verified child of
`NCIT:C48655`.

Adding `meaning:` values is the cheap half of this whole problem and it is what lets a plain
string in a submitted spreadsheet become a resolvable IRI in an RDF graph without changing
anything the submitter sees.

An OBO-side hierarchy for incomplete data records is under discussion as of 2026-08. When it
lands, the `meaning:` values here are the only thing that needs to change.

## Running it

```bash
uv sync
./run_checks.sh
```

`run_checks.sh` validates every file under `data/` against its option's schema and compares
the result with the expectation in the filename: `valid_*` must pass, `invalid_*` must fail.
It exits non-zero on any disagreement.

## What was measured, not assumed

`docs/findings.md` records what actually happens, including the things that surprised me: how
`value_presence` rules compile into JSON Schema `if`/`then`, why the generated `required` list
under-reports option 3's constraints, and why both `any_of` and `exactly_one_of` work here when
https://github.com/linkml/linkml/issues/2283 reports that the latter does not. It also lists
the NCIT terms that were checked and the two that were rejected, with the reason.

## Background

- https://github.com/linkml/linkml/issues/178 Metadata about a slot's value - Not Applicable;
  Missing; etc. Open since 2021. The union sketch in option 1 comes from this thread.
- https://github.com/linkml/linkml/issues/1994 Dealing with missing data. Open since 2024.
  The `NA` token problem in CSV.
- https://github.com/linkml/linkml/issues/2283 exactly_one_of with range: does not work as
  expected when using linkml:types.
- https://github.com/obi-ontology/obi/issues/1230 Provide patterns for relating absence of
  actionable data with assay "successfulness". The same question from the process side: if the
  assay produced no datum, did the assay happen.
