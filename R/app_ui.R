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
            tabName = "Beers",
            active = TRUE,
            icon = f7Icon("rectangle_stack"),
            f7Timeline(
              uiOutput("timeline")
            )
          ),
          f7Tab(
            tabName = "Logs",
            icon = f7Icon("graph_square"),
            uiOutput("brew"),
            f7Select(
              inputId = "plot_type",
              label = "Select plot type",
              choices = c("Gravity", "Temperatures")
            ),
            conditionalPanel(
              condition = 'input.plot_type == "Gravity"',
              highchartOutput("plot_gravity", height = "350px")
            ),
            conditionalPanel(
              condition = 'input.plot_type == "Temperatures"',
              highchartOutput("plot_temps", height = "350px")
            )
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
            f7Card(
              uiOutput("toolUI"),
              footer = uiOutput("tool_res")
            )
          ),
          f7Tab(
            tabName = "About",
            icon = f7Icon("question_square"),
            p("This Shiny app is a Progressive Web App (PWA) designed for smart phones meaning it can show in full screen giving it the feeling of a native smart phone app, it's just served from the web instead. To install on iOS/Android do the following:"),
            p("1. Visit", tags$a('https://apps.cafekapper.dk/kaspbeerypi'), "from a web browser on a smart phone"),
            p("2. Depending on the browser, find and click 'add to home screen'"),
            p("3. Name it whatever you want, fx KaspbeeryPi"),
            p("4. Click Add. Clicking the icon from the home screen will now show the app in full screen."
            )
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
