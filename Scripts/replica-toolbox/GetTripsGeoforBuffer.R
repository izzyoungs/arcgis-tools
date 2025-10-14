#' Tool Name: Get Network Volumes
#' Purpose: Retrieve network link volumes for a specified region and income type.
#' Author: Izzy Youngs
#' Date: 2024-06-16
#' Copyright: © 2024 Izzy Youngs
#'
#' Inputs:
#'  - study_area: A feature class or shapefile containing the study area.
#'  - equity_area: A feature class or shapefile containing the equity area.
#'  - year: The year for which to retrieve network volumes.
#'  - quarter: The quarter for which to retrieve network volumes.
#'  - day: The day for which to retrieve network volumes.
#'  - email: The email address for BigQuery authentication.
#'
#' Outputs:
#'   - An output feature class containing network volumes.
# -----------------------------------------------------------------------

# Load libraries
tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    sf_use_s2(FALSE)
    library(tidyverse)
    library(bigrquery)
    library(glue)
    library(arcgisbinding)
  })
  arc.check_product()

  arc.progress_label("Running script...")

  # Extract input parameters
  print("Extracting input parameters")
  study_area <- arc.open(in_params[[1]]) |> arc.select()
  year <- in_params[[2]] # Year
  quarter <- in_params[[3]] # Quarter
  day <- in_params[[4]] # Day
  email <- in_params[[5]] # Email for authentication
  output_path <- out_params[[1]] # Output path

  study_area_sf <- arc.data2sf(study_area) |>
    st_transform(4326) |>
    summarize() |>
    st_make_valid() |>
    suppressMessages()

  study_area_wkt <- st_as_text(study_area_sf$geom) |> glue_sql()

  if (nchar(study_area_wkt) > 1000) {
    bbox_study_area <- st_bbox(study_area_sf)

    bbox_study_area_coords <- matrix(
      c(
        bbox_study_area["xmin"], bbox_study_area["ymin"], # Bottom-left
        bbox_study_area["xmax"], bbox_study_area["ymin"], # Bottom-right
        bbox_study_area["xmax"], bbox_study_area["ymax"], # Top-right
        bbox_study_area["xmin"], bbox_study_area["ymax"], # Top-left
        bbox_study_area["xmin"], bbox_study_area["ymin"] # Close the polygon
      ),
      ncol = 2, byrow = TRUE
    )

    bbox_study_area_polygon <- st_polygon(list(bbox_study_area_coords)) |>
      st_make_valid()
    study_area_wkt <- st_as_text(bbox_study_area_polygon) |>
      glue_sql()
  }

  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)

  # Create megaregions data
  megaregions <- data.frame(
    Megaregion = c(
      "alaska", "cal_nev", "cal_nev", "great_lakes", "great_lakes",
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
      "southwest", "southwest", "southwest", "southwest", "southwest"
    ),
    STUSPS = c(
      "AK", "CA", "NV", "IL", "IN", "KY", "MI", "OH", "WI", "HI", "DC",
      "MD", "NC", "VA", "WV", "CT", "DE", "NJ", "NY", "PA", "IA", "KS",
      "MN", "MO", "ND", "NE", "SD", "MA", "ME", "NH", "RI", "VT", "ID",
      "MT", "OR", "WA", "WY", "FL", "GA", "SC", "AL", "AR", "LA", "MS",
      "TN", "AZ", "CO", "NM", "OK", "TX", "UT"
    )
  )

  megaregions_fips <- left_join(tigris::states(cb = TRUE, progress_bar = FALSE), megaregions) |>
    suppressMessages()

  # Read megaregion data
  fips_for_county <- megaregions_fips |>
    st_transform(4326) |>
    st_intersection(study_area_sf) |>
    st_drop_geometry() |>
    slice(1L) |>
    suppressMessages() |>
    suppressWarnings()

  region <- glue_sql(fips_for_county$Megaregion)
  year <- glue_sql(year)
  quarter <- glue_sql(quarter)
  day <- glue_sql(day)


  print(paste0("Running SQL query for ", region, " for ", year, " ", quarter, " ", day, "..."))

  # SQL Query
  sql_query <- glue_sql("WITH study_area AS (SELECT ST_GEOGFROMTEXT('{study_area_wkt}') AS geom),

  base_data AS (SELECT activity_id, mode, travel_purpose, duration_minutes, distance_miles, geometry
                        FROM `replica-customer.{region}.{region}_{year}_{quarter}_{day}_trip`
                        CROSS JOIN study_area
                        WHERE ST_INTERSECTS(geometry, geom) AND distance_miles < 100)
  SELECT *
  FROM base_data;", .con = DBI::ANSI()) |>
    suppressMessages() |>
    suppressWarnings()

  # Query BigQuery
  tb <- bq_project_query("replica-customer", sql_query) |>
    suppressMessages() |>
    suppressWarnings()

  print("Successfully queried BigQuery. Writing to output...")

  df_network <- bq_table_download(tb, page_size = 5000) |>
    suppressMessages() |>
    suppressWarnings()

  # Convert to spatial
  df_network <- st_as_sf(df_network, wkt = "geometry", crs = 4326) |>
  st_collection_extract("LINESTRING") |>
    st_make_valid() |>
    st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
    mutate_if(is.numeric, ~ replace(., is.na(.), 0)) |>
    suppressMessages() |>
    suppressWarnings()

  # Return as ArcGIS output
  arc.write(output_path, df_network, overwrite = TRUE, validate = TRUE) |>
    suppressMessages() |>
    suppressWarnings()

  print("Successfully wrote to output.")
}
