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
  year <- in_params[[3]]                   # Year
  quarter <- in_params[[4]]                # Quarter
  day <- in_params[[5]]                    # Day
  output_path <- out_params[[1]]           # Output path
  
  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)
  
  # Load the study area
  print("Checking and loading study area")
  
  # If study area path is not empty, load the study area
    suppressMessages(sf_use_s2(FALSE))
    study_area <- arc.open(study_area_path) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4269)|>
      st_cast("POLYGON") |>
      st_make_valid() |>
      suppressMessages()
    
    study_area_wkt <- st_as_text(study_area_sf$geom) |> glue_sql()
    
    # Assign megaregion and county/state
    print("Determining megaregion and location")
    
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
    
    megaregions_fips <- left_join(tigris::states(cb = TRUE, year = 2023), megaregions) |>
      st_intersection(study_area) |>
      st_drop_geometry() |>
      slice(1L) |>
      pull(Megaregion) |>
      glue_sql()

  # Construct the SQL query
  print("Constructing SQL query")
  sql_query <- construct_sql_query(
    megaregion,
    study_area_wkt,
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
    suppressMessages(arc.write(output_path, results, overwrite = TRUE, validate = TRUE))
    print("Process completed successfully")
  } }

# Helper Functions

construct_sql_query <- function(megaregion, study_area_wkt, year, quarter, day) {
  year_sql <- glue_sql(year)
  quarter_sql <- glue_sql(quarter)
  day_sql <- glue_sql(day)
    
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
      
      bbox_polygon <- st_polygon(list(bbox_coords))
      study_area_wkt <- st_as_text(bbox_polygon)}
      
      # Build the SQL query
      sql <- glue_sql("
    SELECT person_id, commute_mode, household_size, vehicles, age_group, sex, race, ethnicity, employment, education, lat, lng
    FROM `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_population`
    WHERE ST_WITHIN(ST_GEOGPOINT(lat, lng), ST_GEOGFROMTEXT({study_area_wkt}))
  ", .con = DBI::ANSI())
      
      sql
    }
  

execute_sql_query <- function(sql_query) {
  tb <- bq_project_query("replica-customer", sql_query)
  
  tb_return <- bq_table_download(tb) |>
    suppressMessages()
  
  tb_return
  
}
