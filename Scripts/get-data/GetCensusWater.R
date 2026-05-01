tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    library(tidyverse)
    library(tigris)
    library(arcgisbinding)
  })
  arc.check_product()

  print("Reading in data...")
  study_area <- arc.open(in_params[[1]]) |> arc.select()
  study_area_sf <- arc.data2sf(study_area) |> st_transform(4326)
  acs_year <- as.numeric(in_params[[2]])

  out_fc <- out_params[[1]]

  state_info <- tigris::states(year = acs_year, progress_bar = FALSE) |>
    st_transform(4326) |>
    st_intersection(study_area_sf) |>
    st_drop_geometry() |>
    pull("STUSPS") |>
    suppressWarnings()

  county_info <- tigris::counties(state = state_info, year = acs_year, progress_bar = FALSE) |>
    st_transform(4326) |>
    st_intersection(study_area_sf) |>
    st_drop_geometry() |>
    pull("NAME") |>
    suppressWarnings()

  arc.progress_pos(60)

  print("Getting ACS 5 year data for 2019-2023...")

  water_area <- area_water(state_info,
    county_info,
    year = acs_year,
    progress_bar = FALSE,
    class = "sf"
  ) |>
    st_transform(4326) |>
    st_make_valid() |>
    st_intersection(study_area_sf) |>
    suppressWarnings()



  arc.progress_pos(80)

  print("Writing output...")

  arc.write(file.path(out_fc), water_area, overwrite = TRUE, validate = TRUE)

  arc.progress_pos(100)

  print("Done!")
}
