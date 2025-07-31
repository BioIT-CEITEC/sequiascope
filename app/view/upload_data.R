box::use(
  shiny[NS,tagList,fileInput,moduleServer,observe,reactive,textOutput,updateTextInput,renderText,req,textInput,observeEvent,textAreaInput,column,fluidRow,reactiveVal,isTruthy],
  htmltools[tags,HTML,div,span],
  shinyFiles[shinyDirButton,shinyDirChoose,parseDirPath,getVolumes],
  shinyWidgets[prettySwitch,updatePrettySwitch],
  bs4Dash[addPopover,box],
  stringi[stri_detect_regex],
  stringr[str_detect,regex],
  shinyalert[shinyalert]
  # shinyjs[useShinyjs,runjs],
)

ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .folderInput-container {
          display: flex;
          align-items: baseline;
          gap: 0px;
        }
      "))),
      column(4,
         box(width = 12, headerBorder = FALSE, collapsible = FALSE,
            tags$label("Select directory with patients data:"),
            div(class = "folderInput-container",
              shinyDirButton(ns("dir"), "Browse", "Please select directory with data", class = "btn btn-default"),
              textInput(ns("dir_path"), NULL, placeholder = "No directory selected", width = "100%")),
            tags$br(),
            div(style = "display: flex; align-items: baseline; width: 100%; gap: 10px;",
                tags$label("Write patients id:"),
                tags$div(id = ns("helpPopover_addPatient"),tags$i(class = "fa fa-question fa-xs", style = "color: #2596be;"))),
            div(style = "width: 25rem;",
              textAreaInput(ns("patient_list"), NULL, placeholder = "Add patients name here...", rows = 1, resize = "vertical", width = "100%")),
            tags$br(),
            tags$label("Select datasets for visualization:"),
            div(style = "flex-direction: column; display: flex; align-items: baseline;",
               prettySwitch(ns("somVariants_data"), label = "Somatic variant calling", status = "primary", slim = TRUE),
               prettySwitch(ns("germVariants_data"), label = "Germline variant calling", status = "primary", slim = TRUE),
               prettySwitch(ns("fusion_data"), label = "Fusion genes detection", status = "primary", slim = TRUE),
               prettySwitch(ns("expression_data"), label = "Expression profile", status = "primary", slim = TRUE))
            )),
    column(8,
           box(width = 12, headerBorder = FALSE, collapsible = FALSE,
               box(elevation = 2, collapsible = FALSE, headerBorder = FALSE,width = 12,
                title = span("Somatic varcall", class = "category")),
               box(elevation = 2, collapsible = FALSE, headerBorder = FALSE,width = 12,
                   title = span("Germline varcall", class = "category")),
               box(elevation = 2, collapsible = FALSE, headerBorder = FALSE,width = 12,
                   title = span("Fusion genes", class = "category")),
               box(elevation = 2, collapsible = FALSE, headerBorder = FALSE,width = 12,
                   title = span("Expression profile", class = "category"))
           ))
    
  )
}
server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    wd <- c(home = getwd())
    shinyDirChoose(input, "dir", roots = wd)
    
    # reactiveVal pro seznam souborů
    matching_files <- reactiveVal(character(0))
    
    observeEvent(input$dir, {
      path <- parseDirPath(wd, input$dir)
      updateTextInput(session, "dir_path", value = path)
    })
    
    isValidInput <- function(x) {
      !is.null(x) && length(x) > 0 && any(nzchar(x))
    }
    
    observeEvent(list(input$dir, input$patient_list), {
      if (isValidInput(input$dir) && isValidInput(input$patient_list)) {
        path <- parseDirPath(wd, input$dir)
        print("Im here.")
        print(path)
        print(input$patient_list)
        
        all_files <- list.files(path, full.names = TRUE, recursive = TRUE)
        pattern <- paste(input$patient_list, collapse = "|")
        
        matches <- stringi::stri_detect_regex(all_files, pattern)
        matching_files(all_files[matches])  # << uloží do reactiveVal
      }
    })
    
    observeEvent(input$somVariants_data, {
      
      if (!isValidInput(input$dir) || !isValidInput(input$patient_list)) {
        shinyalert(
          title = "Missing inputs",
          text = "Please select a directory and at least one patient before enabling this module.",
          type = "error"
        )
        updatePrettySwitch(session, "somVariants_data", value = FALSE)
        return(NULL)
      }
      
      if (isTruthy(input$somVariants_data)) {
        somatic_inputFiles <- matching_files()[ 
          str_detect(matching_files(), "\\.(vcf|tsv)$") & 
            str_detect(matching_files(), regex("somatic", ignore_case = TRUE)) 
        ]
        bam_tumorFiles <- matching_files()[
          str_detect(matching_files(), "\\.(bam|bai)$") &
            str_detect(matching_files(), regex("somatic|tumor|FFPE", ignore_case = TRUE))
        ]
        bam_controlFiles <- matching_files()[
          str_detect(matching_files(), "\\.(bam|bai)$") &
            str_detect(matching_files(), regex("somatic|normal|control|krev", ignore_case = TRUE))
        ]
        print(somatic_inputFiles)
      }
    }, ignoreInit = TRUE)  # <<< přidané
    
    
    # observeEvent(input$somVariants_data, {
    #   req(matching_files(), input$dir, input$patient_list)
    #   if (isTruthy(input$somVariants_data)) {
    #     somatic_inputFiles <- matching_files()[ 
    #       str_detect(matching_files(), "\\.(vcf|tsv)$") & 
    #         str_detect(matching_files(), regex("somatic", ignore_case = TRUE)) 
    #     ]
    #     bam_tumorFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(bam|bai)$") &
    #         str_detect(matching_files(), regex("somatic|tumor|FFPE", ignore_case = TRUE))
    #     ]
    #     bam_controlFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(bam|bai)$") &
    #         str_detect(matching_files(), regex("somatic|normal|control|krev", ignore_case = TRUE))
    #     ]
    #     print(somatic_inputFiles)
    #   }
    # })
    # 
    # 
    # observeEvent(input$germVariants_data, {
    #   req(matching_files(), input$dir, input$patient_list)
    #   if (isTruthy(input$germVariants_data)) {
    #     germline_inputFiles <- matching_files()[ 
    #       str_detect(matching_files(), "\\.(vcf|tsv)$") & 
    #         str_detect(matching_files(), regex("germline", ignore_case = TRUE)) 
    #     ]
    #     bam_controlFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(bam|bai)$") &
    #         str_detect(matching_files(), regex("germline|normal|control|krev", ignore_case = TRUE))
    #     ]
    #     print(germline_inputFiles)
    #   }
    # })
    # 
    # observeEvent(input$fusion_data, {
    #   req(matching_files(), input$dir, input$patient_list)
    #   if (isTruthy(input$fusion_data)) {
    #     fusion_inputFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(xlsx|tsv)$") &
    #         str_detect(matching_files(), regex("fusion", ignore_case = TRUE)) &
    #         !str_detect(matching_files(), regex("arriba|STAR", ignore_case = TRUE))
    #     ]
    #     bam_tumorFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(bam|bai)$") &
    #         str_detect(matching_files(), regex("fusion|fuze", ignore_case = TRUE)) &
    #         !str_detect(matching_files(), regex("Chimeric|transcriptome", ignore_case = TRUE))
    #     ]
    #     bam_chimericFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(bam|bai)$") &
    #         str_detect(matching_files(), regex("chimeric", ignore_case = TRUE))
    #     ]
    #     print(fusion_inputFiles)
    #   }
    # })
    # 
    # observeEvent(input$expression_data, {
    #   req(matching_files(), input$dir, input$patient_list)
    #   if (isTruthy(input$expression_data)) {
    #     all_inputFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(xlsx|tsv)$") &
    #         str_detect(matching_files(), regex("RNAseq|gene_expression", ignore_case = TRUE))
    #     ]
    #     goi_inputFiles <- matching_files()[
    #       str_detect(matching_files(), "\\.(xlsx|tsv)$") &
    #         str_detect(matching_files(), regex("RNAseq|gene_expression", ignore_case = TRUE)) &
    #         str_detect(matching_files(), regex("genes_of_interest", ignore_case = TRUE))
    #     ]
    #     print(all_inputFiles)
    #   }
    # })
    # 
    addPopover(
      id = "helpPopover_addPatient",
      options = list(
        title = "Write comma-separated text:",
        content = "example: Patient1, Patient2, Patient3",
        placement = "right",
        trigger = "hover"
      )
    )
    
    
    observeEvent(input$somVariants_data, {
      if (!isValidInput(input$dir) || !isValidInput(input$patient_list)) {
        shinyalert(
          title = "Missing inputs",
          text = "Please select a directory and at least one patient before enabling this module.",
          type = "error"
        )
        updatePrettySwitch(session, "somVariants_data", value = FALSE) # vrátí zpět
      }
    })

    
    observeEvent(input$fusion_data, {
      if (!isValidInput(input$dir) || !isValidInput(input$patient_list)) {
        shinyalert(
          title = "Missing inputs",
          text = "Please select a directory and at least one patient before enabling this module.",
          type = "error"
        )
        updatePrettySwitch(session, "fusion_data", value = FALSE)
      }
    })
    
    observeEvent(input$expression_data, {
      if (!isValidInput(input$dir) || !isValidInput(input$patient_list)) {
        shinyalert(
          title = "Missing inputs",
          text = "Please select a directory and at least one patient before enabling this module.",
          type = "error"
        )
        updatePrettySwitch(session, "expression_data", value = FALSE)
      }
    })
    
    
  })
}

# 
# server <- function(id) {
#   moduleServer(id, function(input, output, session) {
#     
#     wd <- c(home = getwd())
#     shinyDirChoose(input, "dir", roots = wd)
# 
#     matching_files <- reactiveVal(character(0))
#  
#     observeEvent(input$dir, {
#       path <- parseDirPath(wd, input$dir)
#       updateTextInput(session, "dir_path", value = path)
#     })
#     
#     isValidInput <- function(x) {
#       !is.null(x) && length(x) > 0 && any(nzchar(x))
#     }
# 
#     
#     observeEvent(list(input$dir, input$patient_list),{
#       # path <- "/home/katka/BioRoots/sequiaViz/input_files/MOII_e117"
#       # patient_list <- c("DZ1601","LK0302","MR1507","VH0452")
# 
#       print(input$dir)
#       print(input$patient_list)
#       if (isValidInput(input$dir) && isValidInput(input$patient_list)) {
#         path <- parseDirPath(wd, input$dir)
#         print("Im here.")
#         print(path)
#         print(input$patient_list)
#         
#         all_files <- list.files(path, full.names = TRUE, recursive = TRUE)
#         pattern <- paste(input$patient_list, collapse = "|") # Sestav regex (např. DZ1601|LK0302|MR1507|VH0452)
#         
#         matches <- stri_detect_regex(all_files, pattern)
#         matching_files(all_files[matches])
#       }
# 
#     })
#     
# 
# 
# 
# 
#     observeEvent(input$somVariants_data,{
#       req(matching_files(),input$dir,input$patient_list)
#       if(isTruthy(input$somVariants_data)){
#         somatic_inputFiles <- matching_files[ str_detect(matching_files, "\\.(vcf|tsv)$") & str_detect(matching_files, regex("somatic",ignore_case = TRUE)) ]
#         bam_tumorFiles <- matching_files[ str_detect(matching_files, "\\.(bam|bai)$") & str_detect(matching_files, regex("somatic|tumor|FFPE",ignore_case = TRUE)) ]
#         bam_controlFiles <- matching_files[ str_detect(matching_files, "\\.(bam|bai)$") & str_detect(matching_files, regex("somatic|normal|control|krev",ignore_case = TRUE)) ]
#         print(somatic_inputFiles)
#       }
#     })
#     observeEvent(input$germVariants_data,{
#       req(matching_files(),input$dir,input$patient_list)
#       if(isTruthy(input$germVariants_data)){
#         germline_inputFiles <- matching_files[ str_detect(matching_files, "\\.(vcf|tsv)$") & str_detect(matching_files, regex("germline",ignore_case = TRUE)) ]
#         bam_controlFiles <- matching_files[ str_detect(matching_files, "\\.(bam|bai)$") & str_detect(matching_files, regex("germline|normal|control|krev",ignore_case = TRUE)) ]
#         print(germline_inputFiles)
#       }
#     })
#     observeEvent(input$fusion_data,{
#       req(matching_files(),input$dir,input$patient_list)
#       if(isTruthy(input$fusion_data)){
#         fusion_inputFiles <- matching_files[ str_detect(matching_files, "\\.(xlsx|tsv)$") & str_detect(matching_files, regex("fusion",ignore_case = TRUE)) & !str_detect(matching_files, regex("arriba|STAR",ignore_case = TRUE)) ]
#         bam_tumorFiles <- matching_files[ str_detect(matching_files, "\\.(bam|bai)$") & str_detect(matching_files, regex("fusion|fuze",ignore_case = TRUE)) & !str_detect(matching_files, regex("Chimeric|transcriptome",ignore_case = TRUE)) ]
#         bam_chimericFiles <- matching_files[ str_detect(matching_files, "\\.(bam|bai)$") & str_detect(matching_files, regex("chimeric",ignore_case = TRUE)) ]
#         print(fusion_inputFiles)
#       }
#     })
#     observeEvent(input$expression_data,{
#       req(matching_files(),input$dir,input$patient_list)
#       if(isTruthy(input$expression_data)){
#         all_inputFiles <- matching_files[ str_detect(matching_files, "\\.(xlsx|tsv)$") & str_detect(matching_files, regex("RNAseq|gene_expression",ignore_case = TRUE)) ]
#         goi_inputFiles <- matching_files[ str_detect(matching_files, "\\.(xlsx|tsv)$") & str_detect(matching_files, regex("RNAseq|gene_expression",ignore_case = TRUE)) & str_detect(matching_files, regex("genes_of_interest",ignore_case = TRUE)) ]
#         print(all_inputFiles)
#       }
#     })
#     
#     
#     addPopover(id = "helpPopover_addPatient",options = list(title = "Write comma-separated text:",content = "example: Patient1, Patient2, Patient3",placement = "right",trigger = "hover"))
#   })
# }

# multiInput(
#   inputId = "Id010",
#   label = "Countries :", 
#   choices = NULL,
#   choiceNames = lapply(seq_along(countries), 
#                        function(i) tagList(tags$img(src = flags[i],
#                                                     width = 20, 
#                                                     height = 15), countries[i])),
#   choiceValues = countries, 
#   width = "100%"
# )