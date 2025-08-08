library(shiny)
library(shinyWidgets)
library(shinyFiles)

ui <- fluidPage(
  h2("Upload data workflow"),
  uiOutput("wizard_ui")
)

server <- function(input, output, session) {
  
  step <- reactiveVal(1)  # aktuální stránka
  
  # krok 1: cesta + pacienti
  step1_ui <- fluidPage(
    tags$h4("Step 1: Select directory and patients"),
    shinyDirButton("dir", "Browse...", "Select directory"),
    textInput("dir_path", "Directory path"),
    textAreaInput("patients_raw", "Patients (comma separated)"),
    br(),
    actionButton("next1", "Next")
  )
  
  # krok 2: typ dat
  step2_ui <- fluidPage(
    tags$h4("Step 2: Select data type"),
    radioButtons("datatype", "Choose data type:",
                 choices = c("Somatic variants", "Germline variants",
                             "Fusion genes", "Expression profile")),
    br(),
    actionButton("prev2", "Back"),
    actionButton("next2", "Next")
  )
  
  # krok 3: potvrzení
  step3_ui <- fluidPage(
    tags$h4("Step 3: Confirm"),
    verbatimTextOutput("summary"),
    br(),
    actionButton("prev3", "Back"),
    actionButton("confirm", "Confirm")
  )
  
  # render UI podle kroku
  output$wizard_ui <- renderUI({
    switch(step(),
           "1" = step1_ui,
           "2" = step2_ui,
           "3" = step3_ui
    )
  })
  
  # ovládání kroků
  observeEvent(input$next1, step(2))
  observeEvent(input$prev2, step(1))
  observeEvent(input$next2, step(3))
  observeEvent(input$prev3, step(2))
  
  # rekapitulace na konci
  output$summary <- renderPrint({
    list(
      path = input$dir_path,
      patients = strsplit(input$patients_raw, ",")[[1]] |> trimws(),
      datatype = input$datatype
    )
  })
  
  observeEvent(input$confirm, {
    showModal(modalDialog(
      "Your selection has been confirmed!",
      easyClose = TRUE
    ))
  })
}

shinyApp(ui, server)
