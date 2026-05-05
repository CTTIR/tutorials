library(shiny)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Bayesian Updater"),
  sidebarLayout(
    sidebarPanel(
      selectInput("pair", "Conjugate pair",
                  c("beta-binomial",
                    "normal-normal (known variance)",
                    "gamma-Poisson")),
      hr(),
      h4("Prior"),
      uiOutput("prior_ui"),
      hr(),
      h4("Data"),
      uiOutput("data_ui"),
      hr(),
      checkboxInput("sequential", "Sequential update (one datum at a time)", FALSE),
      conditionalPanel("input.sequential",
                       sliderInput("step", "Step", 1, 50, 1))
    ),
    mainPanel(
      plotOutput("plot", height = "380px"),
      tableOutput("summary")
    )
  )
)

server <- function(input, output, session) {
  output$prior_ui <- renderUI({
    switch(input$pair,
      "beta-binomial" = tagList(
        numericInput("prior_a", "alpha", 2),
        numericInput("prior_b", "beta", 2)
      ),
      "normal-normal (known variance)" = tagList(
        numericInput("prior_mu", "prior mean mu0", 0),
        numericInput("prior_tau", "prior SD tau0", 1),
        numericInput("data_sigma", "known SD sigma", 1)
      ),
      "gamma-Poisson" = tagList(
        numericInput("prior_shape", "shape (alpha)", 2),
        numericInput("prior_rate",  "rate (beta)", 1)
      )
    )
  })

  output$data_ui <- renderUI({
    switch(input$pair,
      "beta-binomial" = tagList(
        numericInput("successes", "observed successes", 7),
        numericInput("trials",   "observed trials", 10)
      ),
      "normal-normal (known variance)" = tagList(
        textInput("obs_vec", "observations (comma-separated)",
                  "1.2, 0.8, 1.5, 0.9, 1.1")
      ),
      "gamma-Poisson" = tagList(
        textInput("obs_pois", "counts (comma-separated)",
                  "2, 5, 3, 4, 6"),
        numericInput("exposure", "total exposure (if applicable)", 1)
      )
    )
  })

  posterior <- reactive({
    switch(input$pair,
      "beta-binomial" = {
        s <- input$successes; n <- input$trials
        if (input$sequential) {
          step <- min(input$step, n)
          s_now <- round(s * step / n)
          list(type = "beta", alpha = input$prior_a + s_now,
               beta = input$prior_b + (step - s_now))
        } else {
          list(type = "beta", alpha = input$prior_a + s,
               beta = input$prior_b + (n - s))
        }
      },
      "normal-normal (known variance)" = {
        xs <- as.numeric(strsplit(input$obs_vec, ",")[[1]])
        if (input$sequential) xs <- xs[1:min(input$step, length(xs))]
        n <- length(xs); xbar <- mean(xs)
        mu0 <- input$prior_mu; tau0 <- input$prior_tau
        sig <- input$data_sigma
        var_post <- 1 / (1 / tau0^2 + n / sig^2)
        mu_post <- var_post * (mu0 / tau0^2 + n * xbar / sig^2)
        list(type = "normal", mu = mu_post, sd = sqrt(var_post),
             n = n, xbar = xbar)
      },
      "gamma-Poisson" = {
        ks <- as.numeric(strsplit(input$obs_pois, ",")[[1]])
        if (input$sequential) ks <- ks[1:min(input$step, length(ks))]
        list(type = "gamma",
             shape = input$prior_shape + sum(ks),
             rate  = input$prior_rate + length(ks))
      }
    )
  })

  output$plot <- renderPlot({
    p <- posterior()
    xs <- switch(p$type,
      beta = seq(0.001, 0.999, length.out = 300),
      normal = seq(p$mu - 4 * p$sd, p$mu + 4 * p$sd, length.out = 300),
      gamma = seq(0.001, qgamma(0.999, p$shape, p$rate), length.out = 300))

    prior_dens <- switch(p$type,
      beta = dbeta(xs, input$prior_a, input$prior_b),
      normal = dnorm(xs, input$prior_mu, input$prior_tau),
      gamma = dgamma(xs, input$prior_shape, input$prior_rate))

    post_dens <- switch(p$type,
      beta = dbeta(xs, p$alpha, p$beta),
      normal = dnorm(xs, p$mu, p$sd),
      gamma = dgamma(xs, p$shape, p$rate))

    df <- rbind(
      data.frame(x = xs, dens = prior_dens, curve = "prior"),
      data.frame(x = xs, dens = post_dens,  curve = "posterior")
    )
    ggplot(df, aes(x, dens, colour = curve, linetype = curve)) +
      geom_line(linewidth = 1) +
      scale_colour_manual(values = c(prior = "#264653",
                                      posterior = "#E76F51")) +
      scale_linetype_manual(values = c(prior = "dashed",
                                        posterior = "solid")) +
      labs(title = "Prior and posterior", x = "parameter", y = "density") +
      theme_minimal()
  })

  output$summary <- renderTable({
    p <- posterior()
    switch(p$type,
      beta   = data.frame(
        quantity = c("posterior alpha", "posterior beta",
                     "posterior mean", "95% CrI low", "95% CrI high"),
        value = c(p$alpha, p$beta,
                  round(p$alpha / (p$alpha + p$beta), 4),
                  round(qbeta(0.025, p$alpha, p$beta), 4),
                  round(qbeta(0.975, p$alpha, p$beta), 4))),
      normal = data.frame(
        quantity = c("posterior mean", "posterior SD",
                     "95% CrI low", "95% CrI high"),
        value = c(round(p$mu, 4), round(p$sd, 4),
                  round(qnorm(0.025, p$mu, p$sd), 4),
                  round(qnorm(0.975, p$mu, p$sd), 4))),
      gamma  = data.frame(
        quantity = c("shape", "rate", "posterior mean", "95% CrI low",
                     "95% CrI high"),
        value = c(p$shape, p$rate, round(p$shape / p$rate, 4),
                  round(qgamma(0.025, p$shape, p$rate), 4),
                  round(qgamma(0.975, p$shape, p$rate), 4)))
    )
  })
}

shinyApp(ui, server)
