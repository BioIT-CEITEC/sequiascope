# app/logic/waiters.R

box::use(
  shiny[tagList],
  waiter[useWaiter, Waiter, spin_fading_circles, spin_5, waiter_show, waiter_hide],
  shinycssloaders[withSpinner],
)

#' @export
use_spinner <- function(ui_element){
  spinner <- withSpinner(ui_element,type=3,color = "#74c0fc",color.background = "#EEEEEE" )
  return(spinner)
}

#' @export
use_waiter <- function() {
  useWaiter()
}

#' @export
show_waiter <- function(id, text = "Loading...") {
  waiter_show(
    id = id,
    html = tagList(
      spin_fading_circles(),
      shiny::h3(text, style = "color: white; margin-top: 20px;")
    ),
    color = "rgba(0, 0, 0, 0.8)"
  )
}

#' @export
hide_waiter <- function(id) {
  waiter_hide(id)
}

