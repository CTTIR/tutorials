# RNA-seq Pipeline

Lightweight RNA-seq DE explorer. Use the built-in simulated counts or
upload a counts + metadata pair. Produces a sample PCA, a volcano plot
under user-chosen FC and FDR cutoffs, and a sortable top-gene table.

```r
shiny::runApp("apps/12-rnaseq-pipeline")
```

The DE core is a simplified moderated t-test; for production work swap
in `DESeq2` or `edgeR` by replacing the `run_de()` function in `app.R`.
