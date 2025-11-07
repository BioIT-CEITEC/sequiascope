# app/logic/export_functions.R

box::use(
  shiny[downloadHandler, observeEvent, reactive, req,is.reactive],
  openxlsx[write.xlsx],
  data.table[fwrite],
  billboarder[bb_export, billboarderProxy],
  networkD3[saveNetwork],
  webshot2[webshot],
  ggplot2[ggsave]
)

# Export table (CSV, TSV, XLSX)
#' @export
get_table_download_handler <- function(input, patient, data, filtered_data, suffix = "") {
  data_input_name <- paste0("export_data_table", suffix)
  format_input_name <- paste0("export_format_table", suffix)
  
  downloadHandler(
    filename = function() {
      file_name <- switch(input[[data_input_name]],
                          "filtered" = paste0(patient,"_filtered_data"),
                          "all" = paste0(patient,"_all_data"))
      switch(input[[format_input_name]],
             "tsv" = paste0(file_name,".tsv"),
             "csv" = paste0(file_name,".csv"),
             "xlsx" = paste0(file_name,".xlsx"))
    },
    content = function(file) {
      export_data <- if (input[[data_input_name]] == "filtered") {
        if (is.reactive(filtered_data)) filtered_data() else filtered_data
      } else {
        if (is.reactive(data)) data() else data
      }
      
      # Convert list columns to character (for reactable HTML elements, etc.)
      export_data <- as.data.frame(export_data)
      list_cols <- sapply(export_data, is.list)
      if (any(list_cols)) {
        for (col_name in names(export_data)[list_cols]) {
          export_data[[col_name]] <- sapply(export_data[[col_name]], function(x) {
            if (is.null(x) || length(x) == 0) return("")
            if (length(x) == 1) return(as.character(x))
            paste(as.character(x), collapse = ", ")
          })
        }
      }
      
      switch(input[[format_input_name]],
             "tsv" = { fwrite(export_data, file, sep = "\t", quote = FALSE) },
             "csv" = { fwrite(export_data, file, sep = ",", quote = "auto") },
             "xlsx" = { write.xlsx(export_data, file) }
      )
    }
  )
}


# Export histogramu TVF
#' @export
get_hist_download_handler <- function(patient,h) {
  downloadHandler(
    filename = paste0(patient,"_TVF_histogram.png"),
    content = function(file) {
      ggsave(file, h, width = 12, height = 4)
    }
  )
}


# Export Sankey plot (HTML, PNG)
#' @export
get_sankey_download_handler <- function(input, patient, p) {
  downloadHandler(
    filename = function() {
      if (input$export_format == "html") {
        paste0(patient,"_sankey.html")
      } else {
        paste0(patient,"_sankey.png")
      }
    },
    content = function(file) {
      if (input$export_format == "html") {
        saveNetwork(p, file, selfcontained = TRUE)
      } else {
        temp_html <- tempfile(fileext = ".html")
        saveNetwork(p, temp_html, selfcontained = TRUE)
        webshot(temp_html, file, vwidth = 733, vheight = 317)
        unlink(temp_html)
      }
    }
  )
}
