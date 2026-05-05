library(shiny)
library(survival)
library(survminer)
library(ggplot2)

BUILT_IN <- list(
  "lung"    = survival::lung,
  "ovarian" = survival::ovarian
)

ui <- fluidPage(
  titlePanel("Survival Curve Builder"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Dataset", names(BUILT_IN)),
      fileInput("upload", "...or upload a CSV", accept = ".csv"),
      uiOutput("var_ui"),
      selectInput("model", "Model",
                  c("Kaplan-Meier", "Cox proportional hazards"))
    ),
    mainPanel(
      plotOutput("km_plot", height = "380px"),
      verbatimTextOutput("model_summary"),
      tableOutput("median_tbl")
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
      selectInput("time", "Time variable", cols,
                  selected = grep("time", cols, value = TRUE)[1] %||% cols[1]),
      selectInput("event", "Event (0/1 or status)", cols,
                  selected = grep("status|event", cols, value = TRUE)[1] %||% cols[2]),
      selectInput("group", "Grouping variable (optional)",
                  c(".none" = "", cols), selected = ""),
      conditionalPanel("input.model == 'Cox proportional hazards'",
                       checkboxGroupInput("cov", "Covariates", cols))
    )
  })

  `%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

  surv_r <- reactive({
    d <- data_r(); req(input$time, input$event)
    d <- d[complete.cases(d[, c(input$time, input$event)]), ]
    ev <- d[[input$event]]
    ev <- if (is.logical(ev)) as.numeric(ev) else as.numeric(ev) - min(as.numeric(ev), na.rm = TRUE)
    ev[ev > 0] <- 1
    list(d = d, time = d[[input$time]], event = ev)
  })

  output$km_plot <- renderPlot({
    r <- surv_r()
    if (nzchar(input$group)) {
      fit <- survfit(Surv(time, event) ~ r$d[[input$group]], data = r$d)
      ggsurvplot(fit, data = r$d, risk.table = TRUE, conf.int = TRUE,
                 palette = c("#2A9D8F", "#E76F51", "#264653", "#E9C46A"))$plot +
        labs(title = "Kaplan-Meier by group")
    } else {
      fit <- survfit(Surv(time, event) ~ 1, data = r$d)
      ggsurvplot(fit, data = r$d, risk.table = TRUE, conf.int = TRUE)$plot +
        labs(title = "Kaplan-Meier")
    }
  })

  output$model_summary <- renderPrint({
    r <- surv_r()
    if (input$model == "Cox proportional hazards") {
      cov <- setdiff(input$cov, c(input$time, input$event))
      if (length(cov) == 0) return(cat("Select covariates for Cox model."))
      f <- as.formula(paste("Surv(time, event) ~",
                             paste(cov, collapse = " + ")))
      print(summary(coxph(f, data = cbind(time = r$time, event = r$event, r$d))))
    } else {
      if (nzchar(input$group))
        fit <- survfit(Surv(r$time, r$event) ~ r$d[[input$group]], data = r$d)
      else
        fit <- survfit(Surv(r$time, r$event) ~ 1, data = r$d)
      print(fit)
    }
  })

  output$median_tbl <- renderTable({
    r <- surv_r()
    fit <- if (nzchar(input$group))
      survfit(Surv(r$time, r$event) ~ r$d[[input$group]], data = r$d)
    else survfit(Surv(r$time, r$event) ~ 1, data = r$d)
    s <- summary(fit)$table
    as.data.frame(s)
  }, rownames = TRUE)
}

shinyApp(ui, server)
