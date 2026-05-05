library(shiny)
library(ggplot2)
library(tidymodels)

BUILT_IN <- list(
  "iris (classification)"   = list(data = iris,    outcome = "Species",  mode = "classification"),
  "mtcars (regression)"     = list(data = mtcars,  outcome = "mpg",       mode = "regression"),
  "Pima indians (classif.)" = list(data = MASS::Pima.tr, outcome = "type", mode = "classification")
)

ui <- fluidPage(
  titlePanel("ML Workflow Lab (tidymodels)"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Dataset", names(BUILT_IN)),
      uiOutput("var_ui"),
      selectInput("model", "Model",
                  c("logistic / linear regression",
                    "random forest (ranger)",
                    "gradient boosting (xgboost)",
                    "k-nearest neighbours")),
      sliderInput("v", "Cross-validation folds (v)", 2, 10, 5),
      sliderInput("prop", "Train fraction", 0.5, 0.9, 0.75, step = 0.05),
      actionButton("fit", "Fit model")
    ),
    mainPanel(
      h4("Workflow pseudocode"),
      verbatimTextOutput("code"),
      h4("CV metrics"),
      tableOutput("metrics"),
      h4("Test-set diagnostic"),
      plotOutput("diag", height = "320px")
    )
  )
)

build_recipe <- function(data, outcome, mode) {
  recipe(as.formula(paste(outcome, "~ .")), data = data) |>
    step_normalize(all_numeric_predictors()) |>
    step_dummy(all_nominal_predictors())
}

build_spec <- function(model, mode) {
  switch(model,
    "logistic / linear regression" = {
      if (mode == "classification") logistic_reg() |> set_engine("glm")
      else linear_reg() |> set_engine("lm")
    },
    "random forest (ranger)" = rand_forest(trees = 300) |>
      set_engine("ranger") |> set_mode(mode),
    "gradient boosting (xgboost)" = boost_tree(trees = 200) |>
      set_engine("xgboost") |> set_mode(mode),
    "k-nearest neighbours" = nearest_neighbor(neighbors = 5) |>
      set_engine("kknn") |> set_mode(mode)
  )
}

server <- function(input, output, session) {
  output$var_ui <- renderUI({
    ds <- BUILT_IN[[input$dataset]]
    checkboxGroupInput("pred", "Predictors",
                       setdiff(names(ds$data), ds$outcome),
                       selected = setdiff(names(ds$data), ds$outcome))
  })

  res_r <- eventReactive(input$fit, {
    ds <- BUILT_IN[[input$dataset]]
    d <- ds$data[, c(ds$outcome, input$pred)]
    if (ds$mode == "classification")
      d[[ds$outcome]] <- factor(d[[ds$outcome]])

    set.seed(2026)
    split <- initial_split(d, prop = input$prop,
                            strata = if (ds$mode == "classification")
                                      ds$outcome else NULL)
    train <- training(split); test <- testing(split)
    folds <- vfold_cv(train, v = input$v)

    rec <- build_recipe(train, ds$outcome, ds$mode)
    spec <- build_spec(input$model, ds$mode)
    wf <- workflow() |> add_recipe(rec) |> add_model(spec)

    met <- if (ds$mode == "classification") metric_set(accuracy, roc_auc)
           else metric_set(rmse, rsq, mae)
    cv <- fit_resamples(wf, folds, metrics = met,
                        control = control_resamples(save_pred = TRUE))
    final_fit <- last_fit(wf, split, metrics = met)
    list(cv = cv, final = final_fit, mode = ds$mode,
         outcome = ds$outcome, test = test)
  })

  output$code <- renderText({
    ds <- BUILT_IN[[input$dataset]]
    paste(
      "library(tidymodels)",
      "",
      sprintf("rec <- recipe(%s ~ ., data = train) |>", ds$outcome),
      "  step_normalize(all_numeric_predictors()) |>",
      "  step_dummy(all_nominal_predictors())",
      "",
      sprintf("spec <- %s |> set_mode(\"%s\")",
              switch(input$model,
                "logistic / linear regression" = if (ds$mode == "classification")
                  "logistic_reg()" else "linear_reg()",
                "random forest (ranger)" = "rand_forest(trees = 300) |> set_engine(\"ranger\")",
                "gradient boosting (xgboost)" = "boost_tree(trees = 200) |> set_engine(\"xgboost\")",
                "k-nearest neighbours" = "nearest_neighbor(neighbors = 5) |> set_engine(\"kknn\")"
              ), ds$mode),
      "",
      "wf <- workflow() |> add_recipe(rec) |> add_model(spec)",
      sprintf("folds <- vfold_cv(train, v = %d)", input$v),
      "cv <- fit_resamples(wf, folds)",
      sep = "\n")
  })

  output$metrics <- renderTable({
    r <- res_r()
    collect_metrics(r$cv)
  })

  output$diag <- renderPlot({
    r <- res_r()
    preds <- collect_predictions(r$final)
    if (r$mode == "classification") {
      truth <- preds[[r$outcome]]
      class_probs <- preds[, grepl("^\\.pred_", names(preds)) &
                              !grepl("class$", names(preds))]
      if (nlevels(truth) == 2) {
        roc_auc_col <- names(class_probs)[1]
        ggplot(preds, aes_string(roc_auc_col, fill = r$outcome)) +
          geom_histogram(bins = 30, alpha = 0.6, position = "identity") +
          labs(title = "Predicted-probability distribution by class") +
          theme_minimal()
      } else {
        ggplot(preds, aes_string(".pred_class", fill = r$outcome)) +
          geom_bar(position = "dodge") +
          labs(title = "Confusion by class") + theme_minimal()
      }
    } else {
      ggplot(preds, aes_string(r$outcome, ".pred")) +
        geom_point(alpha = 0.6, colour = "#2A9D8F") +
        geom_abline(linetype = 2) +
        labs(title = "Predicted vs observed") + theme_minimal()
    }
  })
}

shinyApp(ui, server)
