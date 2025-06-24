tool_exec <- function(in_params, out_params) {
  arc.progress_label("Loading libraries...")
  arc.progress_pos(0)

  suppressMessages({
    library(sf)
    library(tidyverse)
    library(tidycensus)
    library(tigris)
    library(arcgisbinding)
    arc.check_product()
  })

  arc.progress_label("Loading data...")

  input_polygons <- in_params[[1]]
  fields_to_apportion <- in_params[[2]] |> unlist()
  type_of_apportionment <- in_params[[3]]
  target_polygons <- in_params[[4]]
  apportion_method <- in_params[[5]]
  weight_field <- in_params[[6]]
  output_features <- out_params[[1]]

  # get the input polygons
  input_polygons <- arc.open(input_polygons) |>
    arc.select() |>
    arc.data2sf() |>
    st_transform(4269) |>
    st_make_valid() |>
    suppressWarnings()

  # get the target polygons
  target_polygons <- arc.open(target_polygons) |>
    arc.select() |>
    arc.data2sf() |>
    st_transform(4269) |>
    st_make_valid() |>
    suppressWarnings()

  if (apportion_method == "Population") {
    print("Apportion method to weight by population requires 2020 block data. Getting the blocks that intersect the study area...")

    # get the state and counties for the input polygons
    intersecting_counties <- counties(year = 2020) |>
      st_intersection(target_polygons) |>
      st_drop_geometry() |>
      group_by(STATEFP, COUNTYFP) |>
      summarise() |>
      ungroup() |>
      suppressWarnings() |>
      suppressMessages()

    blocks_customarea <- c()

    for (i in 1:nrow(intersecting_counties)) {
      temp_blocks <- blocks(state = intersecting_counties[i, 1], county = intersecting_counties[i, 2], year = 2020, progress_bar = FALSE) |>
        suppressMessages()

      blocks_customarea <- blocks_customarea |>
        rbind(temp_blocks)
    }

    print(head(blocks_customarea))
    stop()

    blockgroups_customarea <- blocks_customarea |>
      st_drop_geometry() |>
      group_by(GEOID20) |>
      summarise(total_population = sum(POP20, na.rm = TRUE))

    block_centroids <- blocks_customarea |>
      st_centroid() |>
      left_join(blockgroups_customarea, by = "GEOID20") |>
      mutate(weight = POP20 / total_population) |>
      suppressWarnings()

    study_area_weights <- st_intersection(block_centroids, target_polygons) |>
      st_drop_geometry() |>
      suppressWarnings()

    # apportion each field based on weights
    apportioned_data <- input_polygons |>
      st_intersection(target_polygons) |>
      st_drop_geometry() |>
      left_join(study_area_weights, by = c("GEOID" = "GEOID")) |>
      group_by(GEOID) |>
      summarise(across(all_of(fields_to_apportion), ~ sum(.x * weight, na.rm = TRUE))) |>
      suppressWarnings()

    print(head(apportioned_data))

    stop()
  } else if (apportion_method == "Area") {

  }
}
