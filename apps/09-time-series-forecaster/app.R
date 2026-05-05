library(shiny)
library(ggplot2)
library(forecast)

BUILT_IN <- list(
  "AirPassengers" = AirPassengers,
  "USAccDeaths"   = USAccDeaths,
  "co2"           = co2,
  "nottem"        = nottem
)

ui <- fluidPage(
  titlePanel("Time-Series Forecaster"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Built-in series", names(BUILT_IN)),
      fileInput("upload", "...or upload a CSV (single column)", accept = ".csv"),
      numericInput("freq", "Frequency (for uploads)", 12),
      selectInput("model", "Model family",
                  c("auto.arima", "ETS", "naive", "seasonal naive",
                    "STL + ARIMA")),
      sliderInput("h", "Forecast horizon (periods)", 1, 48, 12),
      sliderInput("holdout_frac", "Hold-out fraction", 0, 0.5, 0.2,
                  step = 0.05),
      actionButton("fit", "Fit")
    ),
    mainPanel(
      plotOutput("series_plot", height = "340px"),
      plotOutput("residuals", height = "280px"),
      tableOutput("metrics")
    )
  )
)

get_series <- function(input) {
  if (!is.null(input$upload)) {
    df <- read.csv(input$upload$datapath)
    ts(df[[1]], frequency = input$freq)
  } else BUILT_IN[[input$dataset]]
}

server <- function(input, output, session) {
  series_r <- reactive({ req(input$dataset); get_series(input) })

  fit_r <- eventReactive(input$fit, {
    x <- series_r()
    n <- length(x); n_test <- max(1, floor(n * input$holdout_frac))
    n_train <- n - n_test
    train <- window(x, end = time(x)[n_train])
    test <- window(x, start = time(x)[n_train + 1])

    mdl <- switch(input$model,
      "auto.arima"      = auto.arima(train),
      "ETS"             = ets(train),
      "naive"           = naive(train, h = n_test + input$h),
      "seasonal naive"  = snaive(train, h = n_test + input$h),
      "STL + ARIMA"     = stlf(train, method = "arima",
                               h = n_test + input$h)
    )
    fc <- if (inherits(mdl, "forecast")) mdl else forecast(mdl, h = n_test + input$h)
    list(train = train, test = test, fc = fc, mdl = mdl)
  })

  output$series_plot <- renderPlot({
    r <- fit_r()
    autoplot(r$fc) +
      autolayer(r$test, series = "hold-out") +
      labs(title = "Series with hold-out and forecast",
           x = NULL, y = NULL) +
      theme_minimal()
  })

  output$residuals <- renderPlot({
    r <- fit_r()
    checkresiduals(r$fc, plot = TRUE)
  })

  output$metrics <- renderTable({
    r <- fit_r()
    test_h <- length(r$test)
    if (test_h >= 1) {
      fc_test <- head(r$fc$mean, test_h)
      acc <- accuracy(fc_test, r$test)
      as.data.frame(acc)
    } else data.frame()
  }, rownames = TRUE)
}

shinyApp(ui, server)
