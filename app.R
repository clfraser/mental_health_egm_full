##########################################################
# Mental health EGM
# Original author(s): Catriona Fraser
# Original date: 2023-05-12
# Written/run on RStudio server 2022.7.2.576.12 and R 4.1.2
# Description of content
##########################################################


# Get packages
source("setup.R")

# Source files with UI code for each tab --------------
walk(list.files("ui", full.names = TRUE), ~ source(.x))


# UI
ui <- 
#secure_app( # For password protection
  
  fluidPage(
tagList(
  tags$html(lang = "en"), # Set the language of the page - important for accessibility
  
  # WHEN THE NEW WEPAGE IS LIVE, UNCOMMENT LINES 27 to 31 AND COMMENT OUT LINES 34 to 76. ER did on 11 April 2025
  
  h1("This evidence and gap map has moved"),
  p("Please go to its new home on the",
    tags$a(href = "https://publichealthscotland.scot/population-health/mental-health/prevention-of-mental-ill-health-and-improved-wellbeing/mental-health-evidence-and-addressing-gaps/",
          target = "_blank",
          tags$b("Public Health Scotland website")))
  

# # Specify most recent fontawesome library - change version as needed
# tags$style("@import url(https://use.fontawesome.com/releases/v6.2.0/css/all.css);"),
# # Add note that dashboard is in development
# # div(
# #     div("Dashboard is in development. Not final version."),
# #     style = "color: white; background-color: red; width: 100%; text-align: center; font-weight: bold;",
# # ),
# navbarPage(
#     id = "tabset_navbar", # id used for jumping between tabs
#     title = div(
#         tags$a(img(src = "phs-logo-updated.png", height = 40, alt = "Link to Public Health Scotland website. Opens in a new tab.")),
#                href = "https://www.publichealthscotland.scot/",
#                target = "_blank",
#     style = "position: relative; top: -5px;"),
#     windowTitle = "Self-harm in children and young people EGM",# Title for browser tab
#     header = tags$head(          includeCSS("www/css/main.css"),  # Main
#                                  includeCSS("www/css/tables.css"),  # tables
#                                  includeCSS("www/css/navbar_and_panels.css"), # navbar and notes panel
#                                  includeCSS("www/css/buttons.css"), # buttons
#                                  includeCSS("www/css/select.css"), # selectors and radio buttons
#                                  includeCSS("www/css/popovers.css"), # popovers
#                                  includeCSS("www/css/boxes.css"), # boxes
#                                  includeCSS("www/css/value_box.css"), # valueBox for headline figures
#                                  includeCSS("www/css/info_box.css"), # infoBox for summary page boxes
#                                  includeCSS("www/css/js_tree_r.css") # for heirarchical checkboxes
# 
#     ,  # CSS stylesheet
#     tags$head(
#       tags$script(src="js/index.js")
#     ), # Include script that allows you to jump between tabs using a link
#     collapsible = TRUE, # Make navigation bar collapse on smaller screens
#     tags$link(rel = "shortcut icon", href = "favicon_phs.ico"), # Icon for browser tab
# 
# ),
# 
# # Order of tabs --------------------------------
# 
#  homepageTab,
#  mainTab,
#  glossaryTab,
#  linksTab,
# 
# ) # navbar
) # taglist
) # ui fluidpage
#) # Secure app, for password protection

# Server

server <- function(input, output, session) {

  
  credentials <- readRDS(here("admin/credentials.rds"))
  
  res_auth <- secure_server(
    check_credentials = check_credentials(credentials)
  )
  
    # Get functions
    source(file.path("functions/core_functions.R"), local = TRUE)$value
    source(file.path("functions/intro_page_functions.R"), local = TRUE)$value
    source(file.path("functions/egm_functions.R"), local = TRUE)$value
    source(file.path("functions/guided_tours.R"), local = TRUE)$value

    # Get server content for individual pages
    source(file.path("server/intro_server.R"), local = TRUE)$value
    source(file.path("server/egm_server.R"), local = TRUE)$value
    source(file.path("server/glossary_server.R"), local = TRUE)$value
  
  # Keeps the shiny app from timing out quickly 
  autoInvalidate <- reactiveTimer(10000)
  observe({
    autoInvalidate()
    cat(".")
  })

}

# Run the application
shinyApp(ui=ui, server=server)

### END OF SCRIPT ###
