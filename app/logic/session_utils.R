# app/logic/session_utils.R
box::use(
  shiny[reactive,isolate,showNotification, getDefaultReactiveDomain, reactiveVal],
  jsonlite[read_json,write_json],
  data.table[rbindlist, as.data.table]
)

#' @export
safe_extract <- function(x) {
  if (is.list(x) && length(x) == 0) return(NULL)
  else return(x)
}
#' @export
nz <- function(x, default) if (is.null(x) || !length(x)) default else x
#' @export
ch <- function(x) trimws(as.character(x))

# ============================================
# GENERAL MODUL REGISTR SYSTEM
# ============================================

create_module_registry <- function(shared_data, module_type) {
  list(
    register = function(module_id, methods) {
      registry_key <- paste0(module_type, "_modules")
      pending_key <- paste0(module_type, "_pending")
      
      # Přidej do registry
      reg <- isolate(shared_data[[registry_key]]()); if (is.null(reg)) reg <- list()
      reg[[module_id]] <- methods
      shared_data[[registry_key]](reg)
      
      # Zkontroluj pending restore
      pend <- isolate(shared_data[[pending_key]]())
      if (!is.null(pend) && !is.null(pend[[module_id]])) {
        state <- pend[[module_id]]
        if (!is.null(methods$restore_session_data)) methods$restore_session_data(state)
        pend[[module_id]] <- NULL
        shared_data[[pending_key]](pend)
      }
    },
    
    get_registry = function() {
      registry_key <- paste0(module_type, "_modules")
      isolate(shared_data[[registry_key]]())
    },
    
    get_pending = function() {
      pending_key <- paste0(module_type, "_pending")
      isolate(shared_data[[pending_key]]())
    },
    
    set_pending = function(pending_data) {
      pending_key <- paste0(module_type, "_pending")
      shared_data[[pending_key]](pending_data)
    }
  )
}

#' @export
create_session_handlers <- function(selected_inputs, filter_state, is_restoring = NULL, session = getDefaultReactiveDomain()) {

  restoring_session <- if (!is.null(is_restoring)) is_restoring else reactiveVal(FALSE)
  
  get_session_data <- reactive({
    lapply(selected_inputs, function(x) x())
  })
  
  restore_session_data <- function(data) {
    message("🔄 Starting session restore")

    restoring_session(TRUE)

    for (nm in names(data)) {
      if (!is.null(data[[nm]]) && nm %in% names(selected_inputs)) {
        selected_inputs[[nm]](safe_extract(data[[nm]]))
      }
    }

    if (!is.null(filter_state$restore_ui_inputs)) {
      session$onFlushed(function() {
        session$onFlushed(function() {
          filter_state$restore_ui_inputs(data)

          session$onFlushed(function() {
            restoring_session(FALSE)
            message("✅ Session restore completed")
          }, once = TRUE)
          
        }, once = TRUE)
      }, once = TRUE)
    } else {
      restoring_session(FALSE)
    }
  }
  
  list(
    get_session_data = get_session_data,
    restore_session_data = restore_session_data,
    is_restoring = restoring_session
  )
}

# ============================================
# GENERAL LOAD/SAVE FUNCTIONS
# ============================================

#' @export
load_session <- function(file, shared_data, module_configs = NULL) {
  if (!file.exists(file)) return(invisible(NULL))
  session_data <- read_json(file, simplifyVector = TRUE)

  if (is.null(module_configs)) module_configs <- get_default_module_configs()

  for (module_type in names(module_configs)) {
    if (!is.null(session_data[[module_type]])) {
      config <- module_configs[[module_type]]
      restore_module_type(
        module_type = module_type,
        session_data = session_data[[module_type]],
        shared_data = shared_data,
        config = config
      )
    }
  }
}

restore_module_type <- function(module_type, session_data, shared_data, config) {
  
  registry_key <- paste0(module_type, "_modules")
  pending_key <- paste0(module_type, "_pending")
  
  reg <- shared_data[[registry_key]]()
  pend <- shared_data[[pending_key]]()
  
  for (module_id in names(session_data)) {
    state <- session_data[[module_id]]
    m <- reg[[module_id]]
    
    if (!is.null(m)) {
      if (!is.null(m$restore_session_data)) m$restore_session_data(state)
      if (!is.null(m$filter_state) && !is.null(m$filter_state$restore_ui_inputs)) {
        m$filter_state$restore_ui_inputs(state)
      }
    } else {
      pend[[module_id]] <- state
    }
  }
  
  shared_data[[pending_key]](pend)
  
  if (!is.null(config$post_restore)) config$post_restore(session_data, shared_data)
}

#' @export
save_session <- function(file = "session_data.json", shared_data, module_types = NULL) {
  
  if (is.null(module_types)) module_types <- get_available_module_types(shared_data)
  
  session <- list()
  
  for (module_type in module_types) {
    registry_key <- paste0(module_type, "_modules")
    reg <- shared_data[[registry_key]]()
    
    if (!is.null(reg) && length(reg) > 0) {
      module_data <- lapply(names(reg), function(module_id) {
        isolate(reg[[module_id]]$get_session_data())
      })
      names(module_data) <- names(reg)
      session[[module_type]] <- module_data
    }
  }
  
  write_json(session, file, auto_unbox = TRUE, pretty = TRUE, na = "null")
  showNotification(paste("Session saved to", file), type = "message")
}

# ============================================
# KONFIGURATION FUNCTIONS
# ============================================

get_default_module_configs <- function() {
  list(
    somatic = list(
      post_restore = function(session_data, shared_data) {
        combined_somatic <- rbindlist(
          lapply(names(session_data), function(pat) {
            st <- session_data[[pat]]
            sv <- st$selected_vars
            if (is.null(sv)) return(NULL)
            dt <- as.data.table(sv)
            if (!"sample" %in% names(dt)) dt[, sample := pat]
            dt
          }),
          use.names = TRUE, fill = TRUE
        )
        shared_data$somatic.variants(combined_somatic)
      }
    ),
    
    upload = list(
      post_restore = NULL  # Upload nepotřebuje speciální handling
    ),
    
    germline = list(
      post_restore = function(session_data, shared_data) {
        combined_germline <- rbindlist(
          lapply(names(session_data), function(pat) {
            st <- session_data[[pat]]
            sv <- st$selected_vars
            if (is.null(sv)) return(NULL)
            dt <- as.data.table(sv)
            if (!"sample" %in% names(dt)) dt[, sample := pat]
            dt
          }),
          use.names = TRUE, fill = TRUE
        )
        shared_data$germline.variants(combined_germline)
      }
    ),
    
    fusion = list(
      post_restore = function(session_data, shared_data) {
        combined_fusion <- rbindlist(
          lapply(names(session_data), function(pat) {
            st <- session_data[[pat]]
            sv <- st$selected_vars
            if (is.null(sv)) return(NULL)
            dt <- as.data.table(sv)
            if (!"sample" %in% names(dt)) dt[, sample := pat]
            dt
          }),
          use.names = TRUE, fill = TRUE
        )
        shared_data$fusion.variants(combined_fusion)
      }
    ),
    # v get_default_module_configs() -> expression$post_restore = function(session_data, shared_data) { ... }
    
    expression = list(
      post_restore = function(session_data, shared_data) {
        as_dt_safe <- function(x) {
          if (is.null(x)) return(NULL)
          if (is.data.frame(x)) return(as.data.table(x))
          if (is.list(x) && length(x) > 0) return(as.data.table(x))
          NULL
        }
        
        all_genes_data <- list()
        goi_data <- list()
        
        for (patient in names(session_data)) {
          patient_data <- session_data[[patient]]
          
          # ALL GENES
          if (!is.null(patient_data$all_genes)) {
            sel <- patient_data$all_genes$selected_genes
            dt  <- as_dt_safe(sel)
            if (!is.null(dt) && nrow(dt) > 0) {
              if (!"sample" %in% names(dt)) dt[, sample := patient]
              all_genes_data[[patient]] <- dt
            }
          }
          
          # GOI
          if (!is.null(patient_data$goi)) {
            sel <- patient_data$goi$selected_genes
            dt  <- as_dt_safe(sel)
            if (!is.null(dt) && nrow(dt) > 0) {
              if (!"sample" %in% names(dt)) dt[, sample := patient]
              goi_data[[patient]] <- dt
            }
          }
        }
        
        if (length(all_genes_data) > 0) {
          shared_data$expression.variants.all(rbindlist(all_genes_data, use.names = TRUE, fill = TRUE))
        }
        if (length(goi_data) > 0) {
          shared_data$expression.variants.goi(rbindlist(goi_data, use.names = TRUE, fill = TRUE))
        }
      }
    )
    
    # expression = list(
    #   post_restore = function(session_data, shared_data) {
    #     # Sestavuj data pro all_genes a goi odděleně
    #     all_genes_data <- list()
    #     goi_data <- list()
    #     
    #     for (patient in names(session_data)) {
    #       patient_data <- session_data[[patient]]
    #       
    #       # All genes data
    #       if (!is.null(patient_data$all_genes) && !is.null(patient_data$all_genes$selected_genes)) {
    #         all_genes_selected <- patient_data$all_genes$selected_genes
    #         if (!is.null(all_genes_selected) && nrow(all_genes_selected) > 0) {
    #           dt <- as.data.table(all_genes_selected)
    #           if (!"sample" %in% names(dt)) dt[, sample := patient]
    #           all_genes_data[[patient]] <- dt
    #         }
    #       }
    #       
    #       # GOI data
    #       if (!is.null(patient_data$goi) && !is.null(patient_data$goi$selected_genes)) {
    #         goi_selected <- patient_data$goi$selected_genes
    #         if (!is.null(goi_selected) && nrow(goi_selected) > 0) {
    #           dt <- as.data.table(goi_selected)
    #           if (!"sample" %in% names(dt)) dt[, sample := patient]
    #           goi_data[[patient]] <- dt
    #         }
    #       }
    #     }
    #     
    #     if (length(all_genes_data) > 0) {
    #       combined_all_genes <- rbindlist(all_genes_data, use.names = TRUE, fill = TRUE)
    #       shared_data$expression.variants.all(combined_all_genes)
    #     }
    #     
    #     if (length(goi_data) > 0) {
    #       combined_goi <- rbindlist(goi_data, use.names = TRUE, fill = TRUE)
    #       shared_data$expression.variants.goi(combined_goi)
    #     }
    #   }
    # )
  )
}


get_available_module_types <- function(shared_data) {
  all_keys <- names(shared_data)
  module_keys <- all_keys[grepl("_modules$", all_keys)]
  gsub("_modules$", "", module_keys)
}

#' @export
register_module <- function(shared_data, module_type, module_id, methods) {
  registry <- create_module_registry(shared_data, module_type)
  registry$register(module_id, methods)
}