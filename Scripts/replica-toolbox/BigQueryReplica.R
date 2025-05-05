tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    library(tidyverse)
    library(bigrquery)
    library(glue)
    library(arcgisbinding)
  })
  arc.check_product()
  
  arc.progress_label("Running script...")
  
  # Extract input parameters
  print("Extracting input parameters")
  study_area_path <- in_params[[1]]        # Path to the study area dataset
  state_abb <- in_params[[2]]              # State
  county_name <- in_params[[3]]            # County
  email <- in_params[[4]]                  # Email for authentication
  year <- in_params[[5]]                   # Year
  quarter <- in_params[[6]]                # Quarter
  day <- in_params[[7]]                    # Day
  output_path <- out_params[[1]]           # Output path
  
  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)
  
  # Load the study area
  print("Checking and loading study area")
  
  # If study area path is not empty, load the study area
  if(nchar(study_area_path) > 0) {
    study_area <- arc.open(study_area_path) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4326) |>
      st_make_valid() |>
      summarize() |>
      suppressMessages()
    
  } else {
    print("Study area path is empty, using state name and county to determine study area")
    study_area <- 0
  }
  
  
  # Assign megaregion and county/state
  region_info <- get_region_info(study_area, state_abb, county_name)
  megaregion <- region_info$megaregion |> glue_sql()
  if(nchar(study_area_path) == 0){
    county_fips <- paste0(region_info$state, region_info$county) |> glue_sql()
    study_area <- NULL
  } 

  # Construct the SQL query
  print(paste0("Constructing SQL query for ", megaregion, ", ", year, " ", quarter, " ", day, "..."))
  sql_query <- construct_sql_query(
    megaregion,
    study_area,
    county_fips,
    year, 
    quarter,
    day
  )
  
  # Execute the SQL query
  print("Executing SQL query")
  results <- execute_sql_query(sql_query)
  
  # Export results
  if(nrow(results) == 0) {
    arc.progress_label("No results found. Please check the input parameters.")
    stop()
  } else {
    print(paste0("Exporting results: ", nrow(results), " rows"))
    suppressMessages(arc.write(output_path, results))
    print("Process completed successfully")
  } }

# Helper Functions

get_region_info <- function(study_area, state_abb, county_name) {

  # Megaregion mapping
  megaregions <- data.frame(
    Megaregion = c("alaska", "cal_nev", "cal_nev", "great_lakes", "great_lakes",
                   "great_lakes", "great_lakes", "great_lakes", "great_lakes",
                   "hawaii", "mid_atlantic", "mid_atlantic", "mid_atlantic",
                   "mid_atlantic", "mid_atlantic", "north_atlantic", "north_atlantic",
                   "north_atlantic", "north_atlantic", "north_atlantic", "north_central",
                   "north_central", "north_central", "north_central", "north_central",
                   "north_central", "north_central", "northeast", "northeast",
                   "northeast", "northeast", "northeast", "northwest", "northwest",
                   "northwest", "northwest", "northwest", "south_atlantic",
                   "south_atlantic", "south_atlantic", "south_central", "south_central",
                   "south_central", "south_central", "south_central", "southwest",
                   "southwest", "southwest", "southwest", "southwest", "southwest"),
    STUSPS = c("AK", "CA", "NV", "IL", "IN", "KY", "MI", "OH", "WI", "HI", "DC",
               "MD", "NC", "VA", "WV", "CT", "DE", "NJ", "NY", "PA", "IA", "KS",
               "MN", "MO", "ND", "NE", "SD", "MA", "ME", "NH", "RI", "VT", "ID",
               "MT", "OR", "WA", "WY", "FL", "GA", "SC", "AL", "AR", "LA", "MS",
               "TN", "AZ", "CO", "NM", "OK", "TX", "UT")
  )
  
  megaregions_fips <- left_join(tigris::fips_codes, megaregions, by = c("state" = "STUSPS")) 
  
  if(!is.na(study_area)){
    print("Determining Megaregion based on study area")
    # Load states shapefile
    states <- tigris::states(year = 2023, progress_bar = FALSE) |>
      select(state = STUSPS, NAME, geometry) |>
      left_join(megaregions_fips, "state") |>
      st_transform(4326) |>
      suppressMessages()
    
    print("Reached this point #1")
    
    # Spatial join to find majority intersecting state
    intersecting_states <- st_join(states, st_sf(geometry = study_area),
                                   join = st_intersects, left = FALSE) |>
      slice(1L) |>
      suppressMessages()
    
    print("Reached this point #2")
    
    # Extract megaregion, state, and county
    megaregion <- intersecting_states$Megaregion |> glue_sql()
    
    list(megaregion = megaregion, state = 0, county = 0)
    
  } else {
    print("Determining location based on state and county")
    
    county_names <- c(county_name, paste0(county_name, " County"))
    
    fips_for_county <- megaregions_fips |>
        filter(state %in% state_abb, 
               county %in% county_names)
      
      if (is.na(fips_for_county$county_code)) {
        print("County not found, please check the input parameters.")
        stop()
      }
      
      list(megaregion = fips_for_county$Megaregion, state = fips_for_county$state_code, county = fips_for_county$county_code)
  }
  

}

construct_sql_query <- function(megaregion, study_area, county_fips, year, quarter, day) {
  year_sql <- glue_sql(year)
  quarter_sql <- glue_sql(quarter)
  day_sql <- glue_sql(day)
  
  if(length(study_area) != 0) {
    # Convert study area geometry to WKT
    study_area_wkt <- st_as_text(study_area$geom) |>
      glue_sql()
    
    # if study_area_wkt is over 1000 characters, get the bounding box instead
    if(nchar(study_area_wkt) > 1000) {
      print("Study area WKT is too long, using bounding box instead")
      bbox <- st_bbox(study_area)
      
      bbox_coords <- matrix(
        c(
          bbox["xmin"], bbox["ymin"],  # Bottom-left
          bbox["xmax"], bbox["ymin"],  # Bottom-right
          bbox["xmax"], bbox["ymax"],  # Top-right
          bbox["xmin"], bbox["ymax"],  # Top-left
          bbox["xmin"], bbox["ymin"]   # Close the polygon
        ),
        ncol = 2, byrow = TRUE
      )
      
      bbox_polygon <- st_polygon(list(bbox_coords)) |>
        suppressMessages()
      study_area_wkt <- st_as_text(bbox_polygon$geom) |> glue_sql()}
      
      # Build the SQL query
      sql <- glue_sql("
    SELECT pop.person_id, activity_id, distance_miles, mode, travel_purpose, pop.commute_mode, pop.household_size, pop.vehicles, pop.age_group, pop.sex, pop.race, pop.ethnicity, pop.employment, pop.education, start_lat, start_lng, end_lat, end_lng, pop.lat, pop.lng
    FROM `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_{day_sql}_trip` as trip
    LEFT JOIN `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_population` as pop
    ON trip.person_id = pop.person_id
    WHERE ST_WITHIN(ST_GEOGPOINT(end_lng, end_lat), ST_GEOGFROMTEXT('{study_area_wkt}'))
  ", .con = DBI::ANSI())
      
      sql
    }
   else if(is.na(county_fips)) {
    print("Please provide a study area or state/county to determine the location for Replica trips.")
    stop()
  } else {
    
    # Build the SQL query
    sql <- glue_sql("
    SELECT pop.person_id, activity_id, distance_miles, mode, travel_purpose, pop.commute_mode, pop.household_size, pop.vehicles, pop.age_group, pop.sex, pop.race, pop.ethnicity, pop.employment, pop.education, start_lat, start_lng, end_lat, end_lng, pop.lat, pop.lng
    FROM `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_{day_sql}_trip` as trip
    LEFT JOIN `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_population` as pop
    ON trip.person_id = pop.person_id
    WHERE LEFT(destination_bgrp, 5) = '{county_fips}'
  ", .con = DBI::ANSI())
    
    sql
  }
}
  

execute_sql_query <- function(sql_query) {
  tb <- bq_project_query("replica-customer", sql_query)|>
    suppressMessages() |>
    suppressWarnings()
  
  tb_return <- bq_table_download(tb) |>
    suppressMessages()|>
    suppressWarnings()
  
  tb_return |>
    rename(home_lat = lat, home_lng = lng) |>
    mutate(n = 1,
           n2 = 1,
           mode = paste0('mode_', mode),
           travel_purpose = paste0('purpose_', travel_purpose)) |>
    pivot_wider(names_from = travel_purpose, values_from = n, values_fill = list(value = 0),
                values_fn = ~ mean(.x, na.rm = TRUE)) |>
    pivot_wider(names_from = mode, values_from = n2, values_fill = list(value = 0),
                values_fn = ~ mean(.x, na.rm = TRUE)) |>
    mutate_if(is.numeric, ~ ifelse(is.na(.), 0, .))
  
}
