library(shiny)
library(ggplot2)
library(DT)

## Lightweight DE pipeline using edgeR's logic re-implemented in base R
## to avoid Bioconductor dependency at first launch. Users can swap in a
## real DESeq2 / edgeR pipeline by editing `run_de()`.

generate_counts <- function(n_genes = 2000, n_per = 4, seed = 42) {
  set.seed(seed)
  lambda <- rgamma(n_genes, shape = 2, scale = 20)
  de_idx <- sample(n_genes, n_genes * 0.05)
  m <- matrix(rpois(n_genes * (n_per * 2), rep(lambda, n_per * 2)),
              n_genes, n_per * 2)
  m[de_idx, (n_per + 1):(n_per * 2)] <- m[de_idx, (n_per + 1):(n_per * 2)] * 3
  rownames(m) <- sprintf("gene_%04d", seq_len(n_genes))
  colnames(m) <- c(paste0("ctrl", seq_len(n_per)),
                   paste0("trt",  seq_len(n_per)))
  list(counts = m, de_genes = rownames(m)[de_idx])
}

run_de <- function(counts, group) {
  lib_size <- colSums(counts)
  norm_factors <- lib_size / mean(lib_size)
  log_cpm <- log2(t(t(counts + 0.5) / norm_factors) * 1e6 / mean(lib_size) + 1)
  ctrl <- rowMeans(log_cpm[, group == levels(group)[1], drop = FALSE])
  trt  <- rowMeans(log_cpm[, group == levels(group)[2], drop = FALSE])
  logfc <- trt - ctrl
  pooled_sd <- apply(log_cpm, 1, sd)
  t_stat <- logfc / (pooled_sd / sqrt(length(group) / 2))
  p <- 2 * pt(-abs(t_stat), df = length(group) - 2)
  p_adj <- p.adjust(p, method = "BH")
  data.frame(gene = rownames(counts), logFC = logfc,
             pvalue = p, padj = p_adj)
}

ui <- fluidPage(
  titlePanel("RNA-seq Pipeline (lightweight DE)"),
  sidebarLayout(
    sidebarPanel(
      actionButton("generate", "Generate example counts"),
      fileInput("upload_counts", "...or upload counts CSV (genes in rows)",
                accept = ".csv"),
      fileInput("upload_meta", "...and sample metadata CSV (must include 'group')",
                accept = ".csv"),
      hr(),
      sliderInput("fc_cut",  "|log2FC| cutoff", 0, 5, 1, step = 0.1),
      sliderInput("fdr_cut", "FDR cutoff", 0, 0.2, 0.05, step = 0.005)
    ),
    mainPanel(
      plotOutput("pca_plot", height = "260px"),
      plotOutput("volcano", height = "320px"),
      DT::dataTableOutput("top_tbl")
    )
  )
)

server <- function(input, output, session) {
  data_r <- reactiveVal()
  observeEvent(input$generate, {
    data_r(generate_counts())
  })
  observeEvent(input$upload_counts, {
    counts <- as.matrix(read.csv(input$upload_counts$datapath,
                                  row.names = 1, check.names = FALSE))
    data_r(list(counts = counts, de_genes = character()))
  })

  meta_r <- reactive({
    if (!is.null(input$upload_meta)) {
      m <- read.csv(input$upload_meta$datapath)
      factor(m$group)
    } else {
      req(data_r())
      n <- ncol(data_r()$counts)
      factor(c(rep("ctrl", n / 2), rep("trt", n / 2)))
    }
  })

  de_r <- reactive({
    req(data_r()); req(meta_r())
    run_de(data_r()$counts, meta_r())
  })

  output$pca_plot <- renderPlot({
    req(data_r())
    cts <- data_r()$counts
    lcpm <- log2(cts + 1)
    pr <- prcomp(t(lcpm), scale. = TRUE)
    df <- data.frame(PC1 = pr$x[, 1], PC2 = pr$x[, 2],
                     sample = colnames(cts), group = meta_r())
    ggplot(df, aes(PC1, PC2, colour = group, label = sample)) +
      geom_point(size = 3) + geom_text(vjust = -1, size = 3) +
      scale_colour_manual(values = c("#264653", "#E76F51")) +
      labs(title = "Sample PCA (log-CPM)") + theme_minimal()
  })

  output$volcano <- renderPlot({
    r <- de_r()
    r$sig <- with(r, ifelse(padj < input$fdr_cut & abs(logFC) > input$fc_cut,
                             ifelse(logFC > 0, "up", "down"), "ns"))
    ggplot(r, aes(logFC, -log10(padj), colour = sig)) +
      geom_point(alpha = 0.5) +
      geom_vline(xintercept = c(-input$fc_cut, input$fc_cut), linetype = 2) +
      geom_hline(yintercept = -log10(input$fdr_cut), linetype = 2) +
      scale_colour_manual(values = c(up = "#E76F51", down = "#2A9D8F",
                                      ns = "grey70")) +
      labs(title = "Volcano plot") + theme_minimal()
  })

  output$top_tbl <- DT::renderDataTable({
    r <- de_r()
    r <- r[order(r$padj), ]
    head(r, 50)
  })
}

shinyApp(ui, server)
