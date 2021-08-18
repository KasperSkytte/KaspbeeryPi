############# variables #############
readingsFile <- "readings.csv" #filename of the dropbox file with sensor readings
namesFile <- "names.csv" #filename of the file containing names of each beer

############# script #############
#libraries
#.libPaths("/usr/local/lib/R/library")
library(rdrop2)
library(shiny)
library(dygraphs)
library(data.table)
library(shinydashboard)
library(lubridate)

drop_auth(rdstoken = "token.rds")

shinyApp(
  ui = dashboardPage(
    title = "KaspbeeryPi",
    header = dashboardHeader(title = "KaspbeeryPi!"),
    sidebar = dashboardSidebar(
      uiOutput("brewNo"),
      uiOutput("sensor"),
      tags$br(),
      conditionalPanel(
        condition = "$('html').hasClass('shiny-busy')",
        div(
          style = "text-align:center",
          icon("refresh"),
          "Loading..."
        )
      ),
      conditionalPanel(
        condition = "!$('html').hasClass('shiny-busy')",
        div(
          style = "text-align:center",
          downloadLink(
            outputId = "download",
            label = tagList(shiny::icon("file-download"), "Download data")
          )
        )
      )
    ),
    body = dashboardBody(
      #hide errors
      tags$style(type="text/css",
                 ".shiny-output-error { visibility: hidden; }",
                 ".shiny-output-error:before { visibility: hidden; }"
      ),
      width = 12,
      box(
        width = 10,
        title = tagList(shiny::icon("line-chart"), "Time series"),
        icon = icon("chart-line"),
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = FALSE,
        status = "primary",
        dygraphOutput("plot", height = 400)
      ),
      column(
        width = 10,
        box(
          width = 6,
          title = tagList(shiny::icon("stethoscope"), "Fermentation"),
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = FALSE,
          status = "primary",
          verbatimTextOutput("fermentationInfo")
        ),
        box(
          width = 6,
          title = tagList(shiny::icon("thermometer-half"), "Temperatures"),
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = FALSE,
          status = "primary",
          tableOutput("temperaturesInfo")
        )
      )
    ),
    skin = "blue"
  ),
  server = function(input, output) {
    ##### UI elements #####
    output$brewNo <- renderUI({
      shiny::req(getData())
      brews <- unique(getData()$brewNo)
      if(any(colnames(getData()) %chin% "name"))
        names(brews) <- unique(getData()$name)
      selectInput(
        inputId = "brewNo",
        label = "Beer name",
        choices = brews,
        selected = last(brews),
        multiple = FALSE
      )
    })
    
    output$sensor <- renderUI({
      shiny::req(brewData())
      sensors <- sort(unique(brewData()[["sensor"]]))
      selectInput(
        inputId = "sensor",
        label = "Sensor(s)",
        choices = sensors,
        selected = sensors,
        multiple = TRUE
      )
    })
    
    ##### Server elements #####
    getData <- reactive({
      #create temporary file
      readingsPath <- file.path(tempdir(), readingsFile)
      
      #download the file to the temporary file
      drop_download(readingsFile,
                    local_path = readingsPath,
                    overwrite = TRUE,
                    verbose = FALSE,
                    progress = FALSE)
      #read the file into R
      readings <- data.table::fread(readingsPath, col.names = c("time", "sensor", "value"))
      readings$time <- ymd_hm(readings$time, tz = "Europe/Copenhagen")
      
      #sometimes observations get added with the same timestamp and sensor if the Pi hasn't adjusted its clock
      readings <- readings[!duplicated(readings[,c("time", "sensor")]),]
      
      #assume a new brew is made if duration between two observations are >24 hours
      readings[,brewNo := cumsum(c(TRUE, int_diff(time) > hours(24)))]
      
      #merge with names
      tryCatch({
        namesPath <- file.path(tempdir(), namesFile)
        drop_download(namesFile,
                      local_path = namesPath,
                      overwrite = TRUE,
                      verbose = FALSE,
                      progress = FALSE)
        brewNames <- data.table::fread(namesPath)
        readings <- brewNames[readings, on = "brewNo"]
        readings[,name := ifelse(is.na(name), brewNo, name)]
      },
      error = function(e) {
        warning("Couldn't find file with brew names", call. = FALSE)
      })
      
      return(readings)
    })
    
    brewData <- reactive({
      shiny::req(getData(), input$brewNo)
      getData()[brewNo %in% input$brewNo]
    })
    
    dataSubset <- reactive({
      shiny::req(brewData(), input$sensor)
      Sys.sleep(0.2)
      readings <- dcast(brewData()[sensor %chin% input$sensor], time~sensor)
      xts <- xts::xts(readings, order.by = readings$time)
      return(xts)
    })
    
    output$fermentationInfo <- renderPrint({
      shiny::req(brewData())
      startDate <- brewData()[, min(time)]
      endDate <- brewData()[,max(time)]
      duration <- lubridate::as.period(
        lubridate::as.duration(
          lubridate::interval(
            startDate,endDate)))
      cat(paste0("Start: ", format(startDate, "%Y-%m-%d %H:%M")))
      cat("\n")
      cat(paste0("End: ", format(endDate, "%Y-%m-%d %H:%M")))
      cat("\n")
      cat(paste0("Duration: ", sprintf("%dd %dh %dm",
                                       duration$day, 
                                       duration$hour, 
                                       duration$minute)))
      if(any(brewData()$sensor == "tiltSG")) {
        latest <- brewData()[sensor %chin% "tiltSG"][.N]
        OG <- brewData()[sensor %chin% "tiltSG", max(value)]
        FG <- brewData()[sensor %chin% "tiltSG", min(value)]
        attenuation <- round((OG-FG)/(OG-1000)*100, 2)
        ABV <- round(1.05*(OG-FG)/(FG*0.79)*100, 2)
        cat("\n")
        cat("\n")
        cat(paste0("SG (", latest[,format(time, format = "%Y-%m-%d %H:%M")], "): ", latest[,value]))
        cat("\n")
        cat(paste0("OG (max): ", OG))
        cat("\n")
        cat(paste0("FG (min): ", FG))
        cat("\n")
        cat("\n")
        cat(paste0("App. attenuation: ", attenuation, "%"))
        cat("\n")
        cat(paste0("ABV: ", ABV, "%"))
        cat("\n")
      }
    })
    
    output$temperaturesInfo <- renderTable({
      shiny::req(brewData())
      out <- brewData()[
        !sensor %chin% "tiltSG",
        .(min = round(min(value), 2), 
          mean = round(mean(value), 2), 
          max = round(max(value), 2),
          last = round(last(value), 2)), 
        by = sensor]
      colnames(out)[1] <- "Probe"
      return(out)
    })
    
    output$plot <- renderDygraph({
      shiny::req(dataSubset(), input$sensor)
      plot <- dygraph(dataSubset()) %>%
        #dyRangeSelector(height = 100) %>%
        dyOptions(drawPoints = TRUE, pointSize = 2, drawGrid = FALSE) %>%
        dyLegend(show = "follow", width = 200) %>%
        dyLimit(0, color = "red") %>%
        dyUnzoom() %>%
        dyAxis("y", label = "temperature [ºC]", independentTicks = TRUE)
      if(any(input$sensor %chin% "tiltSG")) {
        plot <- plot %>% 
          dyAxis("y2", label = "gravity [g/L]", independentTicks = TRUE) %>% 
          dySeries("tiltSG", axis = "y2")
      }
      #dyAxis(name = "y", valueRange = c(floor(min(dataSubset()$temperature))-1, ceiling(max(dataSubset()$temperature))+1))
      # if((as.numeric(zoo::index(dataSubset())[length(unique(zoo::index(dataSubset())))]) - as.numeric(zoo::index(dataSubset()[1]))) > 86400) {
      #   plot <- plot %>%
      #     dyRangeSelector(height = 100, 
      #                     dateWindow = c(zoo::index(dataSubset())[length(unique(zoo::index(dataSubset())))]-86400,
      #                                    zoo::index(dataSubset())[length(unique(zoo::index(dataSubset())))]))
      # }
      return(plot)
    })
    
    output$download <- downloadHandler(
      filename = "readings.csv",
      content = function(file) {
        outData <- getData()
        outData[, time := as.character(time)]
        data.table::fwrite(getData(), file = file, quote = TRUE)
      }
    )
  }
)
