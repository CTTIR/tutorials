library(shiny)
library(ggplot2)
library(pwr)

ui <- fluidPage(
  titlePanel("Power Calculator"),
  sidebarLayout(
    sidebarPanel(
      selectInput("design", "Design family",
                  c("two-sample means (Cohen's d)",
                    "one-sample mean",
                    "two proportions",
                    "correlation (Pearson r)",
                    "one-way ANOVA (Cohen's f)",
                    "linear regression (f^2)")),
      selectInput("solve", "Solve for",
                  c("sample size n", "power", "effect size", "alpha")),
      numericInput("n", "Sample size per group / n", 50),
      numericInput("effect", "Effect size", 0.5),
      numericInput("alpha", "Significance level alpha", 0.05, 0, 1, 0.005),
      numericInput("power", "Power (1 - beta)", 0.80, 0, 1, 0.01),
      selectInput("alt", "Alternative",
                  c("two.sided", "greater", "less")),
      conditionalPanel("input.design == 'one-way ANOVA (Cohen\\'s f)'",
                       numericInput("k_groups", "Number of groups", 3)),
      conditionalPanel("input.design == 'linear regression (f^2)'",
                       numericInput("u_num", "Numerator df (predictors)", 3)),
      actionButton("go", "Calculate")
    ),
    mainPanel(
      verbatimTextOutput("result"),
      plotOutput("curve", height = "300px")
    )
  )
)

do_calc <- function(design, solve, n, effect, alpha, power, alt,
                    k_groups, u_num) {
  args <- list(
    n = if (solve == "sample size n") NULL else n,
    effect = if (solve == "effect size") NULL else effect,
    alpha = if (solve == "alpha") NULL else alpha,
    power = if (solve == "power") NULL else power
  )
  switch(design,
    "two-sample means (Cohen's d)" = pwr.t.test(
      n = args$n, d = args$effect, sig.level = args$alpha,
      power = args$power, type = "two.sample", alternative = alt),
    "one-sample mean" = pwr.t.test(
      n = args$n, d = args$effect, sig.level = args$alpha,
      power = args$power, type = "one.sample", alternative = alt),
    "two proportions" = pwr.2p.test(
      h = args$effect, n = args$n, sig.level = args$alpha,
      power = args$power, alternative = alt),
    "correlation (Pearson r)" = pwr.r.test(
      r = args$effect, n = args$n, sig.level = args$alpha,
      power = args$power, alternative = alt),
    "one-way ANOVA (Cohen's f)" = pwr.anova.test(
      k = k_groups, n = args$n, f = args$effect,
      sig.level = args$alpha, power = args$power),
    "linear regression (f^2)" = pwr.f2.test(
      u = u_num, v = args$n,
      f2 = args$effect, sig.level = args$alpha, power = args$power)
  )
}

server <- function(input, output, session) {
  res <- eventReactive(input$go, {
    tryCatch(do_calc(input$design, input$solve, input$n, input$effect,
                     input$alpha, input$power, input$alt,
                     input$k_groups, input$u_num),
             error = function(e) e)
  })

  output$result <- renderPrint({
    r <- res()
    if (inherits(r, "error")) cat("Error:", r$message, "\n") else print(r)
  })

  output$curve <- renderPlot({
    ns <- seq(5, 500, by = 5)
    pwrs <- sapply(ns, function(n) {
      tryCatch(switch(input$design,
        "two-sample means (Cohen's d)" = pwr.t.test(
          n = n, d = input$effect, sig.level = input$alpha,
          type = "two.sample", alternative = input$alt)$power,
        "one-sample mean" = pwr.t.test(
          n = n, d = input$effect, sig.level = input$alpha,
          type = "one.sample", alternative = input$alt)$power,
        "two proportions" = pwr.2p.test(
          h = input$effect, n = n, sig.level = input$alpha,
          alternative = input$alt)$power,
        "correlation (Pearson r)" = pwr.r.test(
          r = input$effect, n = n, sig.level = input$alpha,
          alternative = input$alt)$power,
        "one-way ANOVA (Cohen's f)" = pwr.anova.test(
          k = input$k_groups, n = n, f = input$effect,
          sig.level = input$alpha)$power,
        "linear regression (f^2)" = pwr.f2.test(
          u = input$u_num, v = n, f2 = input$effect,
          sig.level = input$alpha)$power
      ), error = function(e) NA)
    })
    df <- data.frame(n = ns, power = pwrs)
    ggplot(df, aes(n, power)) +
      geom_line(linewidth = 1, colour = "#2A9D8F") +
      geom_hline(yintercept = 0.80, linetype = 2, colour = "#E76F51") +
      labs(title = "Power curve", x = "n", y = "power") +
      theme_minimal() + ylim(0, 1)
  })
}

shinyApp(ui, server)
