# RDF examples: ways a blood glucose value ends up missing

Turtle companions to the LinkML options in this repository, written for the OBI developer call
on 2026-09-14. Each file shows one way a value can be absent, as triples, using OBO terms that
were checked against the OLS4 API on 2026-09-14.

## Scenario

A patient (`ex:patient1`, bearer of OBI:0000093 'patient role') and a provider
(`ex:provider1`, bearer of OMRSE:00000012 'health care provider role') participate in
`ex:encounter1`, an OGMS:0000097 'health care encounter'. A blood specimen collection, part of
the encounter, outputs `ex:specimen1`, an OBI:0000655 'blood specimen'. These live in
`base.ttl`. Each pattern file then adds (or withholds) `ex:glucoseAssay1`, an OBI:2100072
'venous blood glucose assay' with the specimen as specified input and `ex:glucoseDatum1`, an
IAO:0000109 'measurement datum', as specified output, whose OBI:0001938 'has value
specification' points at `ex:valueSpec1`, an OBI:0001931 'scalar value specification' with
OBI:0001937 'has specified numeric value' and IAO:0000039 'has measurement unit label'
UO:0010067 'milligram per deciliter'. Namespace: `https://example.org/encounter/`.

`base.ttl` also carries a small axiom excerpt copied from OBI 2026-07-27 and COB 2025-12-15
(property domains and ranges, the COB:0000035 / COB:0000083 disjointness, a few verified
subclass links), so that a reasoner can show the consequences without importing OBI.

## Patterns

LinkML options refer to `src/schema/`: option0 strict, option1 union (and 1b), option2 value
object with value or reason, option3 sibling reason slot, option4 out-of-band report.

| Pattern | File | LinkML option | Query | What it finds |
|---|---|---|---|---|
| p00 complete (baseline) | `p00_complete.ttl` | option0 | `queries/p00_complete.rq` | data with a numeric value and unit |
| p01 nothing asserted | `p01_nothing_asserted.ttl` | none | `queries/p01_nothing_asserted.rq` | data with no value specification and no status |
| p02 sentinel literal (anti-pattern) | `p02_sentinel_literal.ttl` | none (what option1 degrades to with a string range) | `queries/p02_sentinel_literal.rq` | non-numeric literals in the numeric position |
| p03 reason as a term | `p03_reason_as_term.ttl` | option1, 1b | `queries/p03_reason_as_term.rq` | a datum status where the value specification belongs |
| p04 value node without value | `p04_value_node_without_value.ttl` | option2 | `queries/p04_value_node_without_value.rq` | value specifications with unit, no number, and a status |
| p05 assay failed, no datum | `p05_failed_assay.ttl` (+ `p05_failed_assay_contradiction.ttl`) | none | `queries/p05_failed_assay.rq` | failed planned processes with no output |
| p06 not applicable | `p06_not_applicable.ttl` (+ `p06_not_applicable_contradiction.ttl`) | option3 (`value_presence: ABSENT`) for the class form | `queries/p06_not_applicable.rq` | class-level zero cardinality, and per-record GENEPIO status |
| p07 restricted access | `p07_restricted_access.ttl` | option3 shape (reason value also fits 1, 1b, 2) | `queries/p07_restricted_access.rq` | data that exist but are withheld |
| p08 bounded value | `p08_bounded_value.ttl` | none | `queries/p08_bounded_value.rq` | value specifications with a maxExclusive bound and a detection limit |
| p09 lost in transit | `p09_lost_in_transit.ttl` | option4 | `queries/p09_lost_in_transit.rq` | SHACL results joined to PROV-O activities |
| p10 negation | `p10_negation.ttl` (+ `p10_negation_contradiction.ttl`) | none | `queries/p10_negation.rq` | complement-of-existential membership and negative property assertions |
| p11 unknown but exists | `p11_unknown_but_exists.ttl` | none | `queries/p11_unknown_but_exists.rq` | blank node values and existential restrictions |
| p12 asked, answer unknown | `p12_asked_unknown.ttl` | option1 or option2 | `queries/p12_asked_unknown.rq` | answers typed NCIT:C79729 'Asked but Unknown' |

## Running the checks

```bash
.venv/bin/python rdf-examples/run_queries.py --merged-dir .demo-build/rdf-merged
robot reason --reasoner HermiT --input .demo-build/rdf-merged/merged_p10_negation.ttl --output .demo-build/rdf-merged/p10.ofn
```

`run_queries.py` parses base plus each pattern, runs the matching query, and fails if the query
returns zero rows. As a negative control, every query except p00 is also run against base plus
p00 and must return zero rows. Result on 2026-09-14 (rdflib from the repo `.venv`):

| Query | Rows on base + pattern | Rows on base + p00 (control) |
|---|---|---|
| p00 | 1 | n/a |
| p01, p02, p03, p04, p07, p08, p09, p12 | 1 each | 0 |
| p05, p06, p10, p11 | 2 each (p05: two participants; p06, p10, p11: both forms) | 0 |

Use `--merged-dir` for ROBOT. `robot merge --input base.ttl --input pNN.ttl` parses each file on
its own, so a property declared only in `base.ttl` is read as an annotation property in the
pattern file and the reasoner never sees the assertion. That run reported every contradiction
file as consistent, which is wrong; reasoning over the single merged file gives the results below.

## ROBOT results

ROBOT 1.9.10, HermiT, Java 17.0.20.1, run 2026-09-14 on the merged files.

| Merged input | Result | Explanation (from `robot explain --mode inconsistency`) |
|---|---|---|
| base + p00, p01, p03, p04, p05, p06, p07, p08, p09, p10, p11, p12 | consistent | |
| base + p02 | inconsistent | `valueSpec1 has specified numeric value "not collected"` against OBI range `owl:real` |
| base + p05_failed_assay_contradiction | inconsistent | `has specified input` domain COB:0000035, disjoint with COB:0000083 'failed planned process' |
| base + p06 + p06_not_applicable_contradiction | inconsistent | assay part of encounter2, OBI:2100072 subClassOf OBI:2100020, `has part exactly 0 glucose assay` |
| base + p10 + p10_negation_contradiction | inconsistent | assay part of encounter1, `not (has part some glucose assay)` |

Also observed: with base + p03, HermiT infers `ex:reason1` (asserted GENEPIO:0001620 'not
collected') to be an OBI:0001933 'value specification', from the range of OBI:0001938.
The consistent results for p09 and p11 say little. p09 is SHACL and PROV-O instance data with no
OWL axioms to violate. p11's Wikidata-style blank node in a data property position is outside
OWL 2 DL by design, and how OWL API read that triple was not inspected.

## Verified terms

Checked 2026-09-14 against https://www.ebi.ac.uk/ols4/api/ (v1 term and property endpoints,
`hierarchicalParents` / `hierarchicalAncestors` for subclass links). OLS versions: OBI
2026-07-27, COB 2025-12-15, GENEPIO 2026-04-13, IAO 2026-03-30, RO 2026-09-04, OGMS 2021-08-19,
OMRSE 2026-09-03, UO 2026-07-31, NCIT 26.02d. None is obsolete. IRIs are
`http://purl.obolibrary.org/obo/{PREFIX}_{ID}`.

| CURIE | Label | Ontology (OLS) | Kind |
|---|---|---|---|
| BFO:0000050 | part of | ro | object property |
| BFO:0000051 | has part | ro (not defining) | object property |
| RO:0000057 | has participant | ro | object property |
| RO:0000087 | has role | ro | object property |
| IAO:0000136 | is about | iao | object property |
| IAO:0000039 | has measurement unit label | iao | object property |
| OBI:0000293 | has specified input | obi | object property |
| OBI:0000299 | has specified output | obi | object property |
| OBI:0001938 | has value specification | obi | object property |
| OBI:0001937 | has specified numeric value | obi | data property |
| OBI:0002135 | has specified value | obi | data property |
| COB:0000085 | intended plan process type | cob | object property |
| OGMS:0000097 | health care encounter | ogms | class |
| OBI:0000093 | patient role | obi | class |
| OMRSE:00000012 | health care provider role | omrse | class |
| NCBITaxon:9606 | Homo sapiens | ncbitaxon | class |
| OBI:0000655 | blood specimen | obi | class |
| OBI:1110095 | blood specimen collection | obi | class |
| OBI:0000070 | assay | obi | class |
| OBI:0003040 | blood assay | obi | class |
| OBI:2100020 | glucose assay | obi | class |
| OBI:2100072 | venous blood glucose assay | obi | class |
| OBI:0003725 | survey administration assay | obi | class |
| COB:0000082 | planned process | cob | class |
| COB:0000035 | completely executed planned process | cob | class |
| COB:0000083 | failed planned process | cob | class |
| IAO:0000030 | information content entity | iao | class |
| IAO:0000027 | data entity | iao | class |
| IAO:0000109 | measurement datum | iao | class |
| OBI:0000938 | categorical measurement datum | obi | class |
| OBI:0001933 | value specification | obi | class |
| OBI:0001931 | scalar value specification | obi | class |
| OBI:0001930 | categorical value specification | obi | class |
| OBI:0003549 | lower limit of detection | obi | class |
| OBI:0002199 | reason for lack of data item | obi | class |
| GENEPIO:0001850 | datum status | genepio | class |
| GENEPIO:0001618 | missing | genepio | class |
| GENEPIO:0001619 | not applicable | genepio | class |
| GENEPIO:0001620 | not collected | genepio | class |
| GENEPIO:0001662 | in process | genepio | class |
| GENEPIO:0001668 | not provided | genepio | class |
| GENEPIO:0001810 | restricted access | genepio | class |
| GENEPIO:0001851 | recorded | genepio | class |
| UO:0010067 | milligram per deciliter | uo | class and individual |
| NCIT:C79729 | Asked but Unknown | ncit | class |

Cited in comments but not used as triples: OBI:0002200 'cannot be assessed determination',
OBI:0003548 'upper limit of detection', OBI:0002556 / OBI:0002557 'minimum / maximum age value
specification', RO:0002214 'has prototype', NCIT:C80217 'Not Asked', NCIT:C17998 'Unknown',
OBI:0000852 'record of missing knowledge'. OBI:0000011 'planned process' is obsolete, replaced
by COB:0000035.

Not OBO, checked at the source: PROV-O `http://www.w3.org/ns/prov#`, SHACL
`http://www.w3.org/ns/shacl#`, HL7 v3 NullFlavor `ASKU` "asked but unknown" in
`http://terminology.hl7.org/CodeSystem/v3-NullFlavor` (version 4.0.0), FHIR
data-absent-reason `asked-unknown` in `http://terminology.hl7.org/CodeSystem/data-absent-reason`
(version 2.0.0).

Corrections to the candidate list this was built from: OBI:0002135 is 'has specified value'
(the parent); 'has specified numeric value' is OBI:0001937. There is no OBI 'health care
provider role'; the term is OMRSE:00000012.

## Where OBO has no good term

- **Not collected, not applicable, withheld (p03, p04, p06, p07).** OBI:0002199 'reason for lack
  of data item' has four descendants, three of them cancer staging codes. GENEPIO datum status
  covers these cases, but it sits under IAO:0000027 'data entity', not under OBI:0002199, and no
  OBI relation links a datum status to the datum or value specification. `is about` is used here,
  following the GENEPIO definition.
- **Below detection limit (p08).** OBI has 'lower limit of detection' and 'upper limit of
  detection' with no axioms linking them to data, and no 'less than' relation or range value
  specification. The bound is expressed as an OWL datatype restriction.
- **Asked, answer unknown (p12).** No OBI, IAO, or GENEPIO term. NCIT:C79729 fits. OBI:0000852
  'record of missing knowledge' is close in spirit, but its editor note says the class should be
  broken down into kinds such as "inability to determine" versus "no attempt made", which is the
  distinction this pattern needs.
- **Failed assay (p05).** COB:0000083 exists. COB:0000085 exists with a label only.

## Unresolved

https://github.com/obi-ontology/obi/issues/1230 "Provide patterns for relating absence of
actionable data with assay 'successfulness'" (open since 2020-09-06, last comment 2026-04-07).
Positions recorded there: assays are asserted to be completed planned processes (dev call,
2020-09-14); an "intends to implement" relation should be requested in COB (2020-09-28); NMDC
uses COB:0000082 for runs that can fail (2026-04-06); RO:0002214 'has prototype' was proposed as
the link from a failed run to a prototypical completed one, with the objection that its
definition concerns anatomical prototypes and the counter-position that the shared plan
specification is the link, possibly through a dedicated relation (2026-04-07). No resolution is
recorded. p05 uses COB:0000085 'intended plan process type' as the closest existing relation;
whether it is the relation requested in 2020 is not documented in COB.

Consequences visible in these files, not settled anywhere:

1. A failed run cannot be typed as an assay and cannot use `has specified input`, because both
   imply COB:0000035, which is disjoint with COB:0000083 (p05 contradiction file).
2. Putting a reason where a value specification belongs makes the reason a value specification
   under OBI's range axiom (p03).
3. 'has part' is transitive in RO, so the class-level "exactly 0" of p06 is outside OWL 2 DL
   once RO is imported, and has to be written as the complement form of p10.
