# Waiter Progress Bar Helpers
# Functions for managing waiter with progress bar and DOM-based completion detection

box::use(
  shiny[...],
  waiter[waiter_show, waiter_hide, spin_fading_circles],
  htmltools[tagList, tags, h3]
)

#' Show waiter with progress bar
#' 
#' @param session Shiny session object
#' @export
show_waiter_with_progress <- function(session) {
  waiter_show(
    id = NA,
    html = tagList(
      spin_fading_circles(),
      h3("Loading and processing data...", style = "color: white; margin-top: 20px;"),
      tags$div(
        id = "waiter-progress",
        style = "width: 300px; margin: 20px auto;",
        tags$div(
          style = "background: rgba(255,255,255,0.2); border-radius: 10px; padding: 3px;",
          tags$div(
            id = "waiter-progress-bar",
            style = "width: 0%; height: 20px; background: #74c0fc; border-radius: 7px; transition: width 0.3s ease;"
          )
        ),
        tags$div(
          id = "waiter-progress-text",
          style = "color: white; text-align: center; margin-top: 10px; font-size: 14px;",
          "0%"
        )
      )
    ),
    color = "rgba(0, 0, 0, 0.8)"
  )
}

#' Update waiter progress
#' 
#' @param session Shiny session object
#' @param percent Progress percentage (0-100)
#' @param text Optional text to display (defaults to "X%")
#' @export
update_waiter_progress <- function(session, percent, text = NULL) {
  session$sendCustomMessage("waiter-update", list(
    percent = percent,
    text = if (is.null(text)) paste0(percent, "%") else text
  ))
}

#' Request notification when Summary tab is rendered
#' 
#' @param session Shiny session object
#' @param ns Namespace function
#' @export
wait_for_summary_rendered <- function(session, ns) {
  session$sendCustomMessage("wait-for-summary", list(inputId = ns("summary_rendered")))
}

#' Get JavaScript code for waiter progress handlers
#' 
#' @return HTML script tag with JavaScript handlers
#' @export
get_waiter_js <- function() {
  tags$script(HTML("
    Shiny.addCustomMessageHandler('waiter-update', function(data) {
      var bar = document.getElementById('waiter-progress-bar');
      var text = document.getElementById('waiter-progress-text');
      if (bar) bar.style.width = data.percent + '%';
      if (text) text.textContent = data.text;
    });
    
    // Monitor when Summary tab is fully rendered
    Shiny.addCustomMessageHandler('wait-for-summary', function(data) {
      console.log('Waiting for Summary tab to render...');
      console.log('Received inputId:', data.inputId);
      
      // Wait for tab switch and DOM update
      setTimeout(function() {
        // Check if summary boxes are rendered
        var checkRendered = setInterval(function() {
          var summaryBoxes = document.querySelectorAll('[id*=\"summary_table\"]');
          if (summaryBoxes.length > 0) {
            console.log('Summary tab fully rendered!');
            clearInterval(checkRendered);
            Shiny.setInputValue(data.inputId, Math.random(), {priority: 'event'});
          }
        }, 100); // Check every 100ms
        
        // Safety timeout after 5 seconds
        setTimeout(function() {
          clearInterval(checkRendered);
          console.log('Summary render timeout - forcing completion');
          Shiny.setInputValue(data.inputId, Math.random(), {priority: 'event'});
        }, 5000);
      }, 100);
    });
  "))
}
