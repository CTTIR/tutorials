# Diagnostic Accuracy Calculator

Three entry modes: enter a 2x2 table directly, pick a cutoff on a
simulated continuous marker, or upload marker + gold-standard labels.
Reports sensitivity, specificity, PPV, NPV, likelihood ratios, and
accuracy -- with PPV/NPV at user-specified target prevalence.

```r
shiny::runApp("apps/14-diagnostic-accuracy-calculator")
```

Requires: `pROC`.
