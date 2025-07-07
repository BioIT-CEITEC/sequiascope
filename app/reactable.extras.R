#### dnes je 3.7.2025 ###########################################################################################
## reactable.extras stále nejde používata z následujících důvodů:                                              ##
## bug: do reactable_extras_server() nelze předat reaktivní hodnota, například as.data.frame(dt()) jako vstup. ##
## bug: nelze řadit data v tabulce podle více sloupců. pro jeden funguje dobře                                 ##
## sort jako takový řadí vždy jen právě zobrazená data, ale už se nedívá na zbytek dat v tabulce               ## 
#################################################################################################################


library(shiny)
library(reactable)
library(Rsamtools)
library(data.table)
library(shinyjs)
library(htmlwidgets)
library(shinyWidgets)
library(reactable.extras)

ui <- function(id) {
  ns <- NS(id)
  fluidPage(
  reactable_extras_dependency(),
  reactable_extras_ui(ns("table"))
  )
}

server <- function(id, selected_samples, shared_data) {
  moduleServer(id, function(input, output, session) {
  
    tab <- fread("../input_files/MOII_e117/117_WES_germline/per_sample_final_var_tabs/tsv_formated/DZ1601krev.variants.tsv")

    reactable_extras_server("table",
        data = as.data.frame(tab),
        resizable = TRUE,
        striped = TRUE,
        wrap = FALSE,
        highlight = TRUE,
        outlined = TRUE,
        filterable = TRUE,
        total_pages =  ceiling(nrow(file) / 20),
        defaultColDef = colDef(align = "center", sortNALast = TRUE)
        # defaultSorted = list("CGC_Germline" = "desc", "trusight_genes" = "desc", "fOne" = "desc")
    )
    
  })
}

ui2 <- fluidPage(
  ui("test")
)
server2 <- function(input, output, session) {
  server("test")
}
shinyApp(ui = ui2, server = server2, options = list(launch.browser = TRUE))
