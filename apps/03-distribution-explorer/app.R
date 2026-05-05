library(shiny)
library(ggplot2)

DIST_SPEC <- list(
  "Normal" = list(
    params = c("mean" = 0, "sd" = 1),
    range = c(-5, 5),
    d = function(x, p) dnorm(x, p$mean, p$sd),
    p = function(q, p) pnorm(q, p$mean, p$sd),
    q = function(pr, p) qnorm(pr, p$mean, p$sd),
    r = function(n, p) rnorm(n, p$mean, p$sd),
    continuous = TRUE
  ),
  "Exponential" = list(
    params = c("rate" = 1),
    range = c(0, 8),
    d = function(x, p) dexp(x, p$rate),
    p = function(q, p) pexp(q, p$rate),
    q = function(pr, p) qexp(pr, p$rate),
    r = function(n, p) rexp(n, p$rate),
    continuous = TRUE
  ),
  "Gamma" = list(
    params = c("shape" = 2, "rate" = 1),
    range = c(0, 15),
    d = function(x, p) dgamma(x, p$shape, p$rate),
    p = function(q, p) pgamma(q, p$shape, p$rate),
    q = function(pr, p) qgamma(pr, p$shape, p$rate),
    r = function(n, p) rgamma(n, p$shape, p$rate),
    continuous = TRUE
  ),
  "Beta" = list(
    params = c("shape1" = 2, "shape2" = 5),
    range = c(0, 1),
    d = function(x, p) dbeta(x, p$shape1, p$shape2),
    p = function(q, p) pbeta(q, p$shape1, p$shape2),
    q = function(pr, p) qbeta(pr, p$shape1, p$shape2),
    r = function(n, p) rbeta(n, p$shape1, p$shape2),
    continuous = TRUE
  ),
  "Student-t" = list(
    params = c("df" = 5),
    range = c(-6, 6),
    d = function(x, p) dt(x, p$df),
    p = function(q, p) pt(q, p$df),
    q = function(pr, p) qt(pr, p$df),
    r = function(n, p) rt(n, p$df),
    continuous = TRUE
  ),
  "Binomial" = list(
    params = c("size" = 20, "prob" = 0.3),
    range = c(0, 20),
    d = function(x, p) dbinom(round(x), p$size, p$prob),
    p = function(q, p) pbinom(q, p$size, p$prob),
    q = function(pr, p) qbinom(pr, p$size, p$prob),
    r = function(n, p) rbinom(n, p$size, p$prob),
    continuous = FALSE
  ),
  "Poisson" = list(
    params = c("lambda" = 3),
    range = c(0, 20),
    d = function(x, p) dpois(round(x), p$lambda),
    p = function(q, p) ppois(q, p$lambda),
    q = function(pr, p) qpois(pr, p$lambda),
    r = function(n, p) rpois(n, p$lambda),
    continuous = FALSE
  )
)

ui <- fluidPage(
  titlePanel("Distribution Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dist", "Distribution family", names(DIST_SPEC)),
      uiOutput("param_ui"),
      sliderInput("qprob", "Quantile probability", 0, 1, 0.975, step = 0.005),
      numericInput("xval", "Probability at X <= x", 1.96),
      hr(),
      sliderInput("nsim", "Simulation size", 10, 10000, 1000, step = 10),
      actionButton("resim", "Resample")
    ),
    mainPanel(
      plotOutput("pdf", height = "250px"),
      plotOutput("cdf", height = "250px"),
      plotOutput("hist", height = "250px"),
      tableOutput("info")
    )
  )
)

server <- function(input, output, session) {
  output$param_ui <- renderUI({
    spec <- DIST_SPEC[[input$dist]]
    par_inputs <- lapply(names(spec$params), function(nm) {
      numericInput(paste0("param_", nm), nm, spec$params[[nm]])
    })
    do.call(tagList, par_inputs)
  })

  current_params <- reactive({
    spec <- DIST_SPEC[[input$dist]]
    as.list(setNames(
      sapply(names(spec$params),
             function(nm) input[[paste0("param_", nm)]]),
      names(spec$params)
    ))
  })

  sim <- reactive({
    input$resim
    spec <- DIST_SPEC[[input$dist]]
    spec$r(input$nsim, current_params())
  })

  output$pdf <- renderPlot({
    spec <- DIST_SPEC[[input$dist]]
    p <- current_params()
    req(all(!sapply(p, is.null)))
    xs <- if (spec$continuous) seq(spec$range[1], spec$range[2], length.out = 400)
          else seq(spec$range[1], spec$range[2], by = 1)
    df <- data.frame(x = xs, y = spec$d(xs, p))
    ggplot(df, aes(x, y)) +
      (if (spec$continuous) geom_line(linewidth = 1, colour = "#2A9D8F")
       else geom_col(fill = "#2A9D8F")) +
      labs(title = "Density / PMF", x = "x", y = if (spec$continuous) "f(x)" else "P(X = x)") +
      theme_minimal()
  })

  output$cdf <- renderPlot({
    spec <- DIST_SPEC[[input$dist]]
    p <- current_params()
    req(all(!sapply(p, is.null)))
    xs <- seq(spec$range[1], spec$range[2], length.out = 400)
    df <- data.frame(x = xs, y = spec$p(xs, p))
    ggplot(df, aes(x, y)) +
      geom_step(linewidth = 1, colour = "#264653") +
      geom_hline(yintercept = input$qprob, linetype = 2, colour = "#E76F51") +
      labs(title = "CDF", x = "x", y = "F(x)") +
      theme_minimal()
  })

  output$hist <- renderPlot({
    ggplot(data.frame(x = sim()), aes(x)) +
      geom_histogram(bins = 60, fill = "#E9C46A", colour = "white") +
      labs(title = "Simulated sample", x = "x", y = "count") +
      theme_minimal()
  })

  output$info <- renderTable({
    spec <- DIST_SPEC[[input$dist]]
    p <- current_params()
    req(all(!sapply(p, is.null)))
    data.frame(
      quantity = c(sprintf("F^-1(%.3f)", input$qprob),
                   sprintf("F(%.3f)", input$xval),
                   "simulated mean", "simulated SD"),
      value = c(round(spec$q(input$qprob, p), 4),
                round(spec$p(input$xval, p), 4),
                round(mean(sim()), 4),
                round(sd(sim()), 4))
    )
  })
}

shinyApp(ui, server)
