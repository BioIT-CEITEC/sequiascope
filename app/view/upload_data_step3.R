# mod_step3.R
box::use(
  shiny[NS,tagList,fileInput,moduleServer,observe,reactive,textOutput,updateTextInput,renderText,req,textInput,observeEvent,textAreaInput,column,fluidRow,reactiveVal,
        isTruthy,actionButton,icon,updateTextAreaInput,uiOutput,renderUI,bindEvent,fluidPage,radioButtons,verbatimTextOutput,renderPrint],
  htmltools[tags,HTML,div,span,h2,h4,br],
  shinyFiles[shinyDirButton,shinyDirChoose,parseDirPath,getVolumes],
  shinyWidgets[prettySwitch,updatePrettySwitch,pickerInput,updatePickerInput, dropdownButton,tooltipOptions,radioGroupButtons],
  bs4Dash[addPopover,box],
  stringi[stri_detect_regex],
  stringr[str_detect,regex],
  shinyalert[shinyalert],
  # shinyjs[useShinyjs,runjs],
)

# krok 3: potvrzení
step3_ui <- function(id) {
  ns <- NS(id)
  fluidPage(
    tags$h4("Step 3: Confirm"),
    verbatimTextOutput(ns("summary")),
    br(),
    actionButton(ns("prev3"), "Back"),
    actionButton(ns("confirm"), "Confirm")
  )
}

step3_server <- function(id, patients, path) {
  moduleServer(id, function(input, output, session) {
    output$summary <- renderPrint({
      list(
        path     = path(),
        patients = patients()
      )
    })
    
    observeEvent(input$confirm, {
      showModal(modalDialog(
        "Your selection has been confirmed!",
        easyClose = TRUE
      ))
    })
    
    return(list(
      prev3 = reactive(input$prev3)
    ))
  })
}



# 
# step3_server <- function(id, path, patients, datatype) {
#   moduleServer(id, function(input, output, session) {
#     
#     output$summary <- renderPrint({
#       list(path = path(),
#            patients = patients(),
#            datatype = datatype())
#     })
#     
#     observeEvent(input$confirm, {
#       showModal(modalDialog(
#         "Your selection has been confirmed!",
#         easyClose = TRUE
#       ))
#     })
#     
#     return(list(prev3 = reactive(input$prev3)))
#   })
# }
# 
