# Crosswalk: cause, terminus, option, and what a consumer can tell

`README.md` lists six ways to keep a slot required and strongly typed while letting a
submitter declare a reason for absence. This file connects those options to two other things:
the causes that put a value out of reach in the first place, and the vocabularies that already
exist for naming them.

It is written for a reader deciding which option to adopt. The last column is the one that
should drive that decision, because it says what a downstream consumer can still work out
after the data has been merged, joined, or converted to RDF.

## Why absence needs a crosswalk at all

In a LinkML dataset the default result of a missing value is that the key is not there. In an
RDF graph the default result is that no triple is written. Neither one distinguishes "does not
apply" from "was never measured" from "we have it but cannot share it". The two stacks lose
the same information for opposite reasons: open-world RDF cannot conclude anything from
absence, and a closed-world dataset concludes only that the field is empty.

The repair in both is the same. Promote the absence into something asserted.

## The causes, and where each one should land

Eight causes, walked forward to the form the record actually takes.

| Cause | Example | Terminus | Option that produces it | What a consumer can tell |
|---|---|---|---|---|
| a. Does not apply | Sampling depth of a synthetic construct | key absent, plus a statement in the schema | 3, via `value_presence: ABSENT` | That the schema forbids it here, if they read the schema |
| b. Never attempted | Legacy sample, depth not recorded at collection | reason value carrying a `meaning:` | 1, 1b, 2, 3 | That no value was ever determined |
| c. Attempted and failed | Assay ran, produced no datum | a failed-process record, no value at all | outside this repository, see below | That the process ran, if the process is modeled |
| d. Below detection or out of range | "<0.05" recorded as an empty cell | a bounded value, not a missing one | none here; use min/max numeric value | That a value exists and where it sits |
| e. Collected but withheld | Depth that would identify a protected site | reason value carrying a `meaning:` | 1, 1b, 2, 3 | That a value exists and is not available |
| f. Lost in transit | Column dropped by an ingest step, failed unit conversion | a separate record about the pipeline | 4 | That the dataset is at fault, not the sample |
| g. Not yet | A value that may arrive later | reason value carrying a `meaning:` | 1, 1b, 2, 3 | That the record is worth revisiting |
| h. The entity does not exist | A missing row, not a missing field | completeness reporting | 4 | That something was expected and is not there |

Three of these are worth spelling out.

**Cause a is a schema fact, not a data fact.** Writing `not applicable` into the data of every
synthetic construct records the same statement once per row, and it records it in the place
where a consumer is least likely to look. Option 3 puts it in the schema. LinkML has a
metaslot named `inapplicable` that reads as the right tool for this, but it is implemented
nowhere in the codebase, so option 3 uses a `value_presence: ABSENT` rule instead. See
`findings.md`.

**Cause d is not missingness.** A value below the detection limit is a bounded value, and an
empty cell is the most common silent corruption in this space. This repository does not model
it, because the fix is a range rather than a reason.

**Cause f has no home in the sample record.** A value that existed, was submitted, and was
lost in a mapping with no target slot is a fact about the pipeline. Option 4 is the only one
here that can say so, and it is the weakest of the six, because a LinkML rule cannot reach
across objects and so the pairing has to be checked by code.

## The reasons, and what they map to today

`MissingValueReasonEnum` in `src/schema/common.yaml` carries four coarse values.
`DetailedMissingValueReasonEnum` carries ten finer ones. This is where they point.

| Reason | INSDC token | NCIT | OBO term today |
|---|---|---|---|
| not applicable | `not applicable` | NCIT:C48660 | none |
| unknown | `missing`, `not collected` | NCIT:C157157 | none |
| not available | `not provided`, `restricted access` | NCIT:C126101 | none |
| other | none | none | none |
| cannot be assessed | none | NCIT:C48657 | OBI:0002200 `cannot be assessed determination` |

The INSDC column collapses in a way worth noticing. `not provided` and `restricted access`
both land on `not available`, and the difference between them is exactly whether it is worth
asking again. `DetailedMissingValueReasonEnum` exists to carry that distinction alongside the
coarse value.

The `other` row is empty in three columns. A value that was determined and falls outside the
allowed value set is not missing at all, and neither INSDC nor the NCIT Missing Value Reason
branch has a term for it, because it does not belong there.

## What OBO offers today, and where the gap is

OBI has `OBI:0002199` "reason for lack of data item". Checked against the OLS API on
2026-09-02, it has exactly four descendants:

- `OBI:0002200` cannot be assessed determination
- `OBI:0002202` GX, a cannot-be-assessed determination for histologic tumor grade
- `OBI:0002203` pTX, for pathologic primary tumor staging
- `OBI:0002204` pNX, for pathologic staging of lymph nodes

Three of the four are cancer staging codes. The branch is real, correctly placed, and narrow.
So the general reasons that a submitter of environmental or microbiome data actually needs,
does not apply, never measured, withheld, have no OBI term to point at, which is why the
`meaning:` values in this repository point at NCIT instead.

That is the gap, stated as plainly as it can be. Filling it is what an OBO-side hierarchy for
incomplete data records would do, and if one lands, the `meaning:` values in
`src/schema/common.yaml` are the only thing in this repository that has to change.

Cause c, the assay that ran and produced no datum, is the one OBI has been working on longest:
https://github.com/obi-ontology/obi/issues/1230 "Provide patterns for relating absence of
actionable data with assay 'successfulness'", open since 2020-09-06 and last active
2026-04-07. It is out of scope here because it is a fact about a process rather than about a
field, but any complete answer has to reach it.

## Completeness is relative to a schema

The six options are six schemas over one data shape, so the same record can be complete under
one and incomplete under another. One file demonstrates it. `data/option1/valid_depth_reason.yaml`
records a negative control sample as `depth_m: not applicable`. Validated on 2026-09-02 against
linkml 1.11.1:

```
$ linkml-validate -s src/schema/option1_union.yaml -C Biosample data/option1/valid_depth_reason.yaml
(passes)

$ linkml-validate -s src/schema/option0_strict.yaml -C Biosample data/option1/valid_depth_reason.yaml
[ERROR] [data/option1/valid_depth_reason.yaml/0] 'not applicable' is not of type 'number' in /depth_m
```

Same bytes, opposite verdicts, and neither validator is wrong.

That is not a quirk of the setup. It is the reason "incomplete" cannot be a property of a
record on its own. A record is incomplete with respect to a schema, and a data system that
validates against more than one schema can hold a record that is both.

The same applies over time. A value can be scheduled for collection, in process, stored,
deleted, or offline, and none of those states is a property of the sample. They are properties
of the dataset, and they can change without the sample record changing at all. That is a
second argument for option 4, and it is a stronger one than merge-safety alone, because it
explains why the absence record needs its own lifecycle.

## Open questions

1. Should a required-but-nullable slot also be able to carry a reason, or are those two
   separate problems? This is live at https://github.com/orgs/linkml/discussions/3813.
2. `value_presence` is marked `status: unstable` in the LinkML metamodel, and options 2 and 3
   both depend on it. Is it safe to build on?
3. Is `other` a missing-value reason at all, or a value-set coverage problem wearing the same
   coat?
4. Does cause f belong in a validation report, in provenance, or in neither?
