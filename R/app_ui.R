#' The application User-Interface
#' 
#' @param request Internal parameter for `{shiny}`. 
#'     DO NOT REMOVE.
#' @import shiny
#' @importFrom miniUI gadgetTitleBar miniButtonBlock miniContentPanel miniPage miniTabPanel miniTabstripPanel
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    miniPage(
      gadgetTitleBar("KaspbeeryPi", left = NULL, right = NULL),
      miniTabstripPanel(
        #selected = "Graph",
        miniTabPanel(
          "Options",
          icon = icon("sliders-h"),
          miniContentPanel(
            uiOutput("brew"),
            uiOutput("sensor"),
            sliderInput(
              inputId = "timeinterval",
              label = "Interval (WIP)",
              value = 1,
              min = 1,
              max = 10
            )
          )
        ),
        miniTabPanel(
          "Graph",
          icon = icon("chart-line"),
          miniContentPanel(
            uiOutput("plot")
          ),
          miniButtonBlock(
            radioButtons(
              inputId = "plot_type",
              label = "Plot type",
              choices = c("Static", "Interactive"),
              selected = "Static",
              inline = TRUE
            )
          )
        ),
        miniTabPanel(
          "Fermentation",
          icon = icon("stethoscope"),
          miniContentPanel(
            padding = 0,
            fillCol(
              verbatimTextOutput("fermentationInfo"),
              tableOutput("temperaturesInfo")
            )
          )
        ),
        miniTabPanel(
          "ABV calculator",
          icon = icon("percent"),
          miniContentPanel(
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
golem_add_external_resources <- function(){
  
  add_resource_path(
    'www', app_sys('app/www')
  )
 
  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys('app/www'),
      app_title = 'kaspbeerypi'
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert() 
  )
}

