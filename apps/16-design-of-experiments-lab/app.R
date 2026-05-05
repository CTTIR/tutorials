library(shiny)
library(ggplot2)
library(FrF2)
library(rsm)
library(DT)

ui <- fluidPage(
  titlePanel("DOE Lab"),
  sidebarLayout(
    sidebarPanel(
      selectInput("family", "Design family",
                  c("Full factorial (2^k)",
                    "Fractional factorial",
                    "Plackett-Burman",
                    "Central Composite (CCD)",
                    "Box-Behnken (BBD)")),
      sliderInput("k", "Number of factors (k)", 2, 7, 3),
      conditionalPanel("input.family == 'Fractional factorial'",
                       sliderInput("resolution", "Resolution", 3, 6, 4),
                       sliderInput("nruns_frac", "Runs", 8, 64, 16, step = 8)),
      conditionalPanel("input.family == 'Plackett-Burman'",
                       selectInput("pb_runs", "Runs", c(8, 12, 16, 20, 24))),
      conditionalPanel("input.family == 'Central Composite (CCD)'",
                       selectInput("alpha_type", "alpha",
                                   c("rotatable", "orthogonal", "faces"))),
      checkboxInput("randomize", "Randomise run order", TRUE),
      actionButton("build", "Build design")
    ),
    mainPanel(
      DT::dataTableOutput("design_tbl"),
      h4("Design diagnostics"),
      verbatimTextOutput("diag"),
      plotOutput("corr_plot", height = "320px")
    )
  )
)

build_design <- function(input) {
  switch(input$family,
    "Full factorial (2^k)" = {
      FrF2(nruns = 2^input$k, nfactors = input$k,
           randomize = input$randomize)
    },
    "Fractional factorial" = {
      FrF2(nruns = input$nruns_frac, nfactors = input$k,
           resolution = input$resolution,
           randomize = input$randomize)
    },
    "Plackett-Burman" = {
      pb(nruns = as.integer(input$pb_runs), nfactors = input$k,
         randomize = input$randomize)
    },
    "Central Composite (CCD)" = {
      fvars <- paste0("x", seq_len(input$k))
      f <- as.formula(paste("~", paste(fvars, collapse = " + ")))
      ccd(f, n0 = c(3, 3),
          alpha = input$alpha_type,
          randomize = input$randomize)
    },
    "Box-Behnken (BBD)" = {
      fvars <- paste0("x", seq_len(input$k))
      f <- as.formula(paste("~", paste(fvars, collapse = " + ")))
      bbd(f, n0 = 3, randomize = input$randomize)
    }
  )
}

server <- function(input, output, session) {
  design_r <- eventReactive(input$build, {
    build_design(input)
  }, ignoreNULL = FALSE)

  output$design_tbl <- DT::renderDataTable({
    d <- design_r()
    DT::datatable(as.data.frame(d),
                  options = list(pageLength = 25))
  })

  output$diag <- renderPrint({
    d <- design_r()
    cat("Runs:", nrow(as.data.frame(d)), "\n")
    cat("Factors:", ncol(as.data.frame(d)), "\n")
    if (inherits(d, "design")) {
      info <- design.info(d)
      cat("Type:", info$type, "\n")
      if (!is.null(info$resolution)) cat("Resolution:", info$resolution, "\n")
      if (!is.null(info$aliased)) {
        cat("\nAliased effects:\n")
        print(info$aliased)
      }
    }
  })

  output$corr_plot <- renderPlot({
    d <- as.data.frame(design_r())
    num_cols <- sapply(d, is.numeric)
    if (sum(num_cols) < 2) return(NULL)
    M <- cor(d[, num_cols, drop = FALSE])
    df <- expand.grid(Var1 = rownames(M), Var2 = colnames(M))
    df$corr <- as.vector(M)
    ggplot(df, aes(Var1, Var2, fill = corr)) +
      geom_tile() +
      scale_fill_gradient2(low = "#2A9D8F", mid = "white",
                            high = "#E76F51", midpoint = 0,
                            limits = c(-1, 1)) +
      labs(title = "Correlation matrix of design columns") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })
}

shinyApp(ui, server)
