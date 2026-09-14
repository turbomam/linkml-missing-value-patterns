# LinkML options for "mandatory, strongly typed, and sometimes legitimately absent"

A slot you really want to be mandatory and strongly typed, plus a way for a submitter to say
"we are not providing this, and here is the reason". Those two wishes pull against each other,
and LinkML has no single metaslot that grants both.

This repository holds six schemas that grant them in different ways, with example data for
each and a script that checks every example actually behaves the way its filename claims.

It exists because two communities are working on the same question from opposite ends. On the
LinkML side, https://github.com/orgs/linkml/discussions/3813 asks whether a `required` slot may
hold a null. On the OBO side, OBI has `OBI:0002199` "reason for lack of data item" and a long
running discussion at https://github.com/obi-ontology/obi/issues/1230 about what it means for an
assay to produce no datum. `docs/crosswalk.md` connects the two: which cause of absence lands in
which option, what each one maps to in INSDC and NCIT, and where OBO has no term yet.

> **For the 2026-09-14 OBI call:** the talk's exercises use one case, Napoleon's height, under
> `napoleon/`, and every one runs from the justfile (`just --list`). The deck is
> `slides/obi-2026-09-14.md`; the RDF examples are in `rdf-examples/`. The `src/` and `data/`
> folders below hold the original depth examples.

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
slot and mapped to no ontology term, so nothing enforces or resolves it. Checked 2026-09-02
against MIxS at commit `6a2a6ed`, which is after the v7.0.1 tag: `InsdcMissingValueEnum` appears
once in `src/mixs/schema/mixs.yaml`, at its own definition on line 47, and none of its 13
permissible values carries a `meaning:`.

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
just check      # or one pattern at a time: just strict, just union, just one-of, just value-object,
                #   just reason-column, just side-report, just not-applicable
```

Each pattern recipe validates that pattern's records under `napoleon/data/` against its schema in
`napoleon/schema/`. A `valid_*` record must pass, and an `invalid_*` record is run with `!` so the
recipe stops if it passes. `just check` runs all seven, after `just coverage` confirms every record
file under `napoleon/data/` is named in a recipe.

All 26 Napoleon records behaved as their names claim when `just check` last ran, on 2026-09-14
against linkml 1.11.1. The original depth examples under `data/` are covered by `just convert`. Every measured claim in this repository comes from that version, and `uv.lock`
is committed so you get the same one. If you reproduce against a different release and get a
different answer, that difference is worth reporting.

## The same data as OWL, TSV and RDF

```bash
just convert    # or: uv sync && ./convert.sh
```

This writes OWL for every option schema and gathers each option's valid examples into one YAML file
under `generated/`, then converts that file to TSV and Turtle wherever the conversion works.
The table in `docs/findings.md` lists exactly which files each option gets. It uses only the standard LinkML tools
(`gen-owl`, `linkml-convert`).

The union options (1 and 1b) validate, but cannot be written as TSV or Turtle with linkml
1.11.1, and JSON-LD writes RDF for them that is wrong without reporting an error. The script
expects the TSV and Turtle failures, and exits non-zero if either stops happening or fails for
a different reason.
`docs/findings.md` also covers what `gen-owl` does to the rules and to the union.

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

## What I would like feedback on

- Should a required-but-nullable slot also be able to carry a reason for the null, or are those
  two separate problems?
- `value_presence` is marked `status: unstable` in the metamodel, and options 2 and 3 both
  depend on it. Is it safe to build on?
- Is `other` a missing-value reason at all, or a value-set coverage problem?
- Where does a value that was lost in transit belong: a validation report, provenance, or
  neither?

Issues and pull requests are welcome, and so is being told I have overcomplicated this.
