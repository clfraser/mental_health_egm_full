####################### Get click data for when chart is clicked on #######################

get_click_data <- JS("function(rowInfo, column) {
        // Don't handle click events in the domain or subdomain columns
    if (column.id === 'domain' || column.id === 'subdomain') {
      return
    }
    // Send the click event to Shiny, which will be available in input$click_details
    if (window.Shiny) {
      Shiny.setInputValue('click_details', { domain: rowInfo.values.domain, subdomain: rowInfo.values.subdomain, outcome_and_type: column.id }, { priority: 'event' })
    }
  }")

####################### jsTreeR for hierarchical checkboxes #######################

## Functions for creating structures to be used with jsTreeR

create_df_for_nodes <- function(for_tree_tibble, child_level){
  for_tree_tibble %>%
    mutate({{child_level}} := as.character({{child_level}}), # If the child level is a factor, it doesn't convert to nodes properly
           selected = FALSE) %>%
    as.data.frame(.)
}

create_nodes_from_df <- function(df_for_nodes, parent_level, child_level){
  
  # Create separate DFs with different rownames for child or parent
  rownames(df_for_nodes) <- df_for_nodes[[child_level]]
  
  dat <- df_for_nodes %>%
    split(df_for_nodes[[parent_level]])
  
  nodes <- lapply(names(dat), function(parent){
    list(
      text = parent,
      state =
        list(opened = TRUE, selected = if_else(dat[[parent]][[child_level]][1] == "Exclude", df_for_nodes[dat[[parent]][[child_level]][1], "selected"], FALSE)),
      children = lapply(dat[[parent]][[child_level]][dat[[parent]][[child_level]] != "Exclude"], function(child){
        list(
          text = child,
          state =
            list(selected = df_for_nodes[child, "selected"])
        )
      })
    )
  })
  
  return(nodes)
}

# Clear heirarchical checkboxes

clear_tree <- function(df, parent_level, child_level){
  df %>%
    mutate(selected = FALSE) %>%
    create_nodes_from_df(parent_level, child_level)
}

# Putting data in the right format for jsTreeR

# Create initial dataframes for trees

sub_outcomes_for_tree <- data.frame(
  first_level = rep("Any form of self-injurious thoughts and behaviours", 2),
  second_level = c("Exclusively non-suicidal self-harm", "Repetitive, compulsive self-injury")
)

domains_subs_for_tree <- reviews_chart %>%
  select(domain, subdomain) %>%
  distinct(domain, subdomain) %>%
  arrange(domain, subdomain)

age_for_tree <- data.frame(
  first_level = rep("All ages", 2),
  second_level = c("Exclusively 0-18 years", "Up to 25 years")
)

intervention_exposure_for_tree <- reviews_chart %>%
  select(intervention_exposure_short, intervention_classification) %>%
  mutate(intervention_classification = if_else(intervention_exposure_short == "Risk/protective factor", "Exclude", intervention_classification)) %>% # Risk/protective factor should have no children
  distinct(intervention_exposure_short, intervention_classification) %>%
  arrange(intervention_exposure_short) %>%
  filter(!is.na(intervention_exposure_short))

sub_population_for_tree <- reviews_chart %>%
  select(overall_population, sub_population) %>%
  mutate(sub_population = if_else(overall_population == "General population", "Exclude", sub_population)) %>% # General population should have no children
  distinct(overall_population, sub_population) %>%
  arrange(overall_population) %>%
  filter(!is.na(overall_population))

# Turn these into dataframes for creating nodes for the tree
# Note that for the create_df_for_nodes function, the column names shouldn't be in quotes,
# but for the create_nodes_from_df function, they should

outcome_df <- create_df_for_nodes(sub_outcomes_for_tree, second_level)
domains_df <- create_df_for_nodes(domains_subs_for_tree, subdomain)
age_df <- create_df_for_nodes(age_for_tree, second_level)
intervention_risk_df <- create_df_for_nodes(intervention_exposure_for_tree, intervention_classification)
sub_pop_df <- create_df_for_nodes(sub_population_for_tree, sub_population)

# Turn the dataframes into nodes

outcome_nodes <- create_nodes_from_df(outcome_df, "first_level", "second_level")
domain_subs_nodes <- create_nodes_from_df(domains_df, "domain", "subdomain")
age_nodes <- create_nodes_from_df(age_df, "first_level", "second_level")
intervention_risk_nodes <- create_nodes_from_df(intervention_risk_df, "intervention_exposure_short", "intervention_classification")
sub_pop_nodes <- create_nodes_from_df(sub_pop_df, "overall_population", "sub_population")


# Modify bubble_grid function for our purposes
# Change some defaults so that it fits with what we're most likely to use

bubble_grid_modified <- function(data,
                                 shape = "circles",
                                 colors = c("#15607A", "#FFFFFF", "#FA8C00"),
                                 color_ref = NULL,
                                 color_by = NULL,
                                 min_value = 7, # Was 7
                                 max_value = 70, # Was 50
                                 opacity = 1,
                                 bias = 1,
                                 number_fmt = NULL,
                                 text_size = NULL,
                                 text_color = "black",
                                 text_color_ref = NULL,
                                 show_text = FALSE, # Default changed
                                 brighten_text = TRUE,
                                 brighten_text_color = "white",
                                 bold_text = FALSE,
                                 span = TRUE, # Default changed
                                 box_shadow = FALSE,
                                 tooltip = TRUE, # Default changed
                                 animation = "background 1s ease") {
  
  '%notin%' <- Negate('%in%')
  
  if (!is.null(shape) && shape %notin% c("circles", "squares", "triangles") == TRUE) {
    
    stop("`shape` must be either 'circles', 'squares' or 'trinagles")
  } # Include triangles in allowed shapes
  
  if (!is.logical(bold_text)) {
    
    stop("`bold_text` must be TRUE or FALSE")
  }
  
  if (!is.logical(brighten_text)) {
    
    stop("`brighten_text` must be TRUE or FALSE")
  }
  
  if (!is.logical(box_shadow)) {
    
    stop("`box_shadow` must be TRUE or FALSE")
  }
  
  if (!is.logical(tooltip)) {
    
    stop("`tooltip` must be TRUE or FALSE")
  }
  
  if (!is.numeric(bias)) {
    
    stop("`bias` must be numeric")
  }
  
  if (!is.numeric(opacity)) {
    
    stop("`opacity` must be numeric")
  }
  
  if (opacity < 0 | opacity > 1) {
    
    stop("`opacity` must be a value between 0 and 1")
  }
  
  if (length(text_color) > 1) {
    
    stop("multiple colors detected in `text_color`. only one color can be used.")
  }
  
  if (length(brighten_text_color) > 1) {
    
    stop("multiple colors detected in `brighten_text_color` only one color can be used.")
  }
  
  color_pal <- function(x) {
    
    if (!is.na(x))
      rgb(colorRamp(c(colors), bias = bias)(x), maxColorValue = 255)
    else
      NULL
  }
  
  assign_color <- function(x) {
    
    if (!is.na(x)) {
      rgb_sum <- rowSums(colorRamp(c(colors), bias = bias)(x))
      color <- ifelse(rgb_sum >= 395, text_color, brighten_text_color)
      color
    } else
      NULL
  }
  
  if (bold_text == TRUE) {
    
    bold_text <- "bold"
    
  } else bold_text <- "normal"
  
  if (box_shadow == TRUE) {
    
    box_shadow <- "0 6px 6px -4px #888888"
    
  } else box_shadow <- NULL
  
  cell <- function(value, index, name) {
    
    if (is.null(color_ref) & is.null(color_by) & !is.numeric(value)) return(value)
    
    if (is.null(number_fmt)) {
      
      label <- paste0(sub("Risk_protective_factor", "Risk/protective factor", sub(".*\\.", "", name)), ": ", value) # Include the sub-column name in the tooltip (the text after the dot in the column name). Note that the . has to be 'escaped' with "\\".
      
    } else {
      
      label <- paste0(sub("Risk_protective_factor", "Risk/protective factor", sub(".*\\.", "", name)), ": ", number_fmt(value))
      
    }
    
    tooltip_label <- sprintf('<span style="font-size:1.5em">%s</span>', label)
    
    if (is.logical(span)) {
      
      if (span) {
        
        normalized <- (value - min(dplyr::select_if(data, is.numeric), na.rm = TRUE)) / (max(dplyr::select_if(data, is.numeric), na.rm = TRUE) - min(dplyr::select_if(data, is.numeric), na.rm = TRUE))
        
        ### width of data_bars
        size <- if (max(value == 0)){ "0px" } # Show nothing on the chart if everything has been filtered out
        
        else if ((is.numeric(value) & is.null(max_value) & is.null(min_value)) | value == 0) { # Added - use this condition if the value is 0
          
          paste0(abs(value) / max(dplyr::select_if(data, is.numeric), na.rm = TRUE) * 100, "px")
          
          ### min_value provided
        } else if (is.numeric(value) & is.null(max_value) & !is.null(min_value)) {
          
          paste0((abs(value) - min_value) / (max(dplyr::select_if(data, is.numeric), na.rm = TRUE) - min_value) * 100, "px")
          
          ### max_value provided
        } else if (is.numeric(value) & !is.null(max_value) & is.null(min_value)) {
          
          paste0((abs(value) / max_value) * 100, "px")
          
          ### min and max provided
        } else if (is.numeric(value) & !is.null(max_value) & !is.null(min_value)) {
          
          paste0(min_value + (value - min(dplyr::select_if(data, is.numeric), na.rm = TRUE) * (max_value - min_value))
                 / (max(dplyr::select_if(data, is.numeric), na.rm = TRUE) - min(dplyr::select_if(data, is.numeric), na.rm = TRUE)) * 100, "px")
          
        } else if (!is.numeric(value)) {
          
          return(value)
        }
        
      } else if (!is.null(color_ref)) {
        
        normalized <- dplyr::ntile(data[[name]], n = length(colors))
        
      } else {
        
        ### color_by
        if (is.character(color_by)) {
          
          # color_by column must be numeric
          if (all(color_by %in% names(which(sapply(data, is.numeric))))) {
            
            if (is.character(color_by)) { color_by <- which(names(data) %in% color_by) }
            
            # if there is no variance in the column, assign the same color to each value
            if (is.numeric(data[[color_by]]) & mean((data[[color_by]] - mean(data[[color_by]], na.rm=TRUE)) ^ 2, na.rm=TRUE) == 0) {
              
              normalized <- 1
              
            } else {
              
              normalized <- (data[[color_by]][index] - min(data[[color_by]], na.rm = TRUE)) / (max(data[[color_by]], na.rm = TRUE) - min(data[[color_by]], na.rm = TRUE))
              
            }
            
            cell_color <- color_pal(normalized)
            cell_color <- suppressWarnings(grDevices::adjustcolor(cell_color, alpha.f = opacity))
            font_color <- assign_color(normalized)
            
            ### width of data_bars
            size <- if ((is.numeric(data[[color_by]][index]) & is.null(max_value) & is.null(min_value)) | value == 0) { # Added - use this condition if the value is 0
              
              paste0(abs(data[[color_by]][index]) / max(abs(data[[color_by]]), na.rm = TRUE) * 100, "px")
              
              ### min_value provided
            } else if (is.numeric(data[[color_by]][index]) & is.null(max_value) & !is.null(min_value)) {
              
              paste0((abs(data[[color_by]][index]) - min_value) / (max(abs(data[[color_by]]), na.rm = TRUE) - min_value) * 100, "px")
              
              ### max_value provided
            } else if (is.numeric(data[[color_by]][index]) & !is.null(max_value) & is.null(min_value)) {
              
              paste0((abs(data[[color_by]][index]) / max_value) * 100, "px")
              
              ### min and max provided
            } else if (is.numeric(data[[color_by]][index]) & !is.null(max_value) & !is.null(min_value)) {
              
              paste0((abs(data[[color_by]][index]) - min_value) / (max_value - min_value) * 100, "px")
              
            }
            
          } else {
            
            stop("Attempted to select non-existing column or non-numeric column with color_by")
          }
          
        } else {
          
          # standard normalization (no variance check)
          if (is.numeric(value) & mean((data[[name]] - mean(data[[name]], na.rm=TRUE)) ^ 2, na.rm=TRUE) == 0) {
            
            normalized <- 1
            
          } else {
            
            # standard normalization
            normalized <- (value - min(data[[name]], na.rm = TRUE)) / (max(data[[name]], na.rm = TRUE) - min(data[[name]], na.rm = TRUE))
            
          }
          
          cell_color <- color_pal(normalized)
          cell_color <- suppressWarnings(grDevices::adjustcolor(cell_color, alpha.f = opacity))
          font_color <- assign_color(normalized)
          
          ### width of data_bars
          size <- if ((is.numeric(value) & is.null(max_value) & is.null(min_value)) | value == 0) { # Added - use this condition if the value is 0
            
            paste0(abs(value) / max(abs(data[[name]]), na.rm = TRUE) * 100, "px")
            
            ### min_value provided
          } else if (is.numeric(value) & is.null(max_value) & !is.null(min_value)) {
            
            paste0((abs(value) - min_value) / (max(dplyr::select_if(data, is.numeric), na.rm = TRUE) - min_value) * 100, "px")
            
            ### max_value provided
          } else if (is.numeric(value) & !is.null(max_value) & is.null(min_value)) {
            
            paste0((abs(value) / max_value) * 100, "px")
            
            ### min and max provided
          } else if (is.numeric(value) & !is.null(max_value) & !is.null(min_value)) {
            
            paste0(min_value + (value - min(dplyr::select_if(data, is.numeric), na.rm = TRUE) * (max_value - min_value))
                   / (max(dplyr::select_if(data, is.numeric), na.rm = TRUE) - min(dplyr::select_if(data, is.numeric), na.rm = TRUE)), "px")
            
          }
          
        }
        
      }
      
      ### conditional text color
      if (is.character(text_color_ref)) {
        
        if (all(text_color_ref %in% names(which(sapply(data, is.character))))) {
          
          if (is.character(text_color_ref)) { text_color_ref <- which(names(data) %in% text_color_ref) }
          
          font_color <- data[[text_color_ref]][index]
          text_color <- data[[text_color_ref]][index]
          
        } else {
          
          stop("Attempted to select non-existing column or non-character column with text_color_ref")
        }
        
      } else {
        
        font_color <- text_color
      }
      
      ### conditional fill color and font color
      if (is.character(color_ref)) {
        
        if (all(color_ref %in% names(which(sapply(data, is.character))))) {
          
          if (is.character(color_ref)) { color_ref <- which(names(data) %in% color_ref) }
          
          cell_color <- data[[color_ref]][index]
          cell_color <- suppressWarnings(grDevices::adjustcolor(cell_color, alpha.f = opacity))
          
          rgb_sum <- rowSums(grDevices::colorRamp(c(cell_color), bias = bias)(1))
          
          font_color <- ifelse(rgb_sum >= 395, text_color, brighten_text_color)
          
        } else {
          
          stop("Attempted to select non-existing column or non-character column with fill_color_ref")
        }
        
      } else {
        
        cell_color <- color_pal(normalized)
        cell_color <- suppressWarnings(grDevices::adjustcolor(cell_color, alpha.f = opacity))
        font_color <- assign_color(normalized)
        
      }
      
    } else if (is.numeric(span) | is.character(span)) {
      
      if (all(span %in% which(sapply(data, is.numeric))) | all(span %in% names(which(sapply(data, is.numeric))))) {
        
        if (is.character(span)) { span <- which(names(data) %in% span) }
        
        normalized <- (value - min(dplyr::select(data, !!span), na.rm = TRUE)) / (max(dplyr::select(data, !!span), na.rm = TRUE) - min(dplyr::select(data, !!span), na.rm = TRUE))
        cell_color <- if (name %in% colnames(data)[span]) { suppressWarnings(grDevices::adjustcolor(color_pal(normalized), alpha.f = opacity)) }
        font_color <- if (name %in% colnames(data)[span]) { assign_color(normalized) }
        
      } else {
        
        stop("Attempted to select non-existing or non-numeric columns with span")
        
      }
      
    }
    
    # adjust border radius and clipPath based on shape
    if (shape == "circles") {
      radius <- "50%"
    } else radius <- NULL
    
    if (shape == "triangles"){
      clippath <- "polygon(50% 0, 100% 100%, 0 100%)"
    } else clippath <- NULL
    
    # Don't display a shape if size = 0
    if(size == "0px"){
      display_var <- "none"
    } else display_var <- "inline-flex"
    
    
    if (brighten_text == FALSE & show_text == TRUE) {
      
      if (tooltip == TRUE) {
        
        htmltools::tagAppendChild(
          htmltools::tags$button(
            type = "button",
            class = "shape-button",
            'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
            style = list(background = cell_color,
                         color = text_color,
                         display = display_var,
                         justifyContent = "center",
                         alignItems = "center",
                         textAlign = "center",
                         height = size,
                         width = size,
                         borderRadius = radius,
                         fontWeight = bold_text,
                         boxShadow = box_shadow,
                         fontSize = text_size,
                         transition = animation,
                         clipPath = clippath,
                         borderStyle = none,
                         padding = "0px")),
          tippy::tippy(label,
                       animateFill = FALSE,
                       followCursor = TRUE,
                       tooltip = tooltip_label)
        )
        
      } else {
        
        htmltools::tags$button(label,
                               type = "button",
                               class = "shape-button",
                               'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
                               style = list(background = cell_color,
                                            color = text_color,
                                            display = display_var,
                                            justifyContent = "center",
                                            alignItems = "center",
                                            textAlign = "center",
                                            height = size,
                                            width = size,
                                            borderRadius = radius,
                                            fontWeight = bold_text,
                                            boxShadow = box_shadow,
                                            fontSize = text_size,
                                            transition = animation,
                                            clipPath = clippath,
                                            borderStyle = "none",
                                            padding = "0px"))
      }
      
    } else if (brighten_text == TRUE & !is.null(text_color_ref) & show_text == TRUE) {
      
      if (tooltip == TRUE) {
        
        htmltools::tagAppendChild(
          htmltools::tags$button(
            type = "button",
            class = "shape-button",
            'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
            style = list(background = cell_color,
                         color = text_color,
                         display = display_var,
                         justifyContent = "center",
                         alignItems = "center",
                         textAlign = "center",
                         height = size,
                         width = size,
                         borderRadius = radius,
                         boxShadow = box_shadow,
                         fontSize = text_size,
                         transition = animation,
                         clipPath = clippath,
                         borderStyle = "none",
                         padding = "0px")),
          tippy::tippy(label,
                       animateFill = FALSE,
                       followCursor = TRUE,
                       tooltip = tooltip_label)
        )
        
      } else {
        
        htmltools::tags$button(label,
                               type = "button",
                               class = "shape-button",
                               'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
                               style = list(background = cell_color,
                                            color = text_color,
                                            display = display_var,
                                            justifyContent = "center",
                                            alignItems = "center",
                                            textAlign = "center",
                                            height = size,
                                            width = size,
                                            borderRadius = radius,
                                            boxShadow = box_shadow,
                                            fontSize = text_size,
                                            transition = animation,
                                            clipPath = clippath,
                                            borderStyle = "none",
                                            padding = "0px"))
      }
      
    } else if (brighten_text == FALSE & show_text == FALSE) {
      
      if (tooltip == TRUE) {
        
        htmltools::tagAppendChild(
          htmltools::tags$button(
            type = "button",
            class = "shape-button",
            'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
            style = list(background = cell_color,
                         display = display_var,
                         justifyContent = "center",
                         alignItems = "center",
                         textAlign = "center",
                         height = size,
                         width = size,
                         borderRadius = radius,
                         color = "transparent",
                         boxShadow = box_shadow,
                         fontSize = text_size,
                         transition = animation,
                         clipPath = clippath,
                         borderStyle = "none",
                         padding = "0px")),
          tippy::tippy(label,
                       animateFill = FALSE,
                       followCursor = TRUE,
                       tooltip = tooltip_label)
        )
        
      } else {
        
        htmltools::tags$button(label,
                               type = "button",
                               class = "shape-button",
                               'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
                               style = list(background = cell_color,
                                            display = display_var,
                                            justifyContent = "center",
                                            alignItems = "center",
                                            textAlign = "center",
                                            height = size,
                                            width = size,
                                            borderRadius = radius,
                                            fontSize = 0,
                                            boxShadow = box_shadow,
                                            fontSize = text_size,
                                            transition = animation,
                                            clipPath = clippath,
                                            borderStyle = "none",
                                            padding = "0px"))
      }
      
    } else if (brighten_text == TRUE & show_text == FALSE) {
      
      if (tooltip == TRUE) {
        
        htmltools::tagAppendChild(
          htmltools::tags$button(
            type = "button",
            class = "shape-button",
            'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
            style = list(background = cell_color,
                         display = display_var,
                         justifyContent = "center",
                         alignItems = "center",
                         textAlign = "center",
                         height = size,
                         width = size,
                         borderRadius = radius,
                         color = "transparent",
                         boxShadow = box_shadow,
                         fontSize = text_size,
                         transition = animation,
                         clipPath = clippath,
                         borderStyle = "none",
                         padding = "0px")),
          tippy::tippy(label,
                       animateFill = FALSE,
                       followCursor = TRUE,
                       tooltip = tooltip_label)
        )
        
      } else {
        
        htmltools::tags$button(label,
                               type = "button",
                               class = "shape-button",
                               'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
                               style = list(background = cell_color,
                                            display = display_var,
                                            justifyContent = "center",
                                            alignItems = "center",
                                            textAlign = "center",
                                            height = size,
                                            width = size,
                                            borderRadius = radius,
                                            color = "transparent",
                                            boxShadow = box_shadow,
                                            fontSize = text_size,
                                            transition = animation,
                                            clipPath = clippath,
                                            borderStyle = "none",
                                            padding = "0px"))
      }
      
    } else {
      
      if (tooltip == TRUE) {
        
        htmltools::tagAppendChild(
          htmltools::tags$button(
            type = "button",
            class = "shape-button",
            'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
            style = list(background = cell_color,
                         color = font_color,
                         display = display_var,
                         justifyContent = "center",
                         alignItems = "center",
                         textAlign = "center",
                         height = size,
                         width = size,
                         borderRadius = radius,
                         boxShadow = box_shadow,
                         fontWeight = bold_text,
                         fontSize = text_size,
                         transition = animation,
                         clipPath = clippath,
                         borderStyle = "none",
                         padding = "0px")),
          tippy::tippy(label,
                       animateFill = FALSE,
                       followCursor = TRUE,
                       tooltip = tooltip_label)
        )
        
      } else {
        
        htmltools::tags$button(label,
                               type = "button",
                               class = "shape-button",
                               'aria-label' = "The visual EGM is not accessible by screen reader. Please use the Show EGM as text button above to access an accessible version.",
                               style = list(background = cell_color,
                                            color = font_color,
                                            display = display_var,
                                            justifyContent = "center",
                                            alignItems = "center",
                                            textAlign = "center",
                                            height = size,
                                            width = size,
                                            borderRadius = radius,
                                            boxShadow = box_shadow,
                                            fontWeight = bold_text,
                                            fontSize = text_size,
                                            transition = animation,
                                            clipPath = clippath,
                                            borderStyle = "none",
                                            padding = "0px"))
        
      }
    }
  }
}