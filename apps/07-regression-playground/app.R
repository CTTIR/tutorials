library(shiny)
library(ggplot2)
library(broom)

BUILT_IN <- list(
  "mtcars"     = mtcars,
  "iris"       = iris,
  "diamonds (sampled)" = ggplot2::diamonds[sample(nrow(ggplot2::diamonds), 2000), ]
)

ui <- fluidPage(
  titlePanel("Regression Playground"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Dataset", names(BUILT_IN)),
      fileInput("upload", "...or upload a CSV", accept = ".csv"),
      uiOutput("var_ui"),
      selectInput("family", "Family",
                  c("gaussian (lm)", "binomial (glm)", "poisson (glm)")),
      checkboxInput("interaction", "Include two-way interactions", FALSE),
      checkboxInput("log_y", "Log-transform the outcome", FALSE),
      actionButton("fit", "Fit model")
    ),
    mainPanel(
      h4("Model summary"),
      tableOutput("coef_tbl"),
      h4("Fit statistics"),
      tableOutput("fit_tbl"),
      h4("Diagnostic plots"),
      plotOutput("diag", height = "400px")
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
    d <- data_r(); cols <- names(d)
    tagList(
      selectInput("y", "Outcome", cols, selected = cols[1]),
      checkboxGroupInput("x", "Predictors", cols, selected = cols[-1][1:2])
    )
  })

  model_r <- eventReactive(input$fit, {
    d <- data_r(); req(input$y, input$x)
    lhs <- if (input$log_y) sprintf("log(%s)", input$y) else input$y
    rhs <- if (input$interaction)
      paste("(", paste(input$x, collapse = " + "), ")^2")
    else paste(input$x, collapse = " + ")
    f <- as.formula(paste(lhs, "~", rhs))
    fam <- switch(input$family,
      "gaussian (lm)"   = NULL,
      "binomial (glm)"  = binomial(),
      "poisson (glm)"   = poisson())
    if (is.null(fam)) lm(f, data = d) else glm(f, data = d, family = fam)
  })

  output$coef_tbl <- renderTable({
    req(model_r())
    broom::tidy(model_r(), conf.int = TRUE)
  })

  output$fit_tbl <- renderTable({
    req(model_r())
    broom::glance(model_r())
  })

  output$diag <- renderPlot({
    req(model_r())
    par(mfrow = c(2, 2))
    plot(model_r(), which = 1:4)
  })
}

shinyApp(ui, server)
