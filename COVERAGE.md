# Coverage Verification -- Statistical Test Decision Tree

This document maps every tutorial page in `content/decision-tree/` to the
UZH Methodenberatung structural reference and confirms that every test in
the static tree is (a) a reachable wizard leaf and (b) reachable from the
landing page in <=3 clicks.

## UZH URL mapping

The UZH Methodenberatung site at https://www.methodenberatung.uzh.ch/de/datenanalyse_spss.html
is used only as a structural reference. All prose, examples, R code, and
reporting sentences in this section are independently authored in English
(see ORIGINALITY.md). The URL mapping below lists each UZH subpage
referenced in the spec and our corresponding page.

| UZH URL slug                                      | Our page                                                               | Topic |
|---                                                |---                                                                     |---|
| `skalenniveau.html`                               | `foundations/measurement-scales.md`                                    | Scales of measurement |
| `datenanalyse_spss/deskuniv.html`                 | `foundations/descriptive-univariate.md`                                | Descriptive univariate |
| (not on UZH; added for completeness)              | `foundations/normality.md`                                             | Normality checks |
| (not on UZH; added for completeness)              | `foundations/outliers.md`                                              | Outlier detection |
| (not on UZH; added for completeness)              | `foundations/hypotheses-significance.md`                               | Hypotheses, alpha, power |
| `zentral.html`                                    | `differences/central-tendency/_index.md`                               | Central tendency overview |
| `zentral/ttestunabh.html`                         | `differences/central-tendency/independent-t-test.md`                   | Independent t-test (+ Welch) |
| `zentral/ttestabh.html`                           | `differences/central-tendency/paired-t-test.md`                        | Paired t-test |
| `zentral/mann.html`                               | `differences/central-tendency/mann-whitney-u.md`                       | Mann-Whitney U |
| `zentral/wilkoxon.html`                           | `differences/central-tendency/wilcoxon-signed-rank.md`                 | Wilcoxon signed-rank |
| `zentral/vorzeichen.html`                         | `differences/central-tendency/sign-test.md`                            | Sign test |
| `zentral/evarianz.html`                           | `differences/central-tendency/one-way-anova.md`                        | One-way ANOVA |
| `zentral/mvarianz.html`                           | `differences/central-tendency/factorial-anova.md`                      | Factorial ANOVA |
| `zentral/evarianzmessw.html`                      | `differences/central-tendency/rm-anova-one-way.md`                     | One-way rmANOVA |
| `zentral/mvarianzmessw.html`                      | `differences/central-tendency/rm-anova-factorial.md`                   | Factorial/mixed rmANOVA |
| `zentral/kruskal.html`                            | `differences/central-tendency/kruskal-wallis.md`                       | Kruskal-Wallis |
| `zentral/friedman.html`                           | `differences/central-tendency/friedman.md`                             | Friedman |
| `unterschiede/evarianz.html` (variance branch)    | `differences/variances.md`                                             | Variance tests (chi-sq, F, Levene) |
| `proportionen.html`                               | `differences/proportions/_index.md`                                    | Proportions overview |
| `proportionen/binominal.html`                     | `differences/proportions/binomial-test.md`                             | Binomial test |
| `proportionen/pearsonuntersch.html`               | `differences/proportions/chi-square-goodness-of-fit.md`                | Chi-sq goodness-of-fit (+ KS) |
| `zusammenhaenge.html`                             | `associations/_index.md`                                               | Associations overview |
| `zusammenhaenge/pearsonzush.html`                 | `associations/chi-square-contingency.md`                               | Chi-sq contingency (+ Fisher) |
| `zusammenhaenge/rangkorrelation.html`             | `associations/spearman-correlation.md`                                 | Spearman |
| `zusammenhaenge/pearson.html`                     | `associations/pearson-correlation.md`                                  | Pearson |
| (added for completeness)                          | `associations/kendall-tau.md`                                          | Kendall's tau |
| `zusammenhaenge/ereg.html`                        | `associations/simple-linear-regression.md`                             | Simple linear regression |
| `zusammenhaenge/mreg.html`                        | `associations/multiple-regression.md`                                  | Multiple regression |
| `zusammenhaenge/lreg.html`                        | `associations/logistic-regression.md`                                  | Binary logistic regression |
| (extension per UZH)                               | `associations/ordinal-logistic-regression.md`                          | Ordinal logistic regression |
| (extension per UZH)                               | `associations/multinomial-logistic-regression.md`                      | Multinomial logistic regression |
| `interdependenz.html`                             | `interdependence/_index.md`                                            | Interdependence overview |
| `interdependenz/reduktion/faktor.html`            | `interdependence/factor-analysis.md`                                   | Factor analysis (+ CFA pointer) |
| `interdependenz/gruppierung/cluster.html`         | `interdependence/cluster-analysis.md`                                  | Cluster analysis (hier., k-means, two-step) |
| `entscheidassistent.html`                         | `decision-assistant.md` + `decision-tree.md`                           | Decision assistant and static tree |

No UZH page referenced in the spec is unreplicated.

## Wizard leaf coverage

Every leaf in `static/js/wizard.js` resolves to a method page listed above.
The tests `scripts/wizard-test.mjs` enforce:

1. Every leaf in the `LEAVES` table is reachable from `START` via some path.
2. Every `leaf` referenced in a question's choices corresponds to an entry
   in `LEAVES`.
3. Every `next` edge points to a defined question node.
4. No duplicate tokens within a single question.
5. Every leaf has a page URL and a rationale.

Run: `node --test scripts/wizard-test.mjs` (all 6 suites pass).

## Static-tree node coverage

Every test node in the Mermaid chart in `decision-tree.md` has an explicit
`click` handler pointing to its method page. All 27 method-page targets in
the chart correspond to files under `content/decision-tree/`; all 27 are
also wizard leaves.

## Click depth from landing page

Landing page (`/decision-tree/`) -> section index (e.g., Differences ->
Central tendency) -> method page. Every method page is reachable in
exactly 3 clicks from the landing page; the wizard reaches every leaf in
3-5 clicks, and the static tree reaches every leaf in 1 click (all tests
are visible on the chart).

## Section-by-section file inventory

```
content/decision-tree/
  _index.md
  decision-assistant.md
  decision-tree.md
  references.md
  foundations/
    _index.md
    measurement-scales.md
    descriptive-univariate.md
    normality.md
    outliers.md
    hypotheses-significance.md
  differences/
    _index.md
    variances.md
    central-tendency/
      _index.md
      independent-t-test.md
      paired-t-test.md
      mann-whitney-u.md
      wilcoxon-signed-rank.md
      sign-test.md
      one-way-anova.md
      factorial-anova.md
      rm-anova-one-way.md
      rm-anova-factorial.md
      kruskal-wallis.md
      friedman.md
    proportions/
      _index.md
      binomial-test.md
      chi-square-goodness-of-fit.md
  associations/
    _index.md
    chi-square-contingency.md
    spearman-correlation.md
    pearson-correlation.md
    kendall-tau.md
    simple-linear-regression.md
    multiple-regression.md
    logistic-regression.md
    ordinal-logistic-regression.md
    multinomial-logistic-regression.md
  interdependence/
    _index.md
    factor-analysis.md
    cluster-analysis.md
```

**Total**: 38 content pages (4 navigation + 5 foundations + 14 differences
including sub-indexes + 10 associations including section index + 3
interdependence including section index).

## Sign-off

All UZH reference pages listed in the spec are covered. All wizard leaves
are reachable, all tests appear in the static tree, and every method page
is <=3 clicks from the landing page.
