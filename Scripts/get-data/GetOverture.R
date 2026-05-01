#' Tool Name: Overture Data Extractor
#' Purpose: Extract Overture data for a user-defined study area
#' Author: Izzy Youngs
#' Date: December 2025
#' Copyright: 2025

# Load required libraries
arc.progress_label("Loading libraries...")
suppressMessages({
  library(arcgisbinding)
  arc.check_product()
  library(sf)
  library(dplyr)
  library(osmdata)
  library(arrow)
})

tool_exec <- function(in_params, out_params) {
  # Read input parameters
  study_area <- arc.open(in_params[[1]]) |> arc.select()
  confidence_level <- in_params[[2]]

  output <- out_params[[1]]

  arc.progress_pos(10)
  print("Extracting bounding box from input study area...")

  # Convert study area to sf and get bounding box
  study_area_sf <- arc.data2sf(study_area) |>
    st_transform(4326) |>
    st_make_valid()

  sf_bbox <- st_bbox(study_area_sf)

  arc.progress_pos(30)

  print("Fetching places from Overture S3 bucket...")

  places <- open_dataset("s3://overturemaps-us-west-2/release/2025-12-17.0/theme=places/type=place/?region=us-west-2")

  print("Filtering places by bounding box...")
  result <- places |>
    filter(
      bbox$xmin > sf_bbox[1],
      bbox$ymin > sf_bbox[2],
      bbox$xmax < sf_bbox[3],
      bbox$ymax < sf_bbox[4]
    )

  arc.progress_pos(50)

  print("Processing Overture places...")

  # convert result to df
  sf_data <- as.data.frame(result)

  sf_data$name <- sf_data$names[[1]]
  sf_data$category <- sf_data$categories[[1]]

  print("Selecting necessary columns and filtering by confidence level...")
  sf_cleaned <- sf_data |>
    select(c("id", "geometry", "name", "category", "confidence")) |>
    filter(confidence >= confidence_level)

  print("Writing Overture places to output geodatabase...")
  arc.write(output, sf_cleaned, overwrite = TRUE)

  arc.progress_pos(100)
  print("Process complete.")
}
