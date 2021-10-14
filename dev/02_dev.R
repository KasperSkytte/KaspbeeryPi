# Building a Prod-Ready, Robust Shiny Application.
# 
# README: each step of the dev files is optional, and you don't have to 
# fill every dev scripts before getting started. 
# 01_start.R should be filled at start. 
# 02_dev.R should be used to keep track of your development during the project.
# 03_deploy.R should be used once you need to deploy your app.
# 
# 
###################################
#### CURRENT FILE: DEV SCRIPT #####
###################################

# Engineering

## Dependencies ----
## Add one line by package you want to add as dependency
usethis::use_package("rdrop2", min_version = TRUE)
usethis::use_package("shiny", min_version = TRUE)
usethis::use_package("data.table", min_version = TRUE)
usethis::use_package("shinyMobile", min_version = TRUE)
usethis::use_package("lubridate", min_version = TRUE)
usethis::use_package("plyr", min_version = TRUE)
usethis::use_package("ggplot2", min_version = TRUE)
usethis::use_package("dygraphs", min_version = TRUE)
usethis::use_package("xts", min_version = TRUE)

## Setup Progressive Web App for shinyMobile
charpente::set_pwa(
  ".",
  name = "KaspbeeryPi",
  shortName = "KaspbeeryPi",
  description = "Use this app to track the fermentation of my home brewed beer. It tracks the gravity and temperature of my home brewed beer, which is streamed from a Raspberry Pi Zero W near the fermentor. It also has useful tools for the brewer like calculators for adjusting hydrometer readings, ABV, water profile etc. Please, brew more beer yourself!",
  startUrl = "https://apps.cafekapper.dk/kaspbeerypi",
  create_dependencies = TRUE,
  register_service_worker = FALSE
)

## Add modules ----
## Create a module infrastructure in R/
#golem::add_module( name = "name_of_module1" ) # Name of the module
#golem::add_module( name = "name_of_module2" ) # Name of the module

## Add helper functions ----
## Creates fct_* and utils_*
#golem::add_fct( "helpers" ) 
#golem::add_utils( "helpers" )

## External resources
## Creates .js and .css files at inst/app/www
#golem::add_js_file( "script" )
#golem::add_js_handler( "handlers" )
#golem::add_css_file( "custom" )

## Add internal datasets ----
## If you have data in your package
#usethis::use_data_raw( name = "my_dataset", open = FALSE ) 

## Tests ----
## Add one line by test you want to create
#usethis::use_test( "app" )

# Documentation

## Vignette ----
usethis::use_vignette("kaspbeerypi")
devtools::build_vignettes()

## Code Coverage----
## Set the code coverage service ("codecov" or "coveralls")
#usethis::use_coverage()

# Create a summary readme for the testthat subdirectory
#covrpage::covrpage()

## CI ----
## Use this part of the script if you need to set up a CI
## service for your application
## 
## (You'll need GitHub there)
#usethis::use_github()

# GitHub Actions
#usethis::use_github_action() 
# Chose one of the three
# See https://usethis.r-lib.org/reference/use_github_action.html
usethis::use_github_action_check_release()
usethis::use_github_action_check_standard()
usethis::use_github_action_check_full()
# Add action for PR
usethis::use_github_action_pr_commands()

# You're now set! ----
# go to dev/03_deploy.R
rstudioapi::navigateToFile("dev/03_deploy.R")

