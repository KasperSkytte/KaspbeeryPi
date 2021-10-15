#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @import highcharter
#' @importFrom magrittr %>%
#' @importFrom data.table dcast fifelse fread fwrite last rbindlist %chin%
#' @importFrom lubridate as.duration as.period interval ymd_hm
#' @importFrom plyr dlply
#' @importFrom rdrop2 drop_auth drop_dir drop_download
#' @noRd
app_server <- function(input, output, session) {
  local_data_dir <- "data" # where to store data files locally. Cannot container anything else
  drop_data_dir <- "data" # where the data files on dropbox are located
  names_file <- "names.csv" # filename of the "masterfile" with beer names
  drop_auth(rdstoken = "token.rds", cache = FALSE)

  getData <- reactive({
    names_filepath <- paste0(drop_data_dir, "/", names_file)

    # check if local data dir exists
    if (!dir.exists(local_data_dir)) {
      dir.create(local_data_dir)
    }

    # list files and hash on dropbox and write to a local file
    drop_files_status <- drop_dir(drop_data_dir)[, c("name", "path_lower", "content_hash"), drop = FALSE]
    if (!file.exists("files_status.csv")) {
      local_files_status <- drop_files_status[, c("name", "content_hash")]
      fwrite(local_files_status, file = "files_status.csv")
      colnames(local_files_status) <- c("name", "content_hash_local")
    } else {
      local_files_status <- fread("files_status.csv", col.names = c("name", "content_hash_local"))
    }


    # names_file file on dropbox dominates and decides what to store locally
    if (any(grepl(paste0(names_filepath, "$"), drop_files_status$path_lower))) {
      drop_download(
        path = names_filepath,
        local_path = names_filepath,
        overwrite = TRUE,
        progress = FALSE,
        verbose = FALSE
      )
    } else {
      stop(paste("No file named", names_file, "found on Dropbox"), call. = FALSE)
    }

    # read names_file and merge with db file list for checking content hashes
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

    # list local files, exclude names_file
    local_data <- list.files(
      local_data_dir,
      full.names = TRUE,
      recursive = FALSE,
      include.dirs = FALSE
    )
    local_data <- local_data[!grepl(paste0(names_file, "$"), local_data)]

    # delete local files not mentioned in names_file
    file.remove(local_data[!basename(local_data) %chin% names_comb$filename])

    # download those that don't exist locally or with changed hash since last time
    # and load files into a list
    datalist <- plyr::dlply(
      names_comb,
      "filename",
      function(x) {
        if (!x$filename %chin% basename(local_data) | !identical(x$content_hash, x$content_hash_local)) {
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

        # sometimes observations get added with the same timestamp and sensor if the Pi hasn't adjusted its clock
        readings <- readings[!duplicated(readings[, c("time", "sensor")]), ]

        # set brew name as attribute to show in selection instead of file names
        attr(readings, "brew") <- x$name
        return(readings)
      }
    )

    # update local hash table
    fwrite(drop_files_status[, c("name", "content_hash")], file = "files_status.csv")

    # order by names_file
    datalist <- datalist[names_comb$filename]

    return(datalist)
  })

  brewData <- reactive({
    shiny::req(getData(), input$brew)
    getData()[[input$brew]]
  })

  output$timeline <- renderUI({
    lapply(rev(getData()), function(beer) {
      startDate <- beer[, min(time)]
      endDate <- beer[, max(time)]
      duration <- lubridate::as.period(
        lubridate::as.duration(
          lubridate::interval(
            startDate, endDate
          )
        )
      )

      tiltGData <- beer[sensor %chin% "tiltSG"]
      if (tiltGData[, .N] > 0) {
        OG <- tiltGData[, max(value)]
        FG <- tiltGData[, min(value)]
        att <- round((OG - FG) / (OG - 1000) * 100, 2)
        ABV <- round(1.05 * (OG - FG) / (FG * 0.79) * 100, 2)
      } else {
        OG <- FG <- att <- ABV <- "N/A"
      }

      tiltTempData <- beer[sensor %chin% "tiltTempC"]

      f7TimelineItem(
        title = attr(beer, "brew"),
        date = format(startDate, "%Y %b %d"),
        card = TRUE,
        subtitle = tagList(
          p("OG: ", tags$b(OG), "FG: ", tags$b(FG))
        ),
        tagList(
          "ABV: ", tags$b(ABV, "%"),
          tags$br(),
          "App. attenuation: ", tags$b(att, "%"),
          tags$br(),
          "Highest temperature (Tilt): ", tags$b(
            if (tiltTempData[, .N] > 0) {
              tiltTempData[, round(max(value), 2)]
            } else {
              "N/A"
            }
          ),
          tags$br(),
          "Ended: ",
          tags$b(format(endDate, "%Y %b %d")),
          tags$br(),
          "Duration: ",
          tags$b(
            sprintf(
              "%dd %dh %dm",
              duration$day,
              duration$hour,
              duration$minute
            )
          )
        )
      )
    })
  })

  output$brew <- renderUI({
    shiny::req(getData())

    # extract file names and brew names to choose between
    brews <- names(getData())
    names(brews) <- sapply(getData(), attr, "brew")

    f7Select(
      inputId = "brew",
      label = "Select beer",
      choices = brews,
      selected = last(brews)
    )
  })
  outputOptions(output, "brew", suspendWhenHidden = FALSE)

  output$plot_temps <- renderHighchart({
    data_temps <- brewData()[!sensor %chin% "tiltSG"]
    data_temps[, time := datetime_to_timestamp(time)]
    highchart() %>%
      hc_xAxis(
        type = "datetime"
        # ,alternateGridColor = "#222222"
      ) %>%
      hc_yAxis(
        title = list(text = "Temperature [°C]")
      ) %>%
      hc_add_series(
        data_temps,
        "line",
        hcaes(time, value, group = "sensor")
      ) %>%
      hc_navigator(enabled = TRUE) %>%
      hc_add_theme(hc_theme_alone())
  })

  output$plot_gravity <- renderHighchart({
    data_tilt <- brewData()[sensor %chin% "tiltSG"]
    if (data_tilt[, .N] > 0) {
      data_tilt[, time := datetime_to_timestamp(time)]
      highchart() %>%
        hc_xAxis(
          type = "datetime"
          # ,alternateGridColor = "#222222"
        ) %>%
        hc_yAxis(
          title = list(text = "Specific gravity [g/L]")
        ) %>%
        hc_add_series(
          data_tilt,
          "line",
          hcaes(time, value),
          name = "Specific gravity",
          showInLegend = FALSE
        ) %>%
        hc_navigator(enabled = TRUE) %>%
        hc_add_theme(hc_theme_alone())
    } else {
      highchart()
    }
  })

  output$toolUI <- renderUI({
    shiny::req(brewData())
    if (input$tool == "abv") {
      data_tilt <- brewData()[sensor %chin% "tiltSG"]
      tagList(
        f7Stepper(
          inputId = "abvcalc_og",
          label = "Original gravity",
          value = if (data_tilt[, .N] > 0) data_tilt[, max(value)] else 1050,
          min = 1000,
          max = 1200,
          step = 1
        ),
        tags$br(),
        f7Stepper(
          inputId = "abvcalc_fg",
          label = "Final gravity",
          value = if (data_tilt[, .N] > 0) data_tilt[, min(value)] else 1012,
          min = 1000,
          max = 1200,
          step = 1
        )
      )
    } else if (input$tool == "hydrometer") {
      tagList(
        f7Stepper(
          inputId = "hydrometer_temp",
          label = "Temperature",
          value = 70,
          min = 0,
          max = 212,
          step = 1
        ),
        tags$br(),
        f7Stepper(
          inputId = "hydrometer_sg",
          label = "Specific gravity",
          value = 1065,
          min = 1000,
          max = 1200,
          step = 1
        ),
        tags$br(),
        f7Stepper(
          inputId = "hydrometer_calibtemp",
          label = "Hydrometer calibration temperature",
          value = 20,
          min = 0,
          max = 50,
          step = 1
        ),
        tags$br(),
        shiny::radioButtons(
          inputId = "hydrometer_unit",
          label = "",
          choices = c(
            "Celcius",
            "Fahrenheit"
          ),
          inline = TRUE,
          selected = "Celcius"
        )
      )
    }
  })

  output$tool_res <- renderUI({
    shiny::req(input$hydrometer_unit)
    if (input$tool == "abv") {
      tagList(
        p(
          "Result: ",
          tags$b(
            round(1.05 * (input$abvcalc_og - input$abvcalc_fg) / (input$abvcalc_fg * 0.79) * 100, 2)
          )
        )
      )
    } else if (input$tool == "hydrometer") {
      # formula from http://www.musther.net/vinocalc.html
      # formula is for temperatures in fahrenheit only, range: 0-60C
      SG <- input$hydrometer_sg
      temp <- input$hydrometer_temp
      calibTemp <- input$hydrometer_calibtemp

      if (input$hydrometer_unit == "Celcius") {
        temp <- temp * 1.8 + 32
        calibTemp <- calibTemp * 1.8 + 32
      }
      CSG <- SG * ((1.00130346 - (0.000134722124 * temp) + (0.00000204052596 * temp^2) - (0.00000000232820948 * temp^3)) /
        (1.00130346 - (0.000134722124 * calibTemp) + (0.00000204052596 * calibTemp^2) - (0.00000000232820948 * calibTemp^3)))

      tagList(
        p(
          "Result: ",
          tags$b(
            round(CSG, 2)
          )
        )
      )
    }
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
