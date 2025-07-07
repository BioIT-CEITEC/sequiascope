box::use(  
  shiny[tags,tagList, icon, actionButton, textInput,HTML],
  reactable,
  reactable[colDef,JS,colGroup],
  htmltools[div,tags,tagAppendAttributes],
  stats[na.omit,setNames],
  bs4Dash[actionButton],
  reactablefmtr[pill_buttons,data_bars],
  htmltools[HTML,span, div, tagList],
  data.table[uniqueN]
)

box::use(
  app/logic/prepare_table[get_tissue_list, colFilter]
)


# Select input filter with an "All" default option
#' @export
selectFilter <- function(tableId, style = "width: 100%; height: 100%;") {
  function(values, name) {
    tags$select(
      # Set to undefined to clear the filter
      onchange = sprintf("
        const value = event.target.value
        Reactable.setFilter('%s', '%s', value === '__ALL__' ? undefined : value)
      ", tableId, name),
      # "All" has a special value to clear the filter, and is the default option
      tags$option(value = "__ALL__", "All"),
      lapply(unique(values), tags$option),
      "aria-label" = sprintf("Filter %s", name),
      style = style
    )
  }
}

# Min range filter input that handles NaNs
#' @export
minRangeFilter <- function(tableId, style = "width: 100%;") {
  function(values, name) {
    values <- na.omit(values)
    oninput <- sprintf("Reactable.setFilter('%s', '%s', this.value)", tableId, name)
    tags$input(
      type = "range",
      min = floor(min(values)),
      max = ceiling(max(values)),
      value = floor(min(values)),
      oninput = oninput,
      style = style,
      "aria-label" = sprintf("Filter by minimum %s", name)
    )
  }
}

# Min value filter method that handles NaNs
#' @export
filterMinValue <- JS("(rows, columnId, filterValue) => {
  return rows.filter(row => {
    const value = row.values[columnId]
    return !isNaN(value) && value >= filterValue
  })
}")


custom_colDef_setting <- function(tag, session = NULL, column_names = NULL,log2FC = NULL){
  if (tag == "expression") {
    
    custom_colDef <- list(
      # feature_name = colDef(minWidth = 150, filterable = TRUE),
      # geneid = colDef(minWidth = 150, filterable = TRUE),
      # all_kegg_paths_name = colDef(minWidth = 170, filterable = TRUE),
      # pathway = colDef(minWidth = 180, filterable = TRUE),
      # pathway = colDef(
      #   minWidth = 180,
      #   filterable = TRUE,
      #   html = TRUE,  # Povolení HTML v Reactable
      #   cell = function(value) {
      #     if (is.null(value) || value == "") return("N/A")
      #     
      #     pathway_colors <- list(
      #       "RTK Signaling" = "#98FB98",
      #       "Metabolic Signaling" = "#00CED1",
      #       "Epigenetics" = "#DA70D6",
      #       "PI3K/AKT/mTOR Signaling" = "#008000",
      #       "Apoptosis" = "#FF7F00",
      #       "MAPK Signaling" = "#800000",
      #       "WNT signaling" = "#6495ED",
      #       "Hormone Signaling" = "#DC143C",
      #       "DNA damage/repair" = "#87CEEB",
      #       "Cell cycle control" = "#FB9A99",
      #       "Immune Checkpoints" = "#A9A9A9",
      #       "TGF-B Signaling" = "#FFD700",
      #       "JAK/STAT Signaling" = "#BDB76B",
      #       "Hedgehog Signaling" = "#8B008B",
      #       "Non-receptor kinases" = "#6A5ACD",
      #       "Kinase Fusions" = "#D2691E",
      #       "Immune Response" = "#4682B4")
      #     
      #     pathways <- strsplit(value, ",")[[1]] # Rozdělení pathway hodnot do seznamu (některé mohou obsahovat více pathway)
      #     pathways <- trimws(pathways)  # Odstranění mezer kolem názvů
      #     
      #     # Vytvoření pill elementů
      #     pills <- lapply(pathways, function(pathway) {
      #       color <- pathway_colors[[pathway]]
      #       if (is.null(color)) color <- "#D3D3D3"  # Výchozí šedá pro neznámé pathways
      #       div(style = sprintf("display: inline-block; padding: 5px 10px; margin: 2px; border-radius: 15px; background-color: %s; color: white; font-size: 12px; font-weight: bold;", color),
      #           pathway)
      #     })
      #     as.character(tagList(pills)) # Použití `as.character()` k převedení HTML do stringu
      #   }
      # ),
      # num_of_paths = colDef(maxWidth = 100),
      # refseq_id = colDef(maxWidth = 140),
      # type = colDef(maxWidth = 100),
      # gene_definition = colDef(minWidth = 130),
      # all_kegg_gene_names = colDef(minWidth = 150)
    )
    dynamic_columns <- list()
    num_columns <- length(column_names)  # Celkový počet dynamických sloupců
    log2fc_indices <- which(grepl("^log2FC_", column_names))  # Indexy log2FC sloupců
    
    for (i in seq_along(column_names)) {
      col <- column_names[i]
      border_style <- NULL
      
      # # Přidání sloupce mean_log2FC s datovými bary, pokud existuje
      # if ("mean_log2FC" %in% column_names) {
      #   dynamic_columns[["mean_log2FC"]] <- colDef(
      #     cell = data_bars(data$mean_log2FC, 
      #                      fill_color = c("lightblue", "orange"),
      #                      number_fmt = scales::number_format(accuracy = 0.01),
      #                      text_position = "outside-end")
      #   )
      # }
      
      if (grepl("^log2FC_", col)) {
        # První log2FC dostane čáru na oddělení od statických sloupců
        if (i == log2fc_indices[1]) {
          border_style <- list(borderLeft = "2px solid black")
        }
      }
      
      if (grepl("^p_adj_", col)) {
        # P_adj dostane oddělovací čáru jen pokud to není poslední trojice
        if (i < num_columns) {
          border_style <- list(borderRight = "1px dashed rgba(0, 0, 0, 0.3)")
        }
      }
      
      # Vytvoření sloupců s dynamickými vlastnostmi
      # scientific formát, bohužel to trvá strašně dlouho. nejedná se totiž o přepočet ale pouze o zobrazení čísla 
      # v daném zápisu, který reactable zatím nepodporuje: cell = function(value) formatC(value, format = "e", digits = 2)
      if (grepl("^log2FC_", col)) {
        dynamic_columns[[col]] <- colDef(
          # maxWidth = 130,
          style = JS("function(rowInfo, colInfo) {
                        var value = rowInfo.values[colInfo.id];
                        var borderStyle = colInfo.id.includes('p_adj') ? '1px dashed rgba(0, 0, 0, 0.3)' : '';
                        var color = value > 1 ? '#FFE9E9' : (value < -1 ? '#E6F7FF' : '#FFFFFF');

                        return {
                          backgroundColor: color,
                          borderRight: borderStyle
                        };}"))
      } else if (grepl("^p_value_", col)) {
        dynamic_columns[[col]] <- colDef(
          # maxWidth = 130,
          style = JS("function(rowInfo, colInfo) {
                        var value = rowInfo.values[colInfo.id];
                        var borderStyle = colInfo.id.includes('p_adj') ? '1px dashed rgba(0, 0, 0, 0.3)' : '';
                        var color = (value <= 0.05) ? '#FFEFDE' : '#FFFFFF';

                        return {
                          backgroundColor: color,
                          borderRight: borderStyle
                        };}"))
      } else if (grepl("^p_adj_", col)) {
        dynamic_columns[[col]] <- colDef(
          # maxWidth = 130,
          style = JS("function(rowInfo, colInfo) {
                        var value = rowInfo.values[colInfo.id];
                        var borderStyle = '1px dashed rgba(0, 0, 0, 0.3)';  // p-adj má border vždy
                        var color = (value <= 0.05) ? '#E7FAEF' : '#FFFFFF';
                  
                        return {
                          backgroundColor: color,
                          borderRight: borderStyle
                        };}"))
      }
    }

    custom_colDef <- c(custom_colDef, dynamic_columns)
    
  } else {
    print("NOT fusion, expression or germline")
  }
  return(custom_colDef)
}

#' @export
custom_colGroup_setting <- function(tag, tissues = NULL) {
  if (tag == "expression") {
    if (is.null(tissues)) {
      tissues <- get_tissue_list()
    }
    
    custom_colGroup <- lapply(tissues, function(tissue) {
      group_name <- gsub("_", " ", tissue)
      colGroup(name = group_name, columns = c(
        paste0("log2FC_", tissue),
        paste0("p_value_", tissue),
        paste0("p_adj_", tissue)))})
    
    return(custom_colGroup)
  }
  
  return(NULL)
}


set_pathway_colors <- function(){
  pathway_colors <- list(
      "RTK Signaling" = "#98FB98",
      "Metabolic Signaling" = "#00CED1",
      "Epigenetics" = "#DA70D6",
      "PI3K/AKT/mTOR Signaling" = "#008000",
      "Apoptosis" = "#FF7F00",
      "MAPK Signaling" = "#800000",
      "WNT signaling" = "#6495ED",
      "Hormone Signaling" = "#DC143C",
      "DNA damage/repair" = "#87CEEB",
      "Cell cycle control" = "#FB9A99",
      "Immune Checkpoints" = "#A9A9A9",
      "TGF-B Signaling" = "#FFD700",
      "JAK/STAT Signaling" = "#BDB76B",
      "Hedgehog Signaling" = "#8B008B",
      "Non-receptor kinases" = "#6A5ACD",
      "Kinase Fusions" = "#D2691E",
      # "non-WNT/non-SHH medulloblastoma-related markers" = "khaki2",
      "Immune Response" = "#4682B4")

  return(pathway_colors)
}

#' @export
create_clinvar_filter <- function(data, selected_clinvar_sig) {  #data[is.na(clinvar_sig) | clinvar_sig == "Benign",]
  if ("missing_value" %in% selected_clinvar_sig) {
    if (length(selected_clinvar_sig) == 1) {
      return(data[is.na(clinvar_sig) | trimws(clinvar_sig) == ""])
    } else {
      # Pokud jsou vybrány i jiné hodnoty
      other_terms <- selected_clinvar_sig[selected_clinvar_sig != "missing_value"]
      
      if (length(other_terms) > 0) {
        conditions <- sapply(other_terms, function(term) {
          escaped_term <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", term)
          paste0("(^|[|/_])", escaped_term, "($|[|/_])")
        })
        final_pattern <- paste(conditions, collapse = "|")
        
        # Kombinace missing values a pattern matching
        return(data[is.na(clinvar_sig) | trimws(clinvar_sig) == "" | 
                      (!is.na(clinvar_sig) & grepl(final_pattern, clinvar_sig, ignore.case = TRUE))])
      }
    }
    
  } else {
  
    # Normální případ - žádné "missing_value"
    conditions <- sapply(selected_clinvar_sig, function(term) {
      escaped_term <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", term)
      paste0("(^|[|/_])", escaped_term, "($|[|/_])")
    })
    
    final_pattern <- paste(conditions, collapse = "|")
    
    filtered_data <- data[!is.na(clinvar_sig) & 
                            grepl(final_pattern, clinvar_sig, ignore.case = TRUE)]
    return(filtered_data)
  }
}


#' @export
create_consequence_filter <- function(data, selected_consequences, include_missing = FALSE) {

  if(!"consequence_trimws" %in% names(data)) {
    data$consequence_trimws <- data$Consequence
  }
  
  # Vytvoříme logický vektor pro filtrování
  keep_rows <- sapply(data$consequence_trimws, function(x) {
    if(is.null(x) || length(x) == 0) return(FALSE)
    
    # Pokud obsahuje missing_value
    if(any(x == "missing_value")) {
      # Pokud chceme zahrnout missing values, vracíme TRUE
      if(include_missing) return(TRUE)
      # Jinak kontrolujeme, jestli jsou i jiné hodnoty než missing_value
      non_missing_values <- x[x != "missing_value"]
      if(length(non_missing_values) == 0) return(FALSE)
      return(any(non_missing_values %in% selected_consequences))
    }
    # Standardní kontrola
    any(x %in% selected_consequences)
  })
  
  filtered_data <- data[keep_rows]
  
  return(filtered_data)
}