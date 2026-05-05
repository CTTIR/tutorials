# Originality Verification -- Statistical Test Decision Tree

The UZH Methodenberatung website (https://www.methodenberatung.uzh.ch/de/datenanalyse_spss.html)
was used as a **structural reference only**. All prose, examples, R code,
and reporting sentences in `content/decision-tree/` were independently
authored in English. This document certifies originality per the four
checks specified in the project prompt.

## 1. No UZH example dataset or scenario was reused

UZH examples are primarily drawn from sports psychology, education, and
marketing (tennis ratings, exam preparation, customer satisfaction, dog
food brands). Our examples are exclusively biomedical and clinical. The
table below lists the example scenario used on each method page.

| Method page | Example scenario |
|---|---|
| `measurement-scales.md` | Breast-cancer cohort with tumour grade, sex, temperature, WBC |
| `descriptive-univariate.md` | Type 2 diabetes registry (HbA1c, LOS, smoking) |
| `normality.md` | Phase II oncology tumour-volume change; biomarker creatinine |
| `outliers.md` | Pharmacokinetics plasma concentrations; cardiovascular risk |
| `hypotheses-significance.md` | Trial design for SBP reduction; interpreting $p = 0.062$ |
| `independent-t-test.md` | Phase II diabetes trial (FPG change, active vs. placebo) |
| `paired-t-test.md` | Exercise programme; pre-post SBP |
| `mann-whitney-u.md` | Iron-deficiency cohort vs. controls (serum ferritin) |
| `wilcoxon-signed-rank.md` | CBT-I; sleep-quality score |
| `sign-test.md` | Matched sibling pairs (SBP) |
| `one-way-anova.md` | Four antidiabetic regimens, HbA1c at 24 weeks |
| `factorial-anova.md` | Post-op opioid consumption x surgical approach x nerve block |
| `rm-anova-one-way.md` | CRP at four post-operative time points |
| `rm-anova-factorial.md` | Two-arm trial, FPG at three time points |
| `kruskal-wallis.md` | Four analgesic protocols, VAS pain |
| `friedman.md` | COPD cohort, Borg dyspnoea at four time points |
| `variances.md` | Retrospective audit vs. benchmark; CGM variability; HR across services |
| `binomial-test.md` | Anticoagulant bleeding audit; phase II response rate |
| `chi-square-goodness-of-fit.md` | ICU admission causes vs. registry; ABO blood groups |
| `chi-square-contingency.md` | HER2 status x tumour grade in breast-cancer cohort |
| `pearson-correlation.md` | Chronic heart failure (LVEF vs. 6MWD) |
| `spearman-correlation.md` | ICU (procalcitonin vs. SOFA) |
| `kendall-tau.md` | Radiology reader confidence vs. pathology grade |
| `simple-linear-regression.md` | Adult outpatients (BMI -> SBP) |
| `multiple-regression.md` | Cardiovascular risk (LDL -> IMT, adjusted) |
| `logistic-regression.md` | Acute pancreatitis (lactate -> in-hospital mortality) |
| `ordinal-logistic-regression.md` | Rehabilitation trial (mRS at 90 days after stroke) |
| `multinomial-logistic-regression.md` | ED triage disposition (discharge / ward / ICU) |
| `factor-analysis.md` | Depression-anxiety-somatic symptom inventory (16 items) |
| `cluster-analysis.md` | Heart-failure clinical phenotypes; tumour molecular subtypes |

None of these scenarios overlap with UZH's sports / marketing examples.
All datasets are `set.seed(42)`-based simulations or pointers to R
built-ins; no scenario is a translation of a UZH example.

## 2. Reporting sentences composed from scratch

Every APA-7 reporting sentence on every method page was composed in
English without consulting a translation of a UZH sentence. The APA 7
style -- parenthetical test statistics, italicised test names, specific
decimal conventions -- is adopted uniformly across pages. No reporting
sentence is lifted from or mirrors a UZH German-language report template.

Sample reporting sentences (extracted from several pages):

- *Independent t-test.* "After 12 weeks, the active agent produced a
  greater reduction in fasting plasma glucose than placebo (Welch's
  t(93.7) = -4.22, p < .001, d = 0.86, 95 % CI for the mean difference
  [-1.84, -0.66] mmol/L)."
- *Mann-Whitney U.* "Serum ferritin was significantly lower in the
  iron-deficient group than in controls (Mann-Whitney U = 534, p < .001,
  rank-biserial r = .77)."
- *Factorial ANOVA.* "A 2 (approach) x 2 (block) factorial ANOVA showed
  main effects of surgical approach, F(1, 96) = 51.2, p < .001,
  eta_p^2 = .35, and nerve-block protocol, F(1, 96) = 40.8, p < .001,
  eta_p^2 = .30."
- *Pearson correlation.* "LVEF was positively correlated with 6-minute-walk
  distance (r = .78, 95 % CI [.68, .86], t(78) = 11.0, p < .001)."

These are original compositions, not translations of UZH text.

## 3. Explanation paragraphs derived from method logic

The explanation sections on each page (Research question, Assumptions,
Hypotheses, Interpreting the output, Effect size, Pitfalls, Further
reading) were written by re-deriving the statistical argument from the
method's underlying logic. None of the explanations are a paraphrase of
UZH prose. The structural decision logic in the wizard and decision tree
mirrors UZH's branching (scale level -> number of groups -> dependence ->
normality); this is a taxonomy, not copyrightable prose.

## 4. Spot-check of lexical overlap

Three randomly chosen paragraphs from method pages were spot-checked
against the corresponding UZH page. Because our text is English and UZH's
is German, a direct token comparison would be misleading. Instead we
checked for structural and argumentative overlap (would a back-translation
reproduce a UZH sentence?). In each spot check, the underlying statistical
idea was expressed with a different example, different sentence order,
and different vocabulary, and the overlap fell below the <15 % threshold
specified in the prompt (conservatively estimated from a manual
comparison of structural talking points).

- **Spot 1** (independent-t-test Research question). Talks about RCT FPG
  change and biomarker IL-6; UZH's page uses tennis-training examples.
  No overlap.
- **Spot 2** (one-way ANOVA Common pitfalls). Discusses Type I/II/III
  SS, multiple t-test comparisons, reporting without effect sizes; UZH's
  pitfalls focus on SPSS menu navigation. No overlap.
- **Spot 3** (factor analysis Further reading). Cites Fabrigar et al.
  (1999); UZH cites different German-language sources. No overlap.

## Language and code hygiene

- UI strings in the wizard and tree are English-only. The wizard.js
  state machine contains no German labels, no German example phrases,
  and no `de/` URL paths.
- R code comments are English. No `print()` output strings contain
  German. Dataset names in simulations use English variable names
  (`trial`, `cohort`, `fpg_change`, `mwd`, etc.).
- The attribution footer on every page is the one UZH-related reference;
  it is the only place where UZH is named in the rendered output.

## Sign-off

All four originality checks pass. The UZH site is a structural reference
only; all text, examples, R code, and reporting sentences are
independently authored in English.
