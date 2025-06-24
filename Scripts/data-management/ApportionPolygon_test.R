library(tidyverse)
library(sf)
library(mapboxapi)
library(tigris)
sf_use_s2(FALSE)
library(mapview)

# Target Polygons ---------------------------------------------------------



# Create 5 and 10 minute walking isochrones from the center of san francisco
kc_center <- tigris::counties(state = "MO") %>%
  filter(NAME == "Jackson") |>
  st_centroid()

mapview(kc_center)

target_polygons <- mb_isochrone(
  kc_center,
  profile = "cycling",
  time = c(5, 10, 30),
  depart_at = "2025-03-31T09:00",
  denoise = .25,
  generalize = 5,
  geometry = "polygon",
  output = "sf",
  rate_limit = 300
) |>
  st_transform(4269) |>
  mutate(target_id = row_number())

mapview(target_polygons)

kc_county_fips <- c("29165", "20209", "20091", "29095", "29047")

# get the counties for Kansas City, MO
input_polygons <- tigris::counties(state = c("MO", "KS")) |>
  filter(GEOID %in% kc_county_fips) |>
  mutate(bike_riders = runif(n(), min = 5000, max = 10000),
         input_id = row_number())

mapview(input_polygons)

fields_to_apportion <- "bike_riders"
type_of_apportionment <- "Sum"
apportion_method <- "Population"



# Start Script Here -------------------------------------------------------


intersecting_counties <- tigris::counties(year = 2020) |>
  st_intersection(input_polygons) |>
  st_drop_geometry() |>
  group_by(STATEFP, COUNTYFP) |>
  summarise() |>
  ungroup() |>
  suppressWarnings() |>
  suppressMessages()

blocks_customarea <- c()

for (i in 1:nrow(intersecting_counties)) {
  temp_blocks <- blocks(state = intersecting_counties[i, 1], county = intersecting_counties[i, 2], year = 2020, progress_bar = TRUE) |>
    erase_water() |>
    suppressMessages()

  blocks_customarea <- blocks_customarea |>
    rbind(temp_blocks)
  print(paste0("Finished ", i, " of ", nrow(intersecting_counties)))
}

mapview(blocks_customarea)


# Testing -----------------------------------------------------------------


blocks_centroids <- blocks_customarea |>
  st_point_on_surface() |>
  suppressWarnings()

mapview(blocks_centroids)

# Centroids that intersect the input polygons
blocks_input <- blocks_centroids |>
  st_intersection(input_polygons) |>
  st_drop_geometry() |>
  select(input_id, POP20, GEOID20, fields_to_apportion) |>
  suppressWarnings()


# Centroids that intersect the target polygons
blocks_target <- blocks_centroids |>
  st_intersection(target_polygons) |>
  st_drop_geometry() |>
  select(target_id, POP20, GEOID20) |>
  suppressWarnings()


# Weights
weights <- blocks_input |>
  st_drop_geometry() |>
  select(GEOID20, POP20, input_id, fields_to_apportion) |>
  left_join(blocks_target) |>
  drop_na(input_id)

head(weights)

# weights_grouped <- weights |>
#   group_by(input_id) |>
#   mutate(input_pop = sum(POP20, na.rm = TRUE)) |>
#   ungroup() |>
#   mutate(target_pop = POP20,
#         input_pop)

weights |>
  group_by(target_id, input_id) |>
  summarize(pop = sum(POP20)

head(weights_grouped)
