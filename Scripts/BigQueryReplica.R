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
  email <- in_params[[2]]                  # Email for authentication
  output_path <- out_params[[1]]           # Output path
  
  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)
  
  # Load the study area
  print("Loading study area")
  suppressMessages(sf_use_s2(FALSE))
  study_area <- arc.open(study_area_path) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4269)|>
      st_cast("POLYGON") |>
      st_make_valid() |>
    suppressMessages()
  
  
  # Assign megaregion and county/state
  print("Determining megaregion and location")
  region_info <- get_region_info(study_area)
  megaregion <- region_info$megaregion
  state <- region_info$state
  county <- region_info$county
  
  # Construct the SQL query
  print("Constructing SQL query")
  sql_query <- construct_sql_query(
    megaregion,
    study_area
  )
  
  # Execute the SQL query
  print("Executing SQL query")
  results <- execute_sql_query(sql_query)
  
  # Export results
  print("Exporting results")
  suppressMessages(export_results(results, output_path))
  arc.progress_label("Process completed successfully")
}

  arc.progress_label("Process completed successfully")

# Helper Functions

get_region_info <- function(study_area) {
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
  
  # Load states shapefile
  states <- tigris::states(year = 2020, progress_bar = FALSE) |>
    select(STUSPS, NAME, geometry) |>
    left_join(megaregions, by = "STUSPS")|>
    suppressMessages()
  
  # Spatial join to find majority intersecting state
  intersecting_states <- st_join(states, st_sf(geometry = study_area),
                                 join = st_intersects, left = FALSE) |>
    mutate(area = st_area(geometry)) |>
    slice_max(area) |>
    suppressMessages()
           
  
  # Extract megaregion, state, and county
  megaregion <- unique(intersecting_states$Megaregion) |> glue_sql()
  state <- unique(intersecting_states$STUSPS)
  county <- NA  # County can be extracted similarly if needed
  
  list(megaregion = megaregion, state = state, county = county)
}

construct_sql_query <- function(megaregion, study_area, location_fields) {
  # Convert study area geometry to WKT
  study_area_wkt <- st_as_text(st_union(study_area))
  
  # Build the SQL query
  sql <- glue_sql("
    SELECT pop.person_id, activity_id, distance_miles, mode, travel_purpose, pop.commute_mode, pop.household_size, pop.vehicles, pop.age_group, pop.sex, pop.race, pop.ethnicity, pop.employment, pop.education, start_lat, start_lng, end_lat, end_lng, pop.lat, pop.lng
    FROM `replica-customer.{megaregion}.{megaregion}_2024_Q2_thursday_trip` as trip
    LEFT JOIN `replica-customer.{megaregion}.{megaregion}_2024_Q2_population` as pop
    ON trip.person_id = pop.person_id
    WHERE ST_WITHIN(ST_GEOGPOINT(end_lng, end_lat), ST_GEOGFROMTEXT({study_area_wkt}))
  ", .con = DBI::ANSI())
  
  sql
}

execute_sql_query <- function(sql_query) {
  tb <- bq_project_query("replica-customer", sql_query)
  tb_return <- bq_table_download(tb) |>
    suppressMessages()
  
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

export_results <- function(results, output_path) {
  # Convert to spatial data frame if coordinates are included
  if (any(grepl("latitude|longitude", names(results)))) {
    # Assuming longitude and latitude are appropriately named
    results <- st_as_sf(results, coords = c("longitude", "latitude"), crs = 4269)
  }
  
  # Write to output
  arc.write(output_path, results)
}
