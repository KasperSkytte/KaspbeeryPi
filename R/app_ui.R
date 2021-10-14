#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import shinyMobile
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    f7Page(
      title = "test",
      f7TabLayout(
        navbar = f7Navbar(
          title = "KaspbeeryPi"
        ),
        f7Tabs(
          animated = TRUE,
          id = "tabs",
          f7Tab(
            tabName = "Options",
            icon = f7Icon("slider_horizontal_3"),
            uiOutput("brew"),
            uiOutput("sensor"),
            f7Slider(
              inputId = "timeinterval",
              label = "Interval (WIP)",
              value = 1,
              min = 1,
              max = 10
            )
          ),
          f7Tab(
            tabName = "Graphs",
            icon = f7Icon("graph_square"),
            active = TRUE,
            uiOutput("plot"),
            f7Toggle(
              inputId = "plot_type",
              label = "Interactive plot (dygraphs)",
              checked = FALSE
            )
          ),
          f7Tab(
            tabName = "Fermentation",
            icon = f7Icon("table"),
            verbatimTextOutput("fermentationInfo"),
            tableOutput("temperaturesInfo")
          ),
          f7Tab(
            tabName = "Tools",
            icon = f7Icon("wrench"),
            uiOutput("abvui"),
            tags$hr(),
            tags$b("Result:"),
            p(textOutput("abvres", inline = TRUE), "%")
          )
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www", app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "kaspbeerypi"
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
