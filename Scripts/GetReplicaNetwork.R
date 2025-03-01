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
  # conditional, if the in_params[[2]] is null write NULL to equity_area_sf otherwise open the file
  equity_area <- if(is.null(in_params[[2]])) NULL else arc.open(in_params[[2]]) |> arc.select()
  year <- in_params[[3]]             # Year
  quarter <- in_params[[4]]          # Quarter
  day <- in_params[[5]]              # Day
  email <- in_params[[6]]           # Email for authentication
  output_path <- out_params[[1]]    # Output path
  
  if (is.null(equity_area)) {
    print("Equity area not provided")
  } else {
    print("Equity area provided")
  }
  
  study_area_sf <- arc.data2sf(study_area) |> 
    st_transform(4326) |>
    st_make_valid() |>
    summarize()
  
  if(is.null(equity_area)) equity_area_wkt <- 'None' |> glue_sql()
  else{equity_area_sf <- arc.data2sf(equity_area) |> 
    st_transform(4326) |>
    st_make_valid() |>
    summarize()
    equity_area_wkt <- st_as_text(equity_area_sf$geom) |> glue_sql()}
  
  study_area_wkt <- st_as_text(study_area_sf$geom) |> glue_sql()

  # Authenticate with BigQuery
  print("Authenticating with BigQuery")
  bq_auth(email = email)

  # Create megaregions data
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
    sql_query <- glue_sql("WITH aoe AS (
  SELECT ST_GEOGFROMTEXT('{study_area_wkt}') AS geom
),

equity_areas AS (
  SELECT CASE
           WHEN '{equity_area_wkt}' = 'None'
             THEN NULL
           ELSE ST_GEOGFROMTEXT('{equity_area_wkt}')
         END AS geom
),

network_links AS (
  SELECT n.stableEdgeId, n.streetName, n.speed, n.distance, n.highway, n.flags, n.lanes, n.geometry
  FROM `replica-customer.{region}.{region}_2024_{quarter}_network_segments` n
  JOIN aoe a ON ST_INTERSECTS(a.geom, n.geometry)
),

base_data AS (
  SELECT
    stableEdgeId,
    CASE
      WHEN mode = 'ON_DEMAND_AUTO'  THEN 'tnc'
      WHEN mode = 'BIKING'  THEN 'biking'
      WHEN mode = 'PRIVATE_AUTO' THEN 'auto'
      WHEN mode = 'CARPOOL' THEN 'carpool'
      WHEN mode = 'WALKING' THEN 'walking'
      WHEN mode = 'PUBLIC_TRANSIT' THEN 'transit'
      WHEN mode = 'COMMERCIAL' THEN 'commercial'
      ELSE 'other'
    END AS v_mode,
    CASE
      WHEN ea.geom IS NULL THEN '1'
      WHEN ST_WITHIN(ST_GEOGPOINT(pop.lng, pop.lat), ea.geom) THEN '1'
      ELSE '0'
    END AS is_equity_area,
    COUNT(*) AS volume
  FROM `replica-customer.{region}.{region}_{year}_{quarter}_{day}_trip` AS t
  CROSS JOIN UNNEST(network_link_ids) AS stableEdgeId
  JOIN network_links AS n ON n.stableEdgeId = stableEdgeId
  JOIN `replica-customer.{region}.{region}_{year}_{quarter}_population` pop
    ON t.person_id = pop.person_id
  CROSS JOIN equity_areas ea
  WHERE t.travel_purpose != 'HOME'
  GROUP BY stableEdgeId, v_mode, is_equity_area
),
filtered_data AS (
  SELECT *
  FROM base_data
  WHERE is_equity_area = '1'
),
loaded_links AS (
  SELECT
    stableEdgeId,
    IFNULL(volume_auto, 0) AS auto,
    IFNULL(volume_tnc, 0) AS tnc,
    IFNULL(volume_biking, 0) AS biking,
    IFNULL(volume_carpool, 0) AS carpool,
    IFNULL(volume_walking, 0) AS walking,
    IFNULL(volume_transit, 0) AS transit,
    IFNULL(volume_commercial, 0) AS commercial,
    IFNULL(volume_other, 0) AS other
  FROM filtered_data
  PIVOT (
    SUM(volume) AS volume
    FOR v_mode IN ('auto', 'tnc', 'biking', 'carpool', 'walking', 'transit', 'commercial', 'other')
  )
),

loaded_network AS (
SELECT
n.stableEdgeID,
n.streetName,
n.speed,
n.distance,
n.highway,
n.flags,
n.lanes,
n.geometry,
ll.auto,
ll.carpool,
ll.commercial,
ll.tnc,
ll.biking,
ll.walking,
ll.transit,
ll.other
FROM network_links as n
LEFT JOIN loaded_links as ll ON n.stableEdgeId = ll.stableEdgeId
)

SELECT stableEdgeID, streetname, speed, distance, highway, flags, lanes, auto, carpool, commercial, tnc, biking, walking, transit, other, geometry,
FROM loaded_network", .con = DBI::ANSI()) |>
      suppressMessages()|>
  suppressWarnings()

    # Query BigQuery
    tb <- bq_project_query("replica-customer", sql_query) |>
      suppressMessages() |>
      suppressWarnings()

    df_network <- bq_table_download(tb) |>
      suppressMessages()|>
      suppressWarnings()

    # Convert to spatial
    sf_network <- st_as_sf(df_network, wkt = 'geometry', crs = 4326) |>
      st_filter(study_area_sf) |>
      st_make_valid() |>
      suppressMessages()|>
      suppressWarnings()
    
    if(nrow(sf_network) > 60000) {
      stop("Network too large. Please select a smaller study area.")
    }

    # Return as ArcGIS output
    arc.write(output_path, sf_network, overwrite = TRUE, validate = TRUE) |>
      suppressMessages()|>
      suppressWarnings()
}
