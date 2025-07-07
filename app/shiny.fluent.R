# 
# file <- fread("../input_files/MOII_e117/117_WES_germline/per_sample_final_var_tabs/tsv_formated/DZ1601krev.variants.tsv")
# file_json <- jsonlite::toJSON(file, dataframe = "rows")
# 
# shiny.react::reactOutput("VirtualizedGermlineTable")

library(data.table)
library(shiny)
library(shiny.react)
library(jsonlite)

# Simulace dat (nahraď za svůj germline dataframe)
df <- data.frame(
  CHROM = rep("1", 50000),
  POS = 1:50000,
  REF = "A",
  ALT = "T"
)

ui <- fluidPage(
  reactOutput("VirtualizedGermlineTable")
)

server <- function(input, output, session) {
  germline_json <- toJSON(df, dataframe = "rows")
  shiny.react::renderReact("VirtualizedGermlineTable", "VirtualizedGermlineTable", props = list(germline_data = fromJSON(germline_json)))
}

shinyApp(ui, server)
