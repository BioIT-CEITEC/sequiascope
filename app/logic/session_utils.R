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

# ============================================
# OBECNÝ MODUL REGISTRY SYSTÉM
# ============================================

#' @export
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
  
  # Použij předaný flag nebo vytvořte nový
  restoring_session <- if (!is.null(is_restoring)) is_restoring else reactiveVal(FALSE)
  
  get_session_data <- reactive({
    lapply(selected_inputs, function(x) x())
  })
  
  restore_session_data <- function(data) {
    message("🔄 Starting session restore")
    
    # Nastav flag, že probíhá restore
    restoring_session(TRUE)
    
    # 1) naplň reaktivní hodnoty (model)
    for (nm in names(data)) {
      if (!is.null(data[[nm]]) && nm %in% names(selected_inputs)) {
        message(sprintf("Restoring %s with value: %s", nm, paste(safe_extract(data[[nm]]), collapse = ", ")))
        selected_inputs[[nm]](safe_extract(data[[nm]]))
      }
    }
    
    # 2) Použij invalidateLater pro zajištění, že UI bude obnoveno až po všech reaktivních aktualizacích
    if (!is.null(filter_state$restore_ui_inputs)) {
      # Počkaj na několik flush cyklů
      session$onFlushed(function() {
        session$onFlushed(function() {
          message("🎯 Restoring UI inputs")
          filter_state$restore_ui_inputs(data)
          
          # Po dokončení restore resetuj flag
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
# OBECNÉ LOAD/SAVE FUNKCE
# ============================================

#' @export
load_session <- function(file, shared_data, module_configs = NULL) {
  if (!file.exists(file)) return(invisible(NULL))
  session_data <- jsonlite::read_json(file, simplifyVector = TRUE)
  
  message("📂 Loading session from file: ", file)
  
  # Pokud není specifikována konfigurace, použij výchozí
  if (is.null(module_configs)) {
    module_configs <- get_default_module_configs()
  }
  
  # Projdi všechny typy modulů
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

# Pomocná funkce pro restore jednoho typu modulu
restore_module_type <- function(module_type, session_data, shared_data, config) {
  message(sprintf("🔄 Restoring %s modules", module_type))
  
  registry_key <- paste0(module_type, "_modules")
  pending_key <- paste0(module_type, "_pending")
  
  reg <- shared_data[[registry_key]]()
  pend <- shared_data[[pending_key]]()
  
  for (module_id in names(session_data)) {
    message(sprintf("Loading %s data for module: %s", module_type, module_id))
    state <- session_data[[module_id]]
    m <- reg[[module_id]]
    
    if (!is.null(m)) {
      # Modul už existuje, přímo restore
      if (!is.null(m$restore_session_data)) m$restore_session_data(state)
      if (!is.null(m$filter_state) && !is.null(m$filter_state$restore_ui_inputs)) {
        m$filter_state$restore_ui_inputs(state)
      }
    } else {
      # Modul ještě neexistuje, ulož do pending
      pend[[module_id]] <- state
    }
  }
  
  shared_data[[pending_key]](pend)
  
  # Speciální post-processing pokud je definován v konfiguraci
  if (!is.null(config$post_restore)) {
    config$post_restore(session_data, shared_data)
  }
}

#' @export
save_session <- function(file = "session_data.json", shared_data, module_types = NULL) {
  
  # Pokud není specifikováno, použij všechny dostupné typy
  if (is.null(module_types)) {
    module_types <- get_available_module_types(shared_data)
  }
  
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
# KONFIGURAČNÍ FUNKCE
# ============================================

#' @export
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
        shared_data$germline.variants(combined_somatic)
      }
    ),
    
    fusion = list(
      post_restore = function(session_data, shared_data) {
        # Budoucí handling pro fusion
        # ...
      }
    ),
    
    expression = list(
      post_restore = function(session_data, shared_data) {
        # Budoucí handling pro expression
        # ...
      }
    )
  )
}

#' @export
get_available_module_types <- function(shared_data) {
  # Automaticky detekuj dostupné typy modulů ze shared_data
  all_keys <- names(shared_data)
  module_keys <- all_keys[grepl("_modules$", all_keys)]
  gsub("_modules$", "", module_keys)
}

# ============================================
# ZPĚTNĚ KOMPATIBILNÍ FUNKCE
# ============================================

# register_somatic_module <- function(shared_data, patient, methods) {
#   registry <- create_module_registry(shared_data, "somatic")
#   registry$register(patient, methods)
# }
# 
# register_upload_module <- function(shared_data, module_id, methods) {
#   registry <- create_module_registry(shared_data, "upload")
#   registry$register(module_id, methods)
# }

# Obecná funkce pro registraci jakéhokoli typu modulu
#' @export
register_module <- function(shared_data, module_type, module_id, methods) {
  registry <- create_module_registry(shared_data, module_type)
  registry$register(module_id, methods)
}