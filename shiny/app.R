############# variables #############
local_data_dir <- "data" #where to store data files locally. Cannot container anything else
drop_data_dir <- "data" #where the data files on dropbox are located
names_file <- "names.csv" #filename of the "masterfile" with beer names

############# script #############
#libraries
library(rdrop2)
library(shiny)
library(dygraphs)
library(data.table)
library(shinydashboard)
library(lubridate)
library(plyr)

#authenticate with token file generated elsewhere
drop_auth(rdstoken = "token.rds")

shinyApp(
  ui = dashboardPage(
    title = "KaspbeeryPi",
    header = dashboardHeader(title = "KaspbeeryPi!"),
    sidebar = dashboardSidebar(
      uiOutput("brew"),
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
    getData <- reactive({
      names_filepath <- paste0(drop_data_dir, "/", names_file)
      
      #check if local data dir exists
      if(!dir.exists(local_data_dir))
        dir.create(local_data_dir)
      
      #list files and hash on dropbox and write to a local file
      drop_files_status <- drop_dir(drop_data_dir)[,c("name", "path_lower", "content_hash"), drop = FALSE]
      if(!file.exists("files_status.csv")) {
        local_files_status <- drop_files_status[,c("name", "content_hash")]
        fwrite(local_files_status, file = "files_status.csv")
        colnames(local_files_status) <- c("name", "content_hash_local")
      } else {
        local_files_status <- fread("files_status.csv", col.names = c("name", "content_hash_local"))
      }
      
      
      #names.csv file on dropbox dominates and decides what to store locally
      if(any(grepl(paste0(names_filepath, "$"), drop_files_status$path_lower))) {
        drop_download(
          path = names_filepath,
          local_path = names_filepath,
          overwrite = TRUE,
          progress = FALSE,
          verbose = FALSE
        )
      }
      
      #read names.csv and merge with db file list for checking content hashes
      names <- merge(
        fread(names_filepath),
        drop_files_status,
        by.x = "filename",
        by.y = "name",
        all.x = TRUE
      )
      names_comb <- merge(
        names,
        local_files_status,
        by.x = "filename",
        by.y = "name",
        all.x = TRUE
      )
      
      #list local files, exclude names_file
      local_data <- list.files(
        local_data_dir,
        full.names = TRUE,
        recursive = FALSE,
        include.dirs = FALSE
      )
      local_data <- local_data[!grepl(paste0(names_file, "$"), local_data)]
      
      #delete local files not mentioned in names.csv
      file.remove(local_data[!basename(local_data) %chin% names_comb$filename])
      
      #download those that don't exist locally or with changed hash since last time
      #and load files into a list 
      datalist <- plyr::dlply(
        names_comb,
        "name",
        function(x) {
          if(!x$filename %chin% basename(local_data) | !identical(x$content_hash, x$content_hash_local)) {
            drop_download(
              x$path_lower,
              local_path = paste0(local_data_dir, "/", x$filename),
              overwrite = TRUE,
              progress = FALSE,
              verbose = FALSE
            )
          }
          readings <- fread(
            paste0(local_data_dir, "/", x$filename),
            col.names = c("time", "sensor", "value")
          )
          readings$time <- ymd_hm(readings$time, tz = "Europe/Copenhagen")
          
          #sometimes observations get added with the same timestamp and sensor if the Pi hasn't adjusted its clock
          readings <- readings[!duplicated(readings[,c("time", "sensor")]),]
          
          return(readings)
        }
      )
      
      #update local hash table
      fwrite(drop_files_status[,c("name", "content_hash")], file = "files_status.csv")
      
      datalist <- datalist[names_comb$name]
      
      return(datalist)
    })
    
    output$brew <- renderUI({
      shiny::req(getData())
      brews <- names(getData())
      selectInput(
        inputId = "brew",
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
    
    brewData <- reactive({
      shiny::req(getData(), input$brew)
      getData()[[input$brew]]
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
        outData <- rbindlist(getData(), idcol = "brew")
        outData[, time := as.character(time)]
        data.table::fwrite(outData, file = file, quote = TRUE)
      }
    )
  }
)