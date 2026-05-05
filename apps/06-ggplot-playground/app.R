library(shiny)
library(ggplot2)
library(dplyr)

BUILT_IN <- list(
  "iris"       = iris,
  "mtcars"     = mtcars,
  "diamonds (sampled)" = ggplot2::diamonds[sample(nrow(ggplot2::diamonds), 2000), ],
  "economics"  = ggplot2::economics
)

ui <- fluidPage(
  titlePanel("ggplot2 Playground"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Dataset", names(BUILT_IN)),
      fileInput("upload", "...or upload a CSV", accept = ".csv"),
      uiOutput("var_ui"),
      selectInput("geom", "Geom",
                  c("geom_point", "geom_line", "geom_col", "geom_boxplot",
                    "geom_violin", "geom_histogram", "geom_density",
                    "geom_smooth")),
      selectInput("colour_var", "Colour by", c(".none" = ""), selected = ""),
      selectInput("facet_var", "Facet by", c(".none" = ""), selected = ""),
      selectInput("theme", "Theme",
                  c("theme_minimal", "theme_classic", "theme_bw",
                    "theme_grey", "theme_light")),
      checkboxInput("log_y", "Log scale on y", FALSE),
      checkboxInput("flip", "Flip coordinates", FALSE)
    ),
    mainPanel(
      plotOutput("plot", height = "480px"),
      h4("Generated ggplot2 code"),
      verbatimTextOutput("code")
    )
  )
)

get_data <- function(input) {
  if (!is.null(input$upload)) {
    read.csv(input$upload$datapath)
  } else {
    BUILT_IN[[input$dataset]]
  }
}

server <- function(input, output, session) {
  data_r <- reactive({ req(input$dataset); get_data(input) })

  output$var_ui <- renderUI({
    d <- data_r()
    cols <- names(d)
    tagList(
      selectInput("x", "x", cols, selected = cols[1]),
      selectInput("y", "y (unused for some geoms)", cols,
                  selected = cols[min(2, length(cols))])
    )
  })

  observe({
    d <- data_r()
    updateSelectInput(session, "colour_var",
                      choices = c(".none" = "", names(d)))
    updateSelectInput(session, "facet_var",
                      choices = c(".none" = "", names(d)))
  })

  build_plot <- reactive({
    d <- data_r(); req(input$x, input$y, input$geom)
    aes_args <- list(x = sym(input$x))
    if (input$geom %in% c("geom_point", "geom_line", "geom_col",
                           "geom_boxplot", "geom_violin", "geom_smooth")) {
      aes_args$y <- sym(input$y)
    }
    if (nzchar(input$colour_var)) aes_args$colour <- sym(input$colour_var)
    mapping <- do.call(aes, aes_args)
    p <- ggplot(d, mapping) + get(input$geom)()
    if (nzchar(input$facet_var))
      p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
    p <- p + get(input$theme)()
    if (input$log_y) p <- p + scale_y_log10()
    if (input$flip) p <- p + coord_flip()
    p
  })

  output$plot <- renderPlot({ build_plot() })

  output$code <- renderText({
    req(input$x, input$y)
    aes_bits <- sprintf("x = %s", input$x)
    if (input$geom %in% c("geom_point", "geom_line", "geom_col",
                           "geom_boxplot", "geom_violin", "geom_smooth"))
      aes_bits <- paste0(aes_bits, sprintf(", y = %s", input$y))
    if (nzchar(input$colour_var))
      aes_bits <- paste0(aes_bits, sprintf(", colour = %s", input$colour_var))
    extras <- c()
    if (nzchar(input$facet_var))
      extras <- c(extras, sprintf("facet_wrap(~ %s)", input$facet_var))
    extras <- c(extras, paste0(input$theme, "()"))
    if (input$log_y) extras <- c(extras, "scale_y_log10()")
    if (input$flip)  extras <- c(extras, "coord_flip()")
    body <- paste(c(sprintf("ggplot(data, aes(%s))", aes_bits),
                    paste0(input$geom, "()"),
                    extras), collapse = " +\n  ")
    paste0("library(ggplot2)\n\n", body)
  })
}

shinyApp(ui, server)
