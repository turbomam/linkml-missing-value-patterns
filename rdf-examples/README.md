# RDF examples: ways Napoleon's height ends up missing

A reworking of the earlier blood glucose examples (this directory at commit 406a35f) (blood glucose in a health care encounter) with a different
scenario, for the OBI developer call on 2026-09-14. Pattern numbering, file names, queries, the
negative control, and the ROBOT checks follow the template. Terms reused from the template were
verified there; new terms were checked against the OLS4 API on 2026-09-14.

## Scenario

Measurements of Napoleon Bonaparte's standing height, held in an imagined present-day archive.
**The archive and every record in it are invented for illustration**: the examinations, the
physician, the birth record, the hair lock, the descendant DNA comparison, the witness interview,
and the conversion run.

The only historical statements, from the English Wikipedia article "Napoleon complex"
(https://en.wikipedia.org/wiki/Napoleon_complex, read 2026-09-14):

- he was estimated at 5 feet 2 inches in pre-metric French measures, about 1.67 m;
- other historians give 5 feet 7 inches (1.70 m);
- the British cartoonist James Gillray popularized the myth that he was short.

No other historical claim is made in these files.

`base.ttl` holds `ex:napoleon` (NCBITaxon:9606, bearer of OBI:0000093 'patient role'),
`ex:napoleonHeight` (PATO:0000119 'height', RO:0000052 'characteristic of' Napoleon),
`ex:physician1` (bearer of OMRSE:00000012 'health care provider role'), and `ex:examination1`
(OGMS:0000097 'health care encounter'). Each pattern file adds (or withholds) `ex:heightAssay1`,
an OBI:0003817 'length measurement assay' with Napoleon as specified input and
`ex:heightDatum1`, an IAO:0000109 'measurement datum' about his height, as specified output,
with `ex:valueSpec1`, an OBI:0001931 'scalar value specification' with OBI:0001937 'has specified
numeric value' and IAO:0000039 'has measurement unit label' UO:0000008 'meter'.
Namespace: `https://example.org/napoleon/`.

**No OBI term for body height or stature measurement was found.** OLS4 searches of OBI for
"height", "stature", "length", and "anthropometr" returned no such assay. OBI:0003817 'length
measurement assay' (definition "An assay that measures the distance between two points") is the
closest verified OBI class, and is used throughout. CMO:0000106 'body height' ("The vertical
measurement of a body") exists in the Clinical Measurement Ontology and would be a candidate, but
it is not used in the triples.

## Patterns

| Pattern | File | Scenario | Query finds |
|---|---|---|---|
| p00 complete | `p00_complete.ttl` | 1.67 m | data with a numeric value and unit |
| p01 nothing asserted | `p01_nothing_asserted.ttl` | examination with no height entry | patient examinations with no parts, no statement, no negation |
| p02 sentinel literal (anti-pattern) | `p02_sentinel_literal.ttl` | the string `5'2"` as the numeric value | non-numeric literals in the numeric position |
| p03 reason as a term | `p03_reason_as_term.ttl` | height at birth: GENEPIO:0001620 'not collected' (invented birth record) | a datum status where the value specification belongs |
| p04 value node without value | `p04_value_node_without_value.ttl` | unit metre, no number, GENEPIO:0001668 'not provided' | value specifications with unit, no number, and a status |
| p05 failed attempt | `p05_failed_assay.ttl` (+ `_contradiction`) | measurement attempt failed, COB:0000083 | failed planned processes with no output |
| p06 not applicable | `p06_not_applicable.ttl` (+ `_contradiction`) | hair lock relic examination allows 0 length measurement parts, plus per-record GENEPIO:0001619 | class-level zero cardinality and per-record status |
| p07 restricted access | `p07_restricted_access.ttl` | descendant DNA comparison datum, GENEPIO:0001810 (illustrative) | data that exist but are withheld |
| p08 bounded value | `p08_bounded_value.ttl` | 1.67 m and 1.70 m as a datatype restriction plus the two source figures | value specifications with bound facets and their estimates |
| p09 lost in transit | `p09_lost_in_transit.ttl` | conversion used the English inch: 62 x 0.0254 = 1.5748 m; original entry unchanged | validation results joined to the PROV-O activity and source |
| p10 negation | `p10_negation.ttl` (+ `_contradiction`) | examination has no length measurement part | complement membership and negative property assertion |
| p11 unknown but exists | `p11_unknown_but_exists.ttl` | blank node and existential forms | blank node values and existential restrictions |
| p12 asked, answer unknown | `p12_asked_unknown.ttl` | witness answered NCIT:C79729 'Asked but Unknown' (invented interview) | answers typed NCIT:C79729 |

p08: the interval summarizes two disagreeing sourced figures. It is not a claim that the true
height lies between them. p09: the file shows how a unit mix-up can produce a value that looks
short. It makes no claim about how the historical myth arose.

## Running the checks

```bash
.venv/bin/python rdf-examples/run_queries.py --merged-dir .demo-build/napoleon-merged
robot reason --reasoner HermiT --input .demo-build/napoleon-merged/merged_p10_negation.ttl --output .demo-build/napoleon-merged/p10.ofn
```

`run_queries.py` is the template script with only its usage line changed. It parses base plus each
pattern, runs the matching query, and fails if the query returns zero rows. As a negative control,
every query except p00 is also run against base plus p00 and must return zero rows. Use the
merged files for ROBOT: `robot merge` with separate inputs misreads properties declared only in
`base.ttl` (see the template README).

Result on 2026-09-14 (rdflib from the repo `.venv`): exit 0.

| Query | Rows on base + pattern | Rows on base + p00 (control) |
|---|---|---|
| p00 | 1 | n/a |
| p01, p02, p03, p04, p07, p09, p12 | 1 each | 0 |
| p05, p06, p10, p11 | 2 each | 0 |
| p08 | 4 (2 facets x 2 estimates) | 0 |

## ROBOT results

ROBOT 1.9.10, HermiT, run 2026-09-14 on the merged files.

| Merged input | Result |
|---|---|
| base + p00, p01, p03, p04, p05, p06, p07, p08, p09, p10, p11, p12 | consistent |
| base + p02 | inconsistent |
| base + p05_failed_assay_contradiction | inconsistent |
| base + p06 + p06_not_applicable_contradiction | inconsistent |
| base + p10 + p10_negation_contradiction | inconsistent |

The template README gives the explanation for each inconsistency; the axioms involved are the
same here, with OBI:0003817 in place of the glucose assay classes. As in the template, the
consistent results for p09 and p11 say little: p09 is PROV-O and SHACL instance data, and p11's
blank node in a data property position is outside OWL 2 DL.

## Terms

Checked 2026-09-14 against https://www.ebi.ac.uk/ols4/api/ (v1 `/terms/` and `/properties/`
endpoints, `hierarchicalAncestors` for subclass links; UO individuals via `/individuals`).
OLS versions: OBI 2026-07-27, PATO 2025-05-14; others as in the template README. None is obsolete.

New in this directory:

| CURIE | Label | Ontology (OLS) | Kind | Note |
|---|---|---|---|---|
| OBI:0003817 | length measurement assay | obi | class | ancestors include OBI:0000070 assay, COB:0000035 |
| OBI:0000435 | genotyping assay | obi | class | ancestors include OBI:0000070 assay (p07) |
| PATO:0000119 | height | pato | class | "A 1-D extent quality inhering in a bearer by virtue of the bearer's vertical dimension of extension." |
| RO:0000052 | characteristic of | ro | object property | |
| UO:0000008 | meter | uo | class and individual | |
| CMO:0000106 | body height | cmo | class | cited in comments only |

Reused from the template (verified there): BFO:0000050, BFO:0000051, RO:0000057, RO:0000087,
IAO:0000136, IAO:0000039, OBI:0000293, OBI:0000299, OBI:0001938, OBI:0001937, OBI:0002135,
COB:0000085, OGMS:0000097, OBI:0000093, OMRSE:00000012, NCBITaxon:9606, OBI:0000070,
OBI:0003725, COB:0000082, COB:0000035, COB:0000083, IAO:0000030, IAO:0000027, IAO:0000109,
OBI:0000938, OBI:0001933, OBI:0001931, OBI:0001930, GENEPIO:0001850, GENEPIO:0001619,
GENEPIO:0001620, GENEPIO:0001668, GENEPIO:0001810, NCIT:C79729.

Local classes and individuals (not OBO): `ex:HairLockRelicExamination` and all `ex:` individuals.
Not OBO: PROV-O `http://www.w3.org/ns/prov#`, SHACL `http://www.w3.org/ns/shacl#`. There is no UO
term used for the French or English inch; both appear only in comments and literals.

## Unresolved

The failed-assay question (p05) is https://github.com/obi-ontology/obi/issues/1230 "Provide
patterns for relating absence of actionable data with assay 'successfulness'"; see the template
README for the positions recorded there. Two gaps specific to this scenario: OBI has no body height
assay class, so p06 and p10 restrict on all length measurement assays; and OBI has no range value
specification, so p08 uses an OWL datatype restriction.
