library(shiny)
library(ggplot2)
library(metafor)

DEFAULT_STUDIES <- data.frame(
  study = paste("Study", LETTERS[1:8]),
  yi = c(0.32, 0.51, 0.28, 0.45, 0.38, 0.22, 0.60, 0.35),
  sei = c(0.14, 0.17, 0.12, 0.16, 0.20, 0.13, 0.22, 0.15),
  year = 2010:2017,
  stringsAsFactors = FALSE
)

ui <- fluidPage(
  titlePanel("Forest Plot Builder"),
  sidebarLayout(
    sidebarPanel(
      selectInput("measure", "Effect measure",
                  c("Mean difference" = "MD", "SMD (Hedges' g)" = "SMD",
                    "log Risk Ratio" = "logRR", "log Odds Ratio" = "logOR",
                    "log Hazard Ratio" = "logHR",
                    "Pearson r (Fisher z)" = "ZCOR")),
      fileInput("upload", "Upload CSV (columns: study, yi, sei)",
                accept = ".csv"),
      selectInput("method", "Pooling method",
                  c("Random-effects (REML)" = "REML",
                    "Fixed-effect" = "FE",
                    "DerSimonian-Laird" = "DL")),
      selectInput("order_by", "Order studies by",
                  c("as supplied", "effect size", "year")),
      checkboxInput("knha", "Hartung-Knapp adjustment", TRUE)
    ),
    mainPanel(
      plotOutput("forest", height = "480px"),
      h4("Pooled estimate"),
      verbatimTextOutput("pool_summary"),
      h4("Heterogeneity"),
      tableOutput("het_tbl")
    )
  )
)

server <- function(input, output, session) {
  studies_r <- reactive({
    if (!is.null(input$upload)) {
      d <- read.csv(input$upload$datapath)
      if (!all(c("study", "yi", "sei") %in% names(d)))
        stop("CSV must have columns: study, yi, sei")
      d
    } else DEFAULT_STUDIES
  })

  fit_r <- reactive({
    d <- studies_r()
    if (input$order_by == "effect size") d <- d[order(d$yi), ]
    if (input$order_by == "year" && "year" %in% names(d))
      d <- d[order(d$year), ]
    vi <- d$sei^2
    rma(yi = d$yi, vi = vi, method = input$method,
        test = if (input$knha) "knha" else "z",
        slab = d$study)
  })

  output$forest <- renderPlot({
    res <- fit_r()
    forest(res, header = TRUE,
           xlab = switch(input$measure,
             "MD" = "Mean difference",
             "SMD" = "Hedges' g",
             "logRR" = "log Risk Ratio",
             "logOR" = "log Odds Ratio",
             "logHR" = "log Hazard Ratio",
             "ZCOR" = "Fisher z"))
  })

  output$pool_summary <- renderPrint({
    res <- fit_r()
    cat(sprintf("Pooled estimate: %.3f (95%% CI %.3f-%.3f, p = %.4f)\n",
                res$b, res$ci.lb, res$ci.ub, res$pval))
    if (input$measure %in% c("logRR", "logOR", "logHR"))
      cat(sprintf("Exponentiated: %.3f (%.3f-%.3f)\n",
                  exp(res$b), exp(res$ci.lb), exp(res$ci.ub)))
  })

  output$het_tbl <- renderTable({
    res <- fit_r()
    data.frame(
      quantity = c("tau^2", "I^2 (%)", "Q", "Q p-value"),
      value = c(round(res$tau2, 4), round(res$I2, 1),
                round(res$QE, 2), signif(res$QEp, 3))
    )
  })
}

shinyApp(ui, server)
