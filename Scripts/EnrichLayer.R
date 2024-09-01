tool_exec<- function(in_params, out_params){
  
  arc.progress_label("Loading libraries...")

  suppressMessages(require(sf))
  suppressMessages(library(tidyverse))
  suppressMessages(library(tidycensus))
  suppressMessages(library(tigris))
  
  arc.progress_label("Reading in data...")
  
  source_dataset <- in_params[[1]]
  variables_params <- in_params[[2]]
  variables <- unlist(variables_params)
  
  out_fc <- out_params[[1]]
  open <- arc.open(source_dataset)
  input_df <- arc.select(open)
  study_area <- arc.data2sf(input_df) %>%
    st_transform(4269)
  
  print("Finding study area state and county...")
  
  arc.progress_pos(40)

  sf_counties <- counties(year = 2020) %>%
    suppressMessages()
  
  state_customarea <- st_intersection(sf_counties, study_area) %>%
    select(STATEFP, COUNTYFP) %>%
    st_drop_geometry() %>%
    suppressWarnings()
  
  state <- state_customarea$STATEFP[1]
  county <- state_customarea$COUNTYFP[1]
  
  blocks_customarea <- blocks(state = state, county = county, year = 2020) %>%
    mutate(GEOID = paste0(STATEFP20, COUNTYFP20, TRACTCE20, str_sub(BLOCKCE20, 1, 1)))%>%
    suppressMessages()
  
  blockgroups_customarea <- blocks_customarea %>%
    st_drop_geometry() %>%
    group_by(GEOID) %>%
    summarise(total_population = sum(POP20, na.rm = TRUE))
  
  block_centroids <- blocks_customarea %>%
    st_centroid() %>%
    left_join(blockgroups_customarea, by = "GEOID") %>%
    mutate(weight = POP20 / total_population) %>%
    suppressWarnings()
  
  study_area_weights <- st_intersection(block_centroids, study_area) %>%
    st_drop_geometry() %>%
    suppressWarnings()
  
  arc.progress_pos(60)
  
  print("Getting ACS data for 2022...")
  
  vars <- load_variables(year = 2022, "acs5")
  
  concepts <- c('Means of Transportation to Work by Travel Time to Work', 
                'Detailed Race', 
                'Means of Transportation to Work', 
                'Travel Time to Work')
  
  aliases <- vars %>%
    mutate(label = str_replace_all(label, "!!", " "),
           label = str_replace_all(label, ":$", ""),
           label = str_replace_all(label, "\n", ""),
           label = paste0(concept, ": ", label)) %>%
    filter(geography == 'block group', 
           concept %in% concepts)
  
  
  variables <- c('Means of Transportation to Work by Travel Time to Work: Estimate Total', 'Means of Transportation to Work by Travel Time to Work: Estimate Total: Less than 10 minutes')
  
  variable_codes <- variables %>%
    as.data.frame() %>% 
    mutate(label = paste0(.)) %>%
    left_join(aliases) %>%
    select(name, label) %>%
    suppressMessages()
  
  # variable_codes <- sprintf("c(%s)", paste(sprintf("`%s` = '%s'", variable_codes$label, variable_codes$name), collapse = ", "))
  
  variable_codes <- sprintf("c(%s)", paste(sprintf("'%s'", variable_codes$name), collapse = ", "))
  
  variable_codes <- eval(parse(text = variable_codes))
  
  acs_data <- get_acs(geography = "block group", 
                      variables = variable_codes, 
                      state = state, 
                      county = county, 
                      year = 2022) %>%
    suppressMessages()

  study_area_acs <- left_join(study_area_weights, acs_data, by = "GEOID", relationship = "many-to-many") %>%
    mutate(weighted_sum = weight * estimate) %>%
    group_by(variable) %>%
    summarise(estimate = round(sum(weighted_sum))) %>%
    ungroup() %>%
    pivot_wider(names_from = variable, values_from = estimate)

  arc.progress_pos(90)

  print("Joining results and writing out data...")

  output_data <- study_area %>%
    cbind(study_area_acs)

  arc.progress_pos(100)

  arc.write(out_fc, output_data) %>%
    suppressMessages() %>%
    suppressWarnings()
}