# Master TODO -- Tutorial Completion

**Status: COMPLETE.** All 569 tutorials across 16 categories are filled with
full 8-section content (Introduction, Prerequisites, Theory, Assumptions,
R Implementation, Output & Results, Interpretation, Practical Tips), runnable
R code, and >=1,800 characters of prose.

Last audited: 2026-04-19.

## Category status summary

| # | Category                       | Total | Done | Remaining |
|---|--------------------------------|------:|-----:|----------:|
| 1 | statistical-foundations        |    31 |   31 |         0 |
| 2 | descriptive-statistics         |    25 |   25 |         0 |
| 3 | probability                    |    40 |   40 |         0 |
| 4 | inference                      |    45 |   45 |         0 |
| 5 | sample-size                    |    30 |   30 |         0 |
| 6 | visualisation                  |    35 |   35 |         0 |
| 7 | regression-modelling           |    51 |   51 |         0 |
| 8 | multivariate                   |    30 |   30 |         0 |
| 9 | time-series                    |    30 |   30 |         0 |
|10 | bayesian                       |    35 |   35 |         0 |
|11 | survival-analysis              |    30 |   30 |         0 |
|12 | bioinformatics                 |    50 |   50 |         0 |
|13 | machine-learning               |    46 |   46 |         0 |
|14 | clinical-biostatistics         |    36 |   36 |         0 |
|15 | meta-analysis                  |    25 |   25 |         0 |
|16 | experimental-design            |    30 |   30 |         0 |
|   | **TOTAL**                      | **569**| **569**|       **0** |

Verification:

```bash
# Should return 0:
grep -rl 'status = "stub"' content/ 2>/dev/null | wc -l

# Should return 569:
grep -rl 'status = "complete"' content/tutorials/ 2>/dev/null | \
  grep -v _index.md | wc -l
```

## Companion infrastructure

- **Decision tree** (`content/decision-tree/`): 38 pages complete, plus an
  interactive wizard (`static/js/wizard.js`) with 6 passing node tests
  (`scripts/wizard-test.mjs`).
- **Shiny app specs** (`content/shiny/`): 16 Shiny app specifications.
- **Stub generator** (`scripts/generate_stubs.py`) and per-category
  curriculum files (`scripts/curriculum/*.txt`) remain available for future
  expansion.
- **Renv lockfile** (`renv.lock`) pins R 4.4.1 and all packages referenced
  across tutorials.
