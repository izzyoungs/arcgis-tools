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
  destinations <- in_params[[1]] # Path to the destinations boundary
  home_locations <- in_params[[2]] # Path to the home locations boundary
  home_locations_tag <- in_params[[3]] # Path to home locations tag polygon
  home_locations_tag_field <- in_params[[4]] # Field for home locations tag
  email <- in_params[[5]] # Email for authentication
  year <- in_params[[6]] # Year
  quarter <- in_params[[7]] # Quarter
  day <- in_params[[8]] # Day
  output_path <- out_params[[1]] # Output path

  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)


  # Load Boundaries ---------------------------------------------------------

  # If destinations path is not empty, load the destinations boundary
  if (length(destinations) > 0) {
    print("Loading boundary for destinations")
    destinations_sf <- arc.open(destinations) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4269) |>
      st_make_valid() |>
      summarize() |>
      suppressMessages()

    destinations_wkt <- st_as_text(destinations_sf$geom) |> glue_sql()

    # if destinations_wkt is over 1000 characters, get the bounding box instead
    if (nchar(destinations_wkt) > 1000) {
      bbox_destinations <- st_bbox(destinations_sf)

      bbox_destinations_coords <- matrix(
        c(
          bbox_destinations["xmin"], bbox_destinations["ymin"], # Bottom-left
          bbox_destinations["xmax"], bbox_destinations["ymin"], # Bottom-right
          bbox_destinations["xmax"], bbox_destinations["ymax"], # Top-right
          bbox_destinations["xmin"], bbox_destinations["ymax"], # Top-left
          bbox_destinations["xmin"], bbox_destinations["ymin"] # Close the polygon
        ),
        ncol = 2, byrow = TRUE
      )

      bbox_destinations_polygon <- st_polygon(list(bbox_destinations_coords))
      destinations_wkt <- st_as_text(bbox_destinations_polygon) |>
        glue_sql()
    }

    where_destinations <- glue_sql("WHERE ST_WITHIN(ST_GEOGPOINT(end_lng, end_lat), ST_GEOGFROMTEXT('{destinations_wkt}'))",
      .con = DBI::ANSI()
    )

    # If the home locations path is not empty, load the home locations boundary
  } else {
    print("No destinations provided. Using home locations to determine trips.")
    where_destinations <- glue_sql("WHERE", .con = DBI::ANSI())
  }

  if (length(destinations) > 0 & length(home_locations) > 0) {
    both_and <- glue_sql("AND", .con = DBI::ANSI())
  } else {
    both_and <- glue_sql("", .con = DBI::ANSI())
  }

  if (length(home_locations) > 0) {
    print("Loading boundary for home locations")

    home_locations_sf <- arc.open(home_locations) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4269) |>
      st_make_valid() |>
      summarize() |>
      suppressMessages()

    home_locations_wkt <- st_as_text(home_locations_sf$geom) |> glue_sql()

    # if home_locations_wkt is over 1000 characters, get the bounding box instead
    if (nchar(home_locations_wkt) > 1000) {
      bbox_home_locations <- st_bbox(home_locations_sf)

      bbox_home_locations_coords <- matrix(
        c(
          bbox_home_locations["xmin"], bbox_home_locations["ymin"], # Bottom-left
          bbox_home_locations["xmax"], bbox_home_locations["ymin"], # Bottom-right
          bbox_home_locations["xmax"], bbox_home_locations["ymax"], # Top-right
          bbox_home_locations["xmin"], bbox_home_locations["ymax"], # Top-left
          bbox_home_locations["xmin"], bbox_home_locations["ymin"] # Close the polygon
        ),
        ncol = 2, byrow = TRUE
      )

      bbox_home_locations_polygon <- st_polygon(list(bbox_home_locations_coords))
      home_locations_wkt <- st_as_text(bbox_home_locations_polygon) |>
        glue_sql()
    }

    where_home_locations <- glue_sql("ST_WITHIN(ST_GEOGPOINT(lng, lat), ST_GEOGFROMTEXT('{home_locations_wkt}'))",
      .con = DBI::ANSI()
    )
  } else if (length(destinations) == 0 & length(home_locations) == 0) {
    print("No destinations or home location boundaries provided. Please provide a way to return trip table.")
    stop()
  } else {
    print("No home locations provided. Using destinations only to determine trips.")
    where_home_locations <- glue_sql("", .con = DBI::ANSI())
  }


  # Get Home Location Tags --------------------------------------------------

  if (length(home_locations_tag) > 0 & length(home_locations_tag_field) > 0) {
    home_locations_tag_sf <- arc.open(home_locations_tag) |>
      arc.select() |>
      arc.data2sf() |>
      st_transform(4269) |>
      st_make_valid() |>
      select(any_of(home_locations_tag_field)) |>
      suppressMessages()

    print(paste0("Will assign home locations the following tag: ", home_locations_tag_field))
  } else {
    print("No home location tags provided. Will not append a home location flag to table.")
  }


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

  if (length(destinations) == 0) {
    sf_megaregions <= home_locations_sf
  } else {
    sf_megaregions <- destinations_sf
  }

  megaregion <- left_join(tigris::states(cb = TRUE, year = 2023, progress_bar = FALSE), megaregions) |>
    st_intersection(sf_megaregions) |>
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
    SELECT pop.person_id, activity_id, distance_miles, mode, travel_purpose, pop.commute_mode, pop.household_size, pop.vehicles, pop.age_group, pop.sex, pop.race, pop.ethnicity, pop.employment, pop.education, start_lat, start_lng, end_lat, end_lng, pop.lat as home_lat, pop.lng as home_lng
    FROM `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_{day_sql}_trip` as trip
    LEFT JOIN `replica-customer.{megaregion}.{megaregion}_{year_sql}_{quarter_sql}_population` as pop
    ON trip.person_id = pop.person_id
    {where_destinations}
    {both_and} {where_home_locations}",
    .con = DBI::ANSI()
  )

  print("Executing SQL query...")

  # Execute SQL Query -------------------------------------------------------

  tb <- bq_project_query("replica-customer", sql) |>
    suppressMessages() |>
    suppressWarnings()

  tb_return <- bq_table_download(tb, page_size = 10000) |>
    suppressMessages() |>
    suppressWarnings()

  if (nrow(tb_return) == 0) {
    print("No results found. Please check the input parameters.")
    stop()
  }

  sf_final <- tb_return |>
    mutate(
      n = 1,
      n2 = 1,
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
    mutate_if(is.numeric, ~ ifelse(is.na(.), 0, .))

  print("Successfully retrieved data from BigQuery")


  if (length(destinations) > 0) {
    sf_final <- sf_final |>
      st_as_sf(coords = c("end_lng", "end_lat"), crs = 4326, remove = FALSE) |>
      st_intersection(destinations_sf |> st_transform(crs = 4326)) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()

    print("Removed trips outside of destination boundary")
  }

  if (length(home_locations) > 0) {
    sf_final <- sf_final |>
      st_as_sf(coords = c("home_lng", "home_lat"), crs = 4326, remove = FALSE) |>
      st_intersection(home_locations_sf |> st_transform(crs = 4326)) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()

    print("Removed trips outside of home location boundary")
  }
  if (length(home_locations_tag) > 0) {
    sf_final <- sf_final |>
      st_as_sf(coords = c("home_lng", "home_lat"), crs = 4326, remove = FALSE) |>
      st_join(home_locations_tag_sf |> st_transform(crs = 4326), join = st_intersects, left = TRUE) |>
      st_drop_geometry() |>
      suppressMessages() |>
      suppressWarnings()

    print("Added home location tag to trips")
  }

  print("Writing output to file")

  # Export results
  arc.write(output_path, sf_final, overwrite = TRUE, validate = TRUE) |>
    suppressMessages() |>
    suppressWarnings()

  print("Process completed successfully")
}
