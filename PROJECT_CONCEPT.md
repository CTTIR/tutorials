# Project Concept: Statistics & Bioinformatics Tutorial Platform

## Vision

A freely accessible, comprehensive reference website for applied statistics and bioinformatics -- every topic explained with theory, practical R code, and interpretation. Designed as a one-stop learning resource that bridges the gap between textbook theory and hands-on data analysis.

## Target Audience

- Graduate students and postdocs in life sciences, medicine, and biology
- Biostatisticians and bioinformaticians in research and industry
- Clinicians and clinical researchers conducting or evaluating studies
- Self-learners transitioning into data science from adjacent fields

## Core Principles

1. **Every tutorial is self-contained** -- a reader can land on any single page and understand the topic without reading prerequisites first
2. **Theory meets practice** -- each tutorial explains the "why" (when to use a method, assumptions, limitations) before the "how" (R code)
3. **Real R code throughout** -- no pseudocode, no toy snippets; every example runs with simulated or publicly available data
4. **Publication quality** -- output includes interpretable results, proper tables, and figures ready for manuscripts
5. **VG Wort eligible** -- every tutorial exceeds the minimum text length (~1,800 characters) required for German text royalty collection

## Content Architecture

The site is organized into **16 major topic areas**, each containing **25--65 individual tutorials**, totaling **560+ entries**:

| Area | Scope |
|---|---|
| **Statistical Foundations** | Scales of measurement, populations vs. samples, central limit theorem, estimation theory, likelihood |
| **Descriptive Statistics** | Location, dispersion, shape measures, frequency tables, cross-tabulations |
| **Probability Theory** | Axioms, conditional probability, Bayes' theorem, all major distributions |
| **Inferential Statistics** | Hypothesis testing philosophy, t-tests, ANOVA family, chi-square, non-parametric tests, multiple testing correction |
| **Sample Size & Power** | Power analysis for every common design: means, proportions, correlations, survival, equivalence/non-inferiority |
| **Data Visualisation** | ggplot2 grammar, every major plot type, colour palettes, annotation, multi-panel layouts, interactive graphics |
| **Regression & Modelling** | Linear, logistic, Poisson, ordinal, multinomial, GAMs, mixed/multilevel models, regularisation, model diagnostics |
| **Multivariate Statistics** | PCA, factor analysis, cluster analysis, MDS, discriminant analysis, canonical correlation |
| **Time Series Analysis** | Stationarity, ACF/PACF, ARIMA, seasonal decomposition, forecasting, changepoint detection |
| **Bayesian Statistics** | Prior specification, conjugate models, MCMC, Stan/brms, Bayesian hypothesis testing, model comparison |
| **Survival Analysis** | Kaplan-Meier, log-rank, Cox PH, time-varying covariates, competing risks, frailty models |
| **Bioinformatics** | Sequence alignment, RNA-seq (DESeq2/edgeR), enrichment analysis, variant calling, phylogenetics, proteomics, single-cell |
| **Machine Learning** | Tree methods, SVM, k-NN, neural networks, cross-validation, feature selection, tidymodels/caret pipelines |
| **Clinical Biostatistics** | Trial design (RCT, crossover, adaptive), diagnostic accuracy, ROC analysis, agreement (kappa, ICC, Bland-Altman) |
| **Meta-Analysis** | Fixed/random effects, forest/funnel plots, heterogeneity (I², Q), publication bias, network meta-analysis |
| **Experimental Design** | Randomisation, blocking, factorial designs, split-plot, response surface, optimal design |

## Tutorial Structure (Each Entry)

```
1. Introduction        -- What is this method? When do you need it?
2. Prerequisites       -- What should the reader know beforehand?
3. Theory              -- Mathematical/conceptual background
4. Assumptions         -- What must hold for valid results?
5. R Implementation    -- Step-by-step code with real data
6. Output & Results    -- What R produces and what it means
7. Interpretation      -- How to report results in a manuscript
8. Practical Tips      -- Common pitfalls and best practices
9. R Packages Used     -- Listed in frontmatter for reference
```

## Interactive Shiny Applications

For each of the 16 major topic areas, a **didactic Shiny app** will be built:

- Apps run on a dedicated Shiny Server and are embedded into tutorial pages via iframe
- Each app lets users interactively explore the core concept (e.g., drag a slider to see how sample size affects power, or upload data to run a t-test live)

Example Shiny apps:

- **Power Calculator** -- interactive sample size/power curves for common tests
- **Distribution Explorer** -- visualise and compare probability distributions with adjustable parameters
- **Regression Playground** -- fit models interactively, see diagnostics update in real time
- **PCA Explorer** -- upload data, see biplots and variance explained dynamically
- **Survival Curve Builder** -- interactive Kaplan-Meier with log-rank test
- **RNA-seq Pipeline** -- step-through DESeq2 workflow with live volcano/MA plots

## Technical Stack

| Component | Technology |
|---|---|
| Static site generator | Hugo (v0.159.2) |
| Base theme | Hugo Coder (Go module) |
| Custom theme | Academic (local, in `themes/academic/`) |
| Fonts | Source Sans 3, JetBrains Mono |
| Hosting | GitHub Pages |
| CI/CD | GitHub Actions (auto-deploy on push to main) |
| Tutorial code | R (4.0+) |
| Interactive apps | R Shiny, hosted separately, embedded via iframe |
| Taxonomies | Categories (topic areas), Tags (methods/packages), Series (learning paths) |

## VG Wort Compliance

Every tutorial is written to qualify for VG Wort METIS tracking:

- Minimum 1,800 characters of original text per page (excluding code blocks)
- Each page is a standalone, original work
- Tracking pixels can be added to the Hugo template via a frontmatter field

## Repository Structure

```
tutorials/
├── hugo.toml                     # Site configuration
├── go.mod                        # Hugo module dependencies
├── .github/workflows/deploy.yml  # GitHub Pages deployment
├── archetypes/default.md         # Post template
├── assets/css/custom.css         # Custom CSS overrides
├── static/images/                # SVG assets
├── themes/academic/              # Custom theme (layouts + CSS)
├── content/
│   ├── _index.md                 # Landing page
│   ├── about.md                  # About page
│   └── tutorials/
│       ├── _index.md             # Tutorial overview
│       ├── statistical-foundations/
│       ├── descriptive-statistics/
│       ├── probability/
│       ├── inference/
│       ├── sample-size/
│       ├── visualisation/
│       ├── regression-modelling/
│       ├── multivariate/
│       ├── time-series/
│       ├── bayesian/
│       ├── survival-analysis/
│       ├── bioinformatics/
│       ├── machine-learning/
│       ├── clinical-biostatistics/
│       ├── meta-analysis/
│       └── experimental-design/
    ├── 01-power-calculator.md
    ├── 02-distribution-explorer.md
    ├── ...
```

## Current Status

- **Done**: Full Hugo infrastructure, theme, layouts, CSS, landing page, deploy pipeline
- **Next**: Generate 560+ tutorial markdown files, create Shiny instruction files, commit & push
