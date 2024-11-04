tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    library(tidyverse)
    library(tidycensus)
    library(tigris)
    library(arcgisbinding)
    suppressWarnings(library(reticulate)) 
  })
  arc.check_product()
  
  print("Reading in data...")
  
  state_input <- in_params[[1]]
  concepts_params <- in_params[[2]]
  selected_concepts <- unlist(concepts_params)
  
  print(selected_concepts)
  
  out_fc <- out_params[[1]]
  out_table <- out_params[[2]]
  
  # Get state FIPS code
  state_info <- fips_codes |>
    filter(state_name == state_input) |>
    select(state_code, state) |>
    distinct()
  
  state_abbr <- state_info$state[1]
  
  arc.progress_pos(40)
  
  print("Getting ACS 5 year data for 2018-2022...")
  
  vars <- load_variables(year = 2022, dataset = "acs5") %>%
    mutate(label = str_replace_all(label, "!!", " "),
           label = str_replace_all(label, ":$", ""),
           label = str_replace_all(label, "\n", ""),
           label = paste0(concept, ": ", label))  # Clean up labels
  
  # Filter variables based on selected concepts
  variables_to_get <- vars %>%
    filter(concept %in% selected_concepts)
  
  variable_codes <- variables_to_get$name
  # variable_labels <- variables_to_get$label
  
  var_lookup <- variables_to_get %>%
    select(name, label)

  acs_data <- get_acs(geography = "block group", 
                      variables = variable_codes, 
                      state = state_abbr, 
                      year = 2022,
                      geometry = TRUE,
                      progress = FALSE) |>
    suppressMessages()
  
  acs_wide <- acs_data |>
    select(GEOID, variable, estimate, geometry) |>
    pivot_wider(names_from = variable, values_from = estimate)
  
  
  print("Writing out data...")
  
  arc.write(out_fc, acs_wide) |>
    suppressMessages() |>
    suppressWarnings()
  
  # Call the updatealias Python tool
  arc.progress_pos(90)
  print("Writing field aliases to table...")
  
  out_fields <- acs_wide |> 
    names()
  
  # Create a data frame with field names and types
  fields_df <- data.frame(
    target_field = out_fields,
    source_field = out_fields,
    stringsAsFactors = FALSE
  )
  
  fields_df <- left_join(fields_df, var_lookup, by = c("source_field" = "name")) |>
    rename(field_alias = label) |>
    mutate(field_alias = ifelse(source_field == 'GEOID', 'GEOID20', field_alias)) |>
    filter(target_field != 'geometry')
  
  # Write out the table
  arc.write(out_table, fields_df) |>
    suppressMessages() |>
    suppressWarnings()
  
  
  arc.progress_pos(100)
}
