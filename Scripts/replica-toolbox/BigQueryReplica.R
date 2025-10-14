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
  study_area <- in_params[[1]] # Path to the study area boundary
  trip_geometry <- in_params[[2]] # Whether the trips start/end/intersect the study area
  email <- in_params[[3]] # Email for authentication
  year <- in_params[[4]] # Year
  quarter <- in_params[[5]] # Quarter
  day <- in_params[[6]] # Day

  # Set the output path csv
  output_path <- out_params[[1]] # Output path

  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)


  # Load Boundaries ---------------------------------------------------------

  print("Loading study area boundaries")
  study_area_sf <- arc.open(study_area) |>
    arc.select() |>
    arc.data2sf() |>
    st_transform(4326) |>
    st_make_valid() |>
    suppressMessages()

  study_area_wkt <- st_as_text(study_area_sf$geom) |> glue_sql()

  # if WKT is over 1000 characters, get the bounding box instead
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

  where_trip_geometry <- case_when(
    trip_geometry == "Destinations only" ~ "WHERE ST_INTERSECTS(ST_GEOGPOINT(end_lng, end_lat), study_area.geom)",
    trip_geometry == "Origins only" ~ "WHERE ST_INTERSECTS(ST_GEOGPOINT(start_lng, start_lat), study_area.geom)",
    trip_geometry == "Destinations or origins" ~ "WHERE ST_INTERSECTS(ST_GEOGPOINT(end_lng, end_lat), study_area.geom) OR ST_INTERSECTS(ST_GEOGPOINT(start_lng, start_lat), study_area.geom)",
    trip_geometry == "Destinations and origins" ~ "WHERE ST_INTERSECTS(ST_GEOGPOINT(end_lng, end_lat), study_area.geom) AND ST_INTERSECTS(ST_GEOGPOINT(start_lng, start_lat), study_area.geom)",
    trip_geometry == "Intersects" ~ "WHERE ST_INTERSECTS(geometry, study_area.geom))"
  ) |> glue_sql()


  # Get Megaregion ----------------------------------------------------------

  print("Getting megaregion from destination boundary")

  # Megaregion mapping
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

  megaregion <- left_join(tigris::states(cb = TRUE, year = 2023, progress_bar = FALSE) |> st_transform(4326), megaregions) |>
    st_intersection(study_area_sf) |>
    st_drop_geometry() |>
    slice(1L) |>
    pull(Megaregion) |>
    glue_sql() |>
    suppressMessages() |>
    suppressWarnings()

  # Get SQL arguments for query ---------------------------------------------
  # Construct the SQL query
  print(paste0("Constructing SQL query for ", megaregion, ", ", year, " ", quarter, " ", day, "..."))

  year_sql <- glue_sql(year)
  quarter_sql <- glue_sql(quarter)
  day_sql <- glue_sql(day)

  sql <- glue_sql("
    WITH study_area AS (SELECT ST_GEOGFROMTEXT('{study_area_wkt}') AS geom
),
base_data AS (
  SELECT
    pop.person_id, activity_id, distance_miles, origin_bgrp_20, destination_bgrp_20,
    mode, travel_purpose, pop.commute_mode, pop.household_size, pop.vehicles,
    pop.age_group, pop.sex, pop.race, pop.ethnicity, pop.employment, pop.education,
    start_lat, start_lng, end_lat, end_lng,
    pop.lat AS home_lat, pop.lng AS home_lng,
    geometry
  FROM `replica-customer.{megaregion}.{megaregion}_{year}_{quarter}_{day}_trip` AS trip
  LEFT JOIN `replica-customer.{megaregion}.{megaregion}_{year}_{quarter}_population` AS pop
    ON trip.person_id = pop.person_id
  CROSS JOIN study_area
    {where_trip_geometry})
SELECT *
FROM base_data;",
    .con = DBI::ANSI()
  )

  print("Executing SQL query...")
  print(sql)

  # Execute SQL Query -------------------------------------------------------

  tb <- bq_project_query("replica-customer", sql) |>
    suppressMessages() |>
    suppressWarnings()

  tb_return <- bq_table_download(tb, page_size = 5000) |>
    suppressMessages() |>
    suppressWarnings()

  if (nrow(tb_return) == 0) {
    print("No results found. Please check the input parameters.")
    stop()
  }

  print("Successfully retrieved data from BigQuery. Post-processing data...")
  sf_final <- tb_return |>
    mutate(
      n = 1,
      n2 = 1,
      n3 = 1,
      mileage = case_when(
        distance_miles <= 1 ~ "dist_less_1",
        distance_miles > 1 & distance_miles <= 3 ~ "dist_1_3",
        distance_miles > 3 & distance_miles <= 6 ~ "dist_3_6",
        distance_miles > 6 ~ "dist_more_6"
      ),
      primary_mode = mode,
      trip_purpose = travel_purpose,
      mode = paste0("mode_", mode),
      travel_purpose = paste0("purpose_", travel_purpose)
    ) |>
    pivot_wider(
      names_from = travel_purpose, values_from = n, values_fill = list(value = 0),
      values_fn = ~ mean(.x, na.rm = TRUE)
    ) |>
    pivot_wider(
      names_from = mode, values_from = n2, values_fill = list(value = 0),
      values_fn = ~ mean(.x, na.rm = TRUE)
    ) |>
    pivot_wider(
      names_from = mileage, values_from = n3, values_fill = list(value = 0),
      values_fn = ~ mean(.x, na.rm = TRUE)
    ) |>
    mutate_if(is.numeric, ~ ifelse(is.na(.), 0, .)) |>
    suppressMessages() |>
    suppressWarnings()

  if (trip_geometry == "Destinations only") {
    sf_final <- sf_final |>
      st_as_sf(coords = c("end_lng", "end_lat"), crs = 4326, remove = FALSE) |>
      st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()
  } else if (trip_geometry == "Origins only") {
    sf_final <- sf_final |>
      st_as_sf(coords = c("start_lng", "start_lat"), crs = 4326, remove = FALSE) |>
      st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()
  } else if (trip_geometry == "Destinations and origins") {
    sf_final <- sf_final |>
      st_as_sf(coords = c("end_lng", "end_lat"), crs = 4326, remove = FALSE) |>
      st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
      st_drop_geometry() |>
      st_as_sf(coords = c("start_lng", "start_lat"), crs = 4326, remove = FALSE) |>
      st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()
  } else if (trip_geometry == "Destinations or origins") {
    pts_end <- sf_final |>
      st_as_sf(coords = c("end_lng", "end_lat"), crs = 4326, remove = FALSE) |>
      st_intersects(study_area_sf, sparse = FALSE) |>
      suppressMessages() |>
      suppressWarnings()

    pts_start <- sf_final |>
      st_as_sf(coords = c("start_lng", "start_lat"), crs = 4326, remove = FALSE) |>
      st_intersects(study_area_sf, sparse = FALSE) |>
      suppressMessages() |>
      suppressWarnings()

    sf_final <- sf_final |>
      mutate(
        ends = pts_end[, 1],
        starts = pts_start[, 1]
      ) |>
      filter(ends == TRUE | starts == TRUE) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()
  } else if (trip_geometry == "Intersects") {
    sf_final <- sf_final |>
      st_as_sf(wkt = "geometry", crs = 4326, remove = FALSE) |>
      st_filter(study_area_sf |> st_transform(crs = 4326), .predicate = st_intersects) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()
  }

  print("Writing output to file")

  # Export results
  arc.write(output_path, sf_final, overwrite = TRUE, validate = TRUE) |>
    suppressMessages() |>
    suppressWarnings()

  print("Process completed successfully")
}
