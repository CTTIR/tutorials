library(shiny)
library(ggplot2)

summary_tbl <- function(x) {
  if (length(x) == 0) {
    return(data.frame(statistic = character(), value = character()))
  }
  skew <- if (length(x) >= 3) mean((x - mean(x))^3) / sd(x)^3 else NA
  kurt <- if (length(x) >= 4) mean((x - mean(x))^4) / sd(x)^4 - 3 else NA
  data.frame(
    statistic = c("n", "mean", "median", "trimmed mean (10%)",
                  "SD", "MAD", "IQR", "skewness", "excess kurtosis",
                  "min", "max"),
    value = c(length(x),
              round(mean(x), 3),
              round(median(x), 3),
              round(mean(x, trim = 0.1), 3),
              round(sd(x), 3),
              round(mad(x), 3),
              round(IQR(x), 3),
              round(skew, 3),
              round(kurt, 3),
              round(min(x), 3),
              round(max(x), 3))
  )
}

ui <- fluidPage(
  titlePanel("Summary Statistics Lab"),
  sidebarLayout(
    sidebarPanel(
      helpText("Click on the plot to add a point; the table updates live."),
      actionButton("reset", "Reset"),
      actionButton("add_outlier", "Add an outlier at x = 10"),
      actionButton("gen_random", "Generate 30 random points"),
      hr(),
      checkboxInput("trimmed", "Highlight trimmed region (10%)", FALSE)
    ),
    mainPanel(
      plotOutput("strip", click = "plot_click", height = "250px"),
      tableOutput("summary")
    )
  )
)

server <- function(input, output, session) {
  vals <- reactiveVal(rnorm(15, 5, 1.5))

  observeEvent(input$plot_click, {
    vals(c(vals(), input$plot_click$x))
  })

  observeEvent(input$reset, vals(numeric(0)))
  observeEvent(input$add_outlier, vals(c(vals(), 10)))
  observeEvent(input$gen_random, vals(rnorm(30, 5, 1.5)))

  output$strip <- renderPlot({
    x <- vals()
    if (length(x) == 0) {
      ggplot() + xlim(0, 10) + ylim(-0.5, 0.5) +
        labs(title = "Click to add points", x = "x", y = NULL) +
        theme_minimal()
    } else {
      df <- data.frame(x, y = 0)
      p <- ggplot(df, aes(x, y)) +
        geom_point(size = 4, colour = "#2A9D8F", alpha = 0.7) +
        geom_vline(xintercept = mean(x), colour = "#E76F51",
                   linewidth = 1) +
        geom_vline(xintercept = median(x), colour = "#264653",
                   linewidth = 1, linetype = 2) +
        annotate("text", x = mean(x), y = 0.35,
                 label = "mean", colour = "#E76F51") +
        annotate("text", x = median(x), y = -0.35,
                 label = "median", colour = "#264653") +
        xlim(min(c(x, 0)) - 1, max(c(x, 10)) + 1) +
        ylim(-0.5, 0.5) +
        labs(x = "x", y = NULL) +
        theme_minimal() +
        theme(axis.text.y = element_blank())
      if (input$trimmed) {
        trim_lo <- quantile(x, 0.10)
        trim_hi <- quantile(x, 0.90)
        p <- p + annotate("rect", xmin = trim_lo, xmax = trim_hi,
                          ymin = -0.1, ymax = 0.1,
                          alpha = 0.12, fill = "#E9C46A")
      }
      p
    }
  })

  output$summary <- renderTable(summary_tbl(vals()))
}

shinyApp(ui, server)
