library(shiny)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Hypothesis Test Simulator"),
  sidebarLayout(
    sidebarPanel(
      selectInput("test", "Test type",
                  c("one-sample t", "two-sample t",
                    "one-proportion z", "two-proportion z",
                    "correlation")),
      sliderInput("alpha", "Significance level alpha", 0.001, 0.2, 0.05,
                  step = 0.005),
      selectInput("alt", "Alternative",
                  c("two.sided", "greater", "less")),
      sliderInput("effect", "True effect (delta, p - p0, r)",
                  -2, 2, 0.4, step = 0.05),
      sliderInput("n", "Sample size per group", 10, 500, 50),
      sliderInput("nsim", "Number of simulations", 100, 10000, 2000,
                  step = 100),
      actionButton("run", "Run simulation")
    ),
    mainPanel(
      plotOutput("dists", height = "300px"),
      plotOutput("hist_p", height = "260px"),
      tableOutput("summary")
    )
  )
)

simulate_test <- function(test, alt, effect, n, nsim, alpha) {
  pvals <- numeric(nsim)
  for (i in seq_len(nsim)) {
    pvals[i] <- switch(test,
      "one-sample t" = {
        x <- rnorm(n, mean = effect, sd = 1)
        t.test(x, mu = 0, alternative = alt)$p.value
      },
      "two-sample t" = {
        x <- rnorm(n, mean = 0, sd = 1)
        y <- rnorm(n, mean = effect, sd = 1)
        t.test(x, y, alternative = alt)$p.value
      },
      "one-proportion z" = {
        x <- rbinom(1, n, 0.5 + effect * 0.1)
        prop.test(x, n, p = 0.5,
                  alternative = alt, correct = FALSE)$p.value
      },
      "two-proportion z" = {
        p1 <- 0.5; p2 <- 0.5 + effect * 0.1
        x1 <- rbinom(1, n, p1); x2 <- rbinom(1, n, p2)
        prop.test(c(x1, x2), c(n, n),
                  alternative = alt, correct = FALSE)$p.value
      },
      "correlation" = {
        z <- rnorm(n)
        x <- z; y <- effect * z + sqrt(1 - effect^2) * rnorm(n)
        cor.test(x, y, alternative = alt)$p.value
      }
    )
  }
  pvals
}

server <- function(input, output, session) {
  sim <- eventReactive(input$run, {
    simulate_test(input$test, input$alt, input$effect, input$n,
                  input$nsim, input$alpha)
  }, ignoreNULL = FALSE)

  output$dists <- renderPlot({
    xs <- seq(-5, 5, length.out = 400)
    df <- data.frame(
      x = rep(xs, 2),
      density = c(dnorm(xs), dnorm(xs, mean = input$effect * sqrt(input$n) / 2)),
      hypothesis = rep(c("Null", "Alternative"), each = length(xs))
    )
    crit <- qnorm(1 - input$alpha / 2)
    ggplot(df, aes(x, density, colour = hypothesis, fill = hypothesis)) +
      geom_area(position = "identity", alpha = 0.25) +
      geom_line(linewidth = 1) +
      geom_vline(xintercept = c(-crit, crit), linetype = 2, colour = "#E76F51") +
      scale_colour_manual(values = c(Null = "#264653", Alternative = "#2A9D8F")) +
      scale_fill_manual(values = c(Null = "#264653", Alternative = "#2A9D8F")) +
      labs(title = "Null vs alternative (schematic, z-scale)",
           x = "test statistic", y = "density") +
      theme_minimal()
  })

  output$hist_p <- renderPlot({
    pv <- sim()
    ggplot(data.frame(p = pv), aes(p)) +
      geom_histogram(bins = 30, fill = "#E9C46A", colour = "white") +
      geom_vline(xintercept = input$alpha, linetype = 2, colour = "#E76F51") +
      labs(title = "Distribution of p-values across simulations",
           x = "p-value", y = "count") +
      theme_minimal()
  })

  output$summary <- renderTable({
    pv <- sim()
    data.frame(
      quantity = c("Simulations", "Rejections at alpha", "Empirical power",
                   "Median p-value"),
      value = c(length(pv),
                sum(pv < input$alpha),
                round(mean(pv < input$alpha), 3),
                round(median(pv), 3))
    )
  })
}

shinyApp(ui, server)
