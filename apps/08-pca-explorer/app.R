library(shiny)
library(ggplot2)

BUILT_IN <- list(
  "iris"   = iris,
  "mtcars" = mtcars,
  "USArrests" = USArrests
)

ui <- fluidPage(
  titlePanel("PCA Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Dataset", names(BUILT_IN)),
      fileInput("upload", "...or upload a CSV", accept = ".csv"),
      uiOutput("var_ui"),
      checkboxInput("scale", "Scale to unit variance", TRUE),
      sliderInput("pcx", "x-axis component (PC)", 1, 5, 1),
      sliderInput("pcy", "y-axis component (PC)", 1, 5, 2)
    ),
    mainPanel(
      plotOutput("scree", height = "220px"),
      plotOutput("scatter", height = "380px"),
      plotOutput("loadings", height = "260px"),
      tableOutput("var_table")
    )
  )
)

get_data <- function(input) {
  if (!is.null(input$upload)) read.csv(input$upload$datapath)
  else BUILT_IN[[input$dataset]]
}

server <- function(input, output, session) {
  data_r <- reactive({ req(input$dataset); get_data(input) })

  output$var_ui <- renderUI({
    d <- data_r()
    num_cols <- names(d)[sapply(d, is.numeric)]
    chr_cols <- names(d)[!sapply(d, is.numeric)]
    tagList(
      checkboxGroupInput("vars", "Numeric columns", num_cols,
                         selected = num_cols[seq_len(min(6, length(num_cols)))]),
      selectInput("colour", "Colour by (optional)",
                  c(".none" = "", chr_cols))
    )
  })

  pca_r <- reactive({
    d <- data_r(); req(input$vars); req(length(input$vars) >= 2)
    X <- d[, input$vars, drop = FALSE]
    X <- X[complete.cases(X), , drop = FALSE]
    prcomp(X, scale. = input$scale)
  })

  output$scree <- renderPlot({
    pr <- pca_r()
    v <- pr$sdev^2; v <- v / sum(v)
    df <- data.frame(pc = factor(paste0("PC", seq_along(v)),
                                  levels = paste0("PC", seq_along(v))),
                     var = v,
                     cum = cumsum(v))
    ggplot(df, aes(pc, var)) +
      geom_col(fill = "#2A9D8F") +
      geom_line(aes(y = cum, group = 1), colour = "#E76F51", linewidth = 1) +
      geom_point(aes(y = cum), colour = "#E76F51") +
      labs(title = "Scree plot with cumulative variance",
           x = NULL, y = "variance / cumulative") +
      theme_minimal()
  })

  output$scatter <- renderPlot({
    pr <- pca_r(); d <- data_r()
    scores <- as.data.frame(pr$x)
    req(input$pcx <= ncol(scores), input$pcy <= ncol(scores))
    df <- data.frame(x = scores[[input$pcx]], y = scores[[input$pcy]])
    if (nzchar(input$colour))
      df$group <- d[[input$colour]][as.integer(rownames(scores))]
    p <- ggplot(df, aes(x, y)) +
      geom_point(alpha = 0.7, size = 3,
                 aes(colour = if (nzchar(input$colour)) group else NULL)) +
      labs(title = sprintf("PC%d vs PC%d score plot",
                           input$pcx, input$pcy),
           x = sprintf("PC%d", input$pcx),
           y = sprintf("PC%d", input$pcy),
           colour = input$colour) +
      theme_minimal()
    p
  })

  output$loadings <- renderPlot({
    pr <- pca_r()
    L <- as.data.frame(pr$rotation)
    L$var <- rownames(L)
    req(input$pcx <= ncol(L), input$pcy <= ncol(L))
    ggplot(L, aes_string(x = paste0("PC", input$pcx),
                          y = paste0("PC", input$pcy))) +
      geom_segment(aes(xend = 0, yend = 0),
                   arrow = grid::arrow(length = grid::unit(0.15, "cm"),
                                        ends = "first"),
                   colour = "#264653") +
      geom_text(aes(label = var), colour = "#E76F51", size = 4) +
      labs(title = "Loadings biplot") +
      theme_minimal()
  })

  output$var_table <- renderTable({
    pr <- pca_r()
    v <- pr$sdev^2
    data.frame(PC = paste0("PC", seq_along(v)),
               SD = round(pr$sdev, 3),
               `Proportion Var` = round(v / sum(v), 3),
               `Cumulative Var` = round(cumsum(v) / sum(v), 3))
  })
}

shinyApp(ui, server)
