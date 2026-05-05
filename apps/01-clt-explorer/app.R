library(shiny)
library(ggplot2)

DISTS <- c("Uniform(0, 1)", "Exponential(rate=1)", "Bimodal normal mix",
           "Cauchy(0, 1)", "Chi-squared(df=3)", "Bernoulli(0.3)")

draw_sample <- function(dist, n) {
  switch(dist,
    "Uniform(0, 1)"         = runif(n),
    "Exponential(rate=1)"   = rexp(n, 1),
    "Bimodal normal mix"    = ifelse(rbinom(n, 1, 0.5) == 1,
                                     rnorm(n, -2, 0.6), rnorm(n, 2, 0.6)),
    "Cauchy(0, 1)"          = rcauchy(n),
    "Chi-squared(df=3)"     = rchisq(n, 3),
    "Bernoulli(0.3)"        = rbinom(n, 1, 0.3)
  )
}

theory <- function(dist) {
  switch(dist,
    "Uniform(0, 1)"         = list(mu = 0.5,  sd = sqrt(1/12)),
    "Exponential(rate=1)"   = list(mu = 1,    sd = 1),
    "Bimodal normal mix"    = list(mu = 0,    sd = sqrt(4 + 0.36)),
    "Cauchy(0, 1)"          = list(mu = NA,   sd = NA),
    "Chi-squared(df=3)"     = list(mu = 3,    sd = sqrt(6)),
    "Bernoulli(0.3)"        = list(mu = 0.3,  sd = sqrt(0.3 * 0.7))
  )
}

stat_fn <- function(name) switch(name,
  "mean" = mean, "median" = median,
  "trimmed mean (10%)" = function(x) mean(x, trim = 0.1),
  "standardised mean" = function(x) (mean(x) - 0) / (sd(x) / sqrt(length(x)))
)

ui <- fluidPage(
  titlePanel("Central Limit Theorem Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dist", "Source distribution", DISTS),
      sliderInput("n", "Sample size n", 1, 500, 30),
      sliderInput("reps", "Number of replicate samples", 100, 20000, 2000,
                  step = 100),
      selectInput("stat", "Statistic",
                  c("mean", "median", "trimmed mean (10%)", "standardised mean")),
      checkboxInput("overlay", "Overlay normal implied by CLT", TRUE),
      actionButton("reshuffle", "Reshuffle")
    ),
    mainPanel(
      plotOutput("raw_plot", height = "200px"),
      plotOutput("samp_plot", height = "260px"),
      plotOutput("qq_plot", height = "260px"),
      tableOutput("summary")
    )
  )
)

server <- function(input, output, session) {
  sims <- reactive({
    input$reshuffle
    set.seed(NULL)
    reps <- replicate(input$reps,
                      stat_fn(input$stat)(draw_sample(input$dist, input$n)))
    reps
  })

  output$raw_plot <- renderPlot({
    x <- draw_sample(input$dist, 5000)
    ggplot(data.frame(x), aes(x)) +
      geom_histogram(bins = 60, fill = "#2A9D8F", colour = "white") +
      labs(title = paste("Source:", input$dist), x = NULL, y = NULL) +
      theme_minimal()
  })

  output$samp_plot <- renderPlot({
    s <- sims()
    df <- data.frame(s)
    p <- ggplot(df, aes(s)) +
      geom_histogram(aes(y = after_stat(density)),
                     bins = 60, fill = "#E9C46A", colour = "white") +
      labs(title = sprintf("Sampling distribution of the %s (n = %d)",
                           input$stat, input$n), x = NULL, y = "density") +
      theme_minimal()
    if (input$overlay) {
      th <- theory(input$dist)
      if (!is.na(th$mu)) {
        mu_samp <- if (input$stat == "standardised mean") 0 else th$mu
        se_samp <- if (input$stat == "standardised mean") 1 else th$sd / sqrt(input$n)
        xs <- seq(min(s), max(s), length.out = 200)
        dens <- dnorm(xs, mu_samp, se_samp)
        p <- p + geom_line(data = data.frame(xs, dens),
                           aes(xs, dens), colour = "#264653", linewidth = 1)
      }
    }
    p
  })

  output$qq_plot <- renderPlot({
    s <- sims()
    ggplot(data.frame(s), aes(sample = s)) +
      stat_qq(colour = "#2A9D8F", alpha = 0.5) +
      stat_qq_line(colour = "#264653") +
      labs(title = "Q-Q vs normal", x = "theoretical", y = "sample") +
      theme_minimal()
  })

  output$summary <- renderTable({
    s <- sims()
    th <- theory(input$dist)
    data.frame(
      quantity = c("simulated mean", "simulated SE",
                   "theoretical mean", "theoretical SE (sigma / sqrt(n))"),
      value = c(round(mean(s), 3),
                round(sd(s), 3),
                if (is.na(th$mu)) "undefined" else round(th$mu, 3),
                if (is.na(th$sd)) "undefined" else round(th$sd / sqrt(input$n), 3))
    )
  })
}

shinyApp(ui, server)
