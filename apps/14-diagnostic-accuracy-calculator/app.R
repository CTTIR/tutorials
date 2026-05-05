library(shiny)
library(ggplot2)
library(pROC)

ui <- fluidPage(
  titlePanel("Diagnostic Accuracy Calculator"),
  sidebarLayout(
    sidebarPanel(
      radioButtons("mode", "Mode",
                   c("2x2 table", "continuous marker with cutoff",
                     "upload marker + label")),
      conditionalPanel("input.mode == '2x2 table'",
                       numericInput("TP", "True positives",  85),
                       numericInput("FN", "False negatives", 15),
                       numericInput("FP", "False positives", 10),
                       numericInput("TN", "True negatives",  90),
                       numericInput("prev", "Target prevalence (optional)", 0.1,
                                    min = 0, max = 1, step = 0.01)),
      conditionalPanel("input.mode == 'continuous marker with cutoff'",
                       sliderInput("cutoff", "Cutoff", -4, 4, 0, step = 0.05),
                       actionButton("resim", "Resample marker data")),
      conditionalPanel("input.mode == 'upload marker + label'",
                       fileInput("upload", "CSV with columns 'marker' and 'label' (0/1)",
                                 accept = ".csv"))
    ),
    mainPanel(
      plotOutput("plot", height = "360px"),
      tableOutput("accuracy_tbl")
    )
  )
)

server <- function(input, output, session) {
  data_r <- reactiveVal(NULL)

  observe({
    if (input$mode == "continuous marker with cutoff") {
      input$resim
      set.seed(NULL)
      n_pos <- 150; n_neg <- 200
      marker <- c(rnorm(n_neg, 0, 1), rnorm(n_pos, 1.3, 1))
      label <- c(rep(0, n_neg), rep(1, n_pos))
      data_r(data.frame(marker, label))
    } else if (input$mode == "upload marker + label" && !is.null(input$upload)) {
      data_r(read.csv(input$upload$datapath))
    }
  })

  compute_2x2 <- reactive({
    switch(input$mode,
      "2x2 table" = list(TP = input$TP, FN = input$FN,
                         FP = input$FP, TN = input$TN),
      {
        df <- data_r(); req(df); req(input$cutoff)
        pred_pos <- df$marker >= input$cutoff
        list(TP = sum(pred_pos & df$label == 1),
             FN = sum(!pred_pos & df$label == 1),
             FP = sum(pred_pos & df$label == 0),
             TN = sum(!pred_pos & df$label == 0))
      }
    )
  })

  accuracy_metrics <- reactive({
    t <- compute_2x2()
    n <- with(t, TP + FN + FP + TN)
    sens <- with(t, TP / (TP + FN)); spec <- with(t, TN / (TN + FP))
    ppv <- with(t, TP / (TP + FP));  npv <- with(t, TN / (TN + FN))
    lr_pos <- sens / (1 - spec);      lr_neg <- (1 - sens) / spec
    acc <- with(t, (TP + TN) / n)
    youden <- sens + spec - 1
    data.frame(
      metric = c("Sensitivity", "Specificity", "PPV", "NPV",
                 "LR+", "LR-", "Accuracy", "Youden's J"),
      value = round(c(sens, spec, ppv, npv, lr_pos, lr_neg, acc, youden), 4)
    )
  })

  output$plot <- renderPlot({
    if (input$mode == "2x2 table") {
      t <- compute_2x2()
      df <- data.frame(
        truth = rep(c("Disease", "No disease"), 2),
        test = rep(c("+", "-"), each = 2),
        count = c(t$TP, t$FP, t$FN, t$TN)
      )
      ggplot(df, aes(truth, test, fill = count)) +
        geom_tile() + geom_text(aes(label = count), size = 8) +
        scale_fill_gradient(low = "#E9C46A", high = "#2A9D8F") +
        labs(title = "2x2 table heatmap") + theme_minimal()
    } else {
      df <- data_r(); req(df)
      ggplot(df, aes(marker, fill = factor(label))) +
        geom_density(alpha = 0.5) +
        geom_vline(xintercept = input$cutoff, linetype = 2, colour = "#E76F51") +
        scale_fill_manual(values = c("0" = "#264653", "1" = "#2A9D8F")) +
        labs(title = "Marker density by disease status",
             x = "marker", fill = "disease") +
        theme_minimal()
    }
  })

  output$accuracy_tbl <- renderTable({
    m <- accuracy_metrics()
    if (input$mode == "2x2 table" && !is.na(input$prev) && input$prev > 0) {
      sens <- m$value[m$metric == "Sensitivity"]
      spec <- m$value[m$metric == "Specificity"]
      p <- input$prev
      ppv_p <- sens * p / (sens * p + (1 - spec) * (1 - p))
      npv_p <- spec * (1 - p) / ((1 - sens) * p + spec * (1 - p))
      m <- rbind(m,
                 data.frame(metric = sprintf("PPV at prev %.2f", p),
                            value = round(ppv_p, 4)),
                 data.frame(metric = sprintf("NPV at prev %.2f", p),
                            value = round(npv_p, 4)))
    }
    m
  })
}

shinyApp(ui, server)
