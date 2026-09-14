# Aboutness of the examples

Which examples say clearly what their data is about. Recorded 2026-09-14 from the files themselves:
the `IAO:0000136` (is about) triples in `rdf-examples/`, and the slots and comments in `napoleon/data/`.

In the OBI draft hierarchy a complete data record "has a clear referent". Damion Dooley's notes from
the 2026-08-31 call ask whether a data item is semantically appropriate for its subject, for example
the height of a hair lock. This table records where our own examples meet that bar and where they do not.

## RDF patterns (`rdf-examples/`)

In `base.ttl`, `ex:napoleonHeight` is a PATO:0000119 height that is RO:0000052 characteristic of `ex:napoleon`.

| File | Data item | Is about | Aboutness |
|---|---|---|---|
| [p00_complete](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p00_complete.ttl) | `heightDatum1` | `napoleonHeight` | clear |
| [p01_nothing_asserted](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p01_nothing_asserted.ttl) | none | nothing | none: no data item exists |
| [p02_sentinel_literal](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p02_sentinel_literal.ttl) | `heightDatum1` | `napoleonHeight` | clear subject; the content is not a number |
| [p03_reason_as_term](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p03_reason_as_term.ttl) | `heightDatum1` | `napoleonHeight` | subject clear, time not: it is the same height individual as the adult height, and "height at birth" appears only in `rdfs:comment` |
| [p04_value_node_without_value](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p04_value_node_without_value.ttl) | `heightDatum1`; `status1` | `napoleonHeight`; the status is about `valueSpec1` | clear, on two levels |
| [p05_failed_assay](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p05_failed_assay.ttl) | none | nothing; the failed process has Napoleon and the physician as participants | none: no data item was produced |
| [p06_not_applicable](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p06_not_applicable.ttl) | `heightDatum2`; `status6` | `hairLock1`; the status is about `heightDatum2` | clear, and the point of the pattern: a height datum about something that has no height |
| [p07_restricted_access](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p07_restricted_access.ttl) | `dnaDatum1`; `status7` | both `napoleon` and `descendant1`, by design, since it is a comparison; the status is about `dnaDatum1` | clear: the withheld result is the comparison itself, which has two subjects |
| [p08_bounded_value](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p08_bounded_value.ttl) | `heightDatum1` with two estimate parts | `napoleonHeight` | clear |
| [p09_lost_in_transit](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p09_lost_in_transit.ttl) | `heightDatum1` | `napoleonHeight` | clear subject, false content: 1.5748 m comes from a unit conversion error |
| [p10_negation](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p10_negation.ttl) | none | the negation is stated about `examination1` | about the examination, not the height |
| [p11_unknown_but_exists](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p11_unknown_but_exists.ttl) | `heightDatum1` | `napoleonHeight` | clear; the value is unknown |
| [p12_asked_unknown](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/rdf-examples/p12_asked_unknown.ttl) | `answerDatum1`, output of `witnessInterview1` | `napoleonHeight` | clear, and reported by a witness rather than measured |

## LinkML records (`napoleon/data/`)

Apart from side-report, no Napoleon schema has a data slot saying what a record is about. The referent
comes from schema metadata: the `HeightRecord` class descriptions name Napoleon, while the class name
itself does not. In side-report, `MissingValueReport` states its subject with `about_record` and `about_slot`.

| Record | What it is about | Aboutness |
|---|---|---|
| [strict/valid_measured](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/strict/valid_measured.yaml) and the other measured records | Napoleon's height, per the class description | implicit: in schema metadata, not in the data |
| [union/valid_control_sample](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/union/valid_control_sample.yaml) | a reagent blank, per its comment | conflicts with its class: a HeightRecord that is not about a person |
| [union/valid_not_collected](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/union/valid_not_collected.yaml) | height at birth, per its comment | implicit subject; the time is only in a comment |
| [one_of/valid_human_identifiable](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/one_of/valid_human_identifiable.yaml) | a living descendant's height, per its comment | conflicts with its class: not Napoleon |
| [value_object/valid_third_party](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/value_object/valid_third_party.yaml) | Napoleon's height as reported in a memoir | implicit; the memoir is only in `reason_note` |
| [reason_column/valid_answer_unknown](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/reason_column/valid_answer_unknown.yaml) | Napoleon's height, as answered by a witness | implicit; the witness is not recorded |
| [reason_column/valid_declined](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/reason_column/valid_declined.yaml) | Napoleon's height, not measured because he declined | implicit |
| [side_report/valid_lost_in_transit](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/side_report/valid_lost_in_transit.yaml) | the report is about record REC:0501, slot `height_m` | explicit: `about_record` and `about_slot` |
| [not_applicable/valid_hair_lock](https://github.com/turbomam/linkml-missing-value-patterns/blob/main/napoleon/data/not_applicable/valid_hair_lock.yaml) | a hair-lock relic | clear from schema metadata (class name and description), not from the data |

## What this suggests

- Only the side-report pattern states aboutness in the data. The other LinkML records take their referent
  from schema metadata (the class descriptions), and two records contradict theirs. An explicit `about` slot, ranged over identifiers
  or ontology terms, would make the records say what the RDF says with IAO:0000136.
- In RDF, aboutness is clear whenever a data item exists. It is absent when nothing was produced
  (p01, p05), shifted to another entity in p10, and deliberately shared between two subjects in p07.
