# app/logic/helper_prerun_dialog.R

box::use(
  shiny[showNotification, isolate],
  shinyalert[shinyalert],
)

box::use(
  app/logic/prerun_fusion[fusion_patients_to_prerun, check_fusion_status, cleanup_patient_fusion_outputs],
  app/logic/helper_main[get_patients, get_files_by_patient],
)

#' Check for existing fusion outputs and show resume/clean-start dialog if needed.
#'
#' @param confirmed_paths Data frame with confirmed file paths from upload_data.
#' @param output_dir Base output directory (e.g. "output_files").
#' @param shared_data Shiny reactiveValues shared across modules.
#' @return TRUE if dialog was shown and caller should return(); FALSE if no dialog needed.
#' @export
check_and_show_fusion_dialog <- function(confirmed_paths, output_dir, shared_data) {
  
  data_path <- isolate(shared_data$data_path())
  if (is.null(data_path) || data_path == "") return(FALSE)
  
  dataset_name <- basename(data_path)
  dataset_name <- gsub("[^A-Za-z0-9_-]", "_", dataset_name)
  potential_session_dir <- file.path(output_dir, "sessions", dataset_name)
  
  fusion_patients <- get_patients(confirmed_paths, "fusion")
  
  if (!dir.exists(potential_session_dir) || length(fusion_patients) == 0) return(FALSE)
  
  patients_to_run <- fusion_patients_to_prerun(fusion_patients, potential_session_dir)
  if (length(patients_to_run) == 0) return(FALSE)
  
  fusion_files <- get_files_by_patient(confirmed_paths, "fusion")
  
  existing_outputs <- list()
  total_existing_snapshots <- 0
  total_expected_fusions <- 0
  
  for (patient_id in patients_to_run) {
    file_list <- fusion_files[[patient_id]]
    if (!is.null(file_list$fusion) && length(file_list$fusion) > 0) {
      status <- check_fusion_status(patient_id, potential_session_dir, file_list$fusion[1], file_list$arriba)
      if (status$exists) {
        existing_outputs[[patient_id]] <- status
        total_existing_snapshots <- total_existing_snapshots + status$completed_snapshots
        total_expected_fusions   <- total_expected_fusions   + status$total_fusions
      }
    }
  }
  
  if (length(existing_outputs) == 0) return(FALSE)
  
  message("[SESSION] Detected existing fusion outputs for ", length(existing_outputs), " patient(s)")
  
  patient_info <- sapply(names(existing_outputs), function(pid) {
    s <- existing_outputs[[pid]]
    parts <- character(0)
    if (s$total_fusions > 0 || s$completed_snapshots > 0)
      parts <- c(parts, sprintf("IGV %d/%d", s$completed_snapshots, s$total_fusions))
    if (s$total_arriba > 0 || s$completed_arriba > 0)
      parts <- c(parts, sprintf("Arriba %d/%d", s$completed_arriba, s$total_arriba))
    paste0(pid, if (length(parts) > 0) paste0(": ", paste(parts, collapse = ", ")) else "")
  })
  
  info_text <- sprintf(
    "Session '%s' contains partially processed fusion data:<br><br>%s<br><br>Would you like to resume where it left off or start fresh?",
    basename(potential_session_dir),
    paste(patient_info, collapse = "<br>")
  )
  
  shinyalert(
    title = "Existing Session Detected",
    text = info_text,
    type = "info",
    showCancelButton = TRUE,
    showConfirmButton = TRUE,
    confirmButtonText = "Resume",
    cancelButtonText = "Clean Start",
    closeOnClickOutside = FALSE,
    html = TRUE,
    callbackR = function(resume) {
      if (is.logical(resume) && !resume) {
        message("[USER CHOICE] Clean Start - cleaning up existing outputs")
        for (patient_id in names(existing_outputs)) {
          cleanup_patient_fusion_outputs(patient_id, potential_session_dir)
        }
        showNotification("Cleaned existing outputs - starting fresh", type = "message", duration = 3)
      } else if (is.logical(resume) && resume) {
        message("[USER CHOICE] Resume - continuing from last checkpoint")
        showNotification(
          sprintf("Resuming - %d/%d snapshots already complete", total_existing_snapshots, total_expected_fusions),
          type = "message", duration = 3
        )
      } else {
        message("[USER CHOICE] Cancelled - aborting fusion preprocessing")
        shared_data$pending_data_load(NULL)
        return()
      }
      # Reset fusion_prerun_started so the observe() guard passes.
      # This also serves as a reactive invalidation signal — the observe reads
      # fusion_prerun_started(), so setting it FALSE re-fires the observer even
      # when fusion_prerun_user_confirmed was already TRUE from a previous run.
      shared_data$fusion_prerun_started(FALSE)
      shared_data$fusion_prerun_user_confirmed(TRUE)
    }
  )
  
  shared_data$pending_data_load(confirmed_paths)
  return(TRUE)
}
