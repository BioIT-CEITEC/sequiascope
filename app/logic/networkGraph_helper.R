
box::use(
  jsonlite[fromJSON, toJSON],
  data.table[fread,setnames],
  httr[GET, status_code, content],
  stats[setNames]
)
box::use(
  app/logic/load_data[get_inputs]
)

string_cache <- new.env(parent = emptyenv())

# Funkce pro získání interakcí mezi proteiny z STRING API
#' @export
get_string_interactions <- function(proteins, species = 9606, chunk_size = 100, delay = 0.2) {
  # 🔑 VALIDACE: Zkontrolovat, že proteins je validní
  if (is.null(proteins) || length(proteins) == 0) {
    message("⚠️ get_string_interactions: No proteins provided, returning empty data.frame")
    return(data.frame())
  }
  
  # Odstranit NA, NULL a prázdné stringy
  proteins <- proteins[!is.na(proteins) & proteins != ""]
  
  if (length(proteins) == 0) {
    message("⚠️ get_string_interactions: All proteins were invalid (NA or empty), returning empty data.frame")
    return(data.frame())
  }
  
  # Funkce pro odesílání jednotlivých požadavků
  cache_key <- paste(sort(proteins), collapse = "|")
  
  # 🔑 BEZPEČNÁ KONTROLA cache - zkontrolovat, že cache_key je validní string
  if (!is.character(cache_key) || length(cache_key) != 1 || cache_key == "") {
    message("⚠️ get_string_interactions: Invalid cache_key, skipping cache check")
  } else if (exists(cache_key, envir = string_cache)) {
    message("Using cached STRING interactions")
    return(get(cache_key, envir = string_cache))
  }
  
  
  fetch_interactions <- function(protein_chunk) {
    base_url <- "https://string-db.org/api/json/network?"
    query <- paste0("identifiers=", paste(protein_chunk, collapse = "%0D"), "&species=", species)
    url <- paste0(base_url, query)
    
    Sys.sleep(delay)
    response <- GET(url)
    
    if (status_code(response) == 200) {
      content <- fromJSON(content(response, as = "text"))
      return(content)
    } else {
      stop("Request failed with status: ", status_code(response))
    }
  }
  
  # Rozdělení proteinů na bloky podle chunk_size (občas je proteinů moc)
  protein_chunks <- split(proteins, ceiling(seq_along(proteins) / chunk_size))
  all_interactions <- do.call(rbind, lapply(protein_chunks, fetch_interactions))
  
  assign(cache_key, all_interactions, envir = string_cache)
  
  return(all_interactions)
}

# library(data.table)
# library(httr)
# library(jsonlite)
# subTissue_dt <- fread("input_files/MOII_e117/RNAseq21_NEW/MR1507/Blood_all_genes_oneRow.tsv")
# synchronized_nodes <- c("CS","TP53")
# current_nodes <- c("CS","TP53")
# synchronized_nodes <- c("TP53")
# current_nodes <- c("TP53")
# interactions <- get_string_interactions(unique(subTissue_dt[feature_name %in% synchronized_nodes,feature_name]))
# proteins <- current_nodes
# fc_values <- unique(subTissue_dt[feature_name %in% current_nodes, log2FC])
# tab <- unique(subTissue_dt[feature_name %in% current_nodes, .(feature_name,log2FC)])


#' @export
prepare_cytoscape_network <- function(interactions, tab, proteins = NULL) {

    if(is.null(proteins)) proteins <- tab[,feature_name]

    interaction_nodes <- unique(c(interactions$preferredName_A, interactions$preferredName_B))
    all_nodes <- unique(c(interaction_nodes, proteins))

    log2FC_map <- setNames(tab[,log2FC], tab[,feature_name])
    log2FC_values <- sapply(all_nodes, function(node) {
      if (node %in% names(log2FC_map)) {
        log2FC_map[node]
      } else {
        NA  # Hodnota NA pro uzly mimo tabulku
      }
    }, USE.NAMES = FALSE)

    names(log2FC_values) <- all_nodes
    
    # Spočítání stupně (degree) pro každý uzel - singletony mají stupen 0
    degrees <- table(c(interactions$preferredName_A, interactions$preferredName_B))
    degree_values <- sapply(all_nodes, function(x) ifelse(x %in% names(degrees), degrees[x], 0))

    node_data <- data.frame(
      id = all_nodes,
      name = all_nodes,
      label = all_nodes,
      log2FC = log2FC_values,
      degree = degree_values,  # Přidání stupně (degree) uzlu
      stringsAsFactors = FALSE
    )

    if (is.null(interactions) || !is.data.frame(interactions) || nrow(interactions) == 0) {
      edges <- data.frame(
        source = character(0),
        target = character(0),
        interaction = character(0),
        stringsAsFactors = FALSE
      )
    } else {
      edges <- data.frame(
        source = interactions$preferredName_A,
        target = interactions$preferredName_B,
        interaction = "interaction",
        stringsAsFactors = FALSE
      )
    }

  node_data <- node_data[match(proteins, node_data$id, nomatch = 0), ]
  edges <- edges[edges$source %in% proteins & edges$target %in% proteins, ]
  
  json_data <- list(
    elements = list(
      nodes = lapply(seq_len(nrow(node_data)), function(i) {
        list(data = as.list(node_data[i, ]))
      }),
      edges = lapply(seq_len(nrow(edges)), function(i) {
        list(data = as.list(edges[i, ]))
      })
    )
  )

  return(json_data)
}

#' @export
get_pathway_list <- function(expr_tag, goi_dt = NULL, run = NULL) {

  # Bezpečná kontrola parametru run
  if (!is.null(run) && length(run) > 0 && run == "docker") {
    path <- "/input_files/kegg_tab.tsv"
  } else {
    path <- paste0(getwd(), "/input_files/kegg_tab.tsv")
  }

  
  # Zpracování pro ALL GENES
  if (identical(expr_tag, "all_genes")) {
    if (!file.exists(path)) {
      stop("Soubor ", path, " nebyl nalezen.")
    }
    dt <- fread(path)
    return(sort(unique(dt$kegg_paths_name)))
  }
  
  # Zpracování pro GENES OF INTEREST
  if (identical(expr_tag, "genes_of_interest")) {
    # 1️⃣ goi_dt existuje a má sloupec "pathway"
    if (!is.null(goi_dt) && "pathway" %in% colnames(goi_dt)) {
      return(sort(unique(goi_dt$pathway)))
    }
    
    # 2️⃣ goi_dt neobsahuje pathway, použij KEGG tabulku
    if (file.exists(path)) {
      dt <- fread(path)
      return(sort(unique(dt$kegg_paths_name)))
    } else {
      stop("Soubor ", path, " nebyl nalezen.")
    }
  }
  
  # Pokud expr_tag neodpovídá známým hodnotám
  warning("Invalid expr_tag. Please use 'all_genes' or 'genes_of_interest'.")
  return(character(0))
}

