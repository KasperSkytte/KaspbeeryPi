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
      allowPWA = TRUE,
      title = "KaspbeeryPi",
      f7TabLayout(
        navbar = f7Navbar(
          title = "KaspbeeryPi"
        ),
        f7Tabs(
          animated = TRUE,
          id = "tabs",
          f7Tab(
            tabName = "Timeline",
            active = TRUE,
            icon = f7Icon("list_bullet"),
            f7Timeline(
              uiOutput("timeline")
            )
          ),
          f7Tab(
            tabName = "Graphs",
            icon = f7Icon("graph_square"),
            uiOutput("brew"),
            highchartOutput("plot_temps"),
            tags$br(),
            highchartOutput("plot_gravity")
          ),
          f7Tab(
            tabName = "Tools",
            icon = f7Icon("wrench"),
            f7Select(
              inputId = "tool",
              label = "Select a tool",
              choices = c(
                "Hydrometer adjustment" = "hydrometer",
                "Alcohol by Volume (ABV)" = "abv"
              )
            ),
            uiOutput("toolUI"),
            uiOutput("tool_res")
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
