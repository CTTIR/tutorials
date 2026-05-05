# Interactive Shiny Apps

Sixteen self-contained Shiny applications -- one per topic area -- that
pair with the tutorial site at the root of this repository.

Each app lives in its own subfolder with a `app.R` file and a short
`README.md`. To run an app locally:

```r
# From the repository root
shiny::runApp("apps/01-clt-explorer")
```

All apps use packages pinned in `renv.lock`; run `renv::restore()` once
before the first launch.

## Catalogue

| # | App | Topic area |
|---|-----|------------|
| 01 | CLT Explorer | Statistical Foundations |
| 02 | Summary Statistics Lab | Descriptive Statistics |
| 03 | Distribution Explorer | Probability |
| 04 | Hypothesis Test Simulator | Inference |
| 05 | Power Calculator | Sample Size |
| 06 | ggplot2 Playground | Visualisation |
| 07 | Regression Playground | Regression Modelling |
| 08 | PCA Explorer | Multivariate |
| 09 | Time-Series Forecaster | Time Series |
| 10 | Bayesian Updater | Bayesian Statistics |
| 11 | Survival Curve Builder | Survival Analysis |
| 12 | RNA-seq Pipeline | Bioinformatics |
| 13 | ML Workflow Lab | Machine Learning |
| 14 | Diagnostic Accuracy Calculator | Clinical Biostatistics |
| 15 | Forest Plot Builder | Meta-Analysis |
| 16 | DOE Lab | Experimental Design |

See `content/shiny/<nn>-<name>.md` for the full specification of each
app and which tutorials it is embedded into.
