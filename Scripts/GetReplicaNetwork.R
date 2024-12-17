#' Tool Name: Get Network Volumes
#' Purpose: Retrieve network link volumes for a specified region and income type.
#' Author: Izzy Youngs
#' Date: 2024-06-16
#' Copyright: © 2024 Izzy Youngs
#'
#' Inputs:
#'   - State Abbreviation: (string) State abbreviation (e.g., 'OR')
#'   - County Name: (string) County name (e.g., 'Multnomah County')
#'   - Income: (string) 'low-income' or 'none'
#'
#' Outputs:
#'   - An output feature class or shapefile containing network volumes.
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
  state_abb <- in_params[[1]]        # State abbreviation
  county_name <- in_params[[2]]      # County name
  income <- in_params[[3]]           # Income type
  year <- in_params[[4]]             # Year
  quarter <- in_params[[5]]          # Quarter
  day <- in_params[[6]]              # Day
  breakdown <- in_params[[7]]        # Breakdown
  email <- in_params[[8]]           # Email for authentication
  output_path <- out_params[[1]]    # Output path

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

  megaregions_fips <- left_join(tigris::fips_codes, megaregions, by = c("state" = "STUSPS"))

  # Read megaregion data
  fips_for_county <- megaregions_fips |>
    filter(state == state_abb, county == county_name)


    region <- glue_sql(fips_for_county$Megaregion)
    county_fips <- glue_sql(paste0(fips_for_county$state_code, fips_for_county$county_code))
    year <- glue_sql(year)
    quarter <- glue_sql(quarter)
    day <- glue_sql(day)

    # Construct income condition
    income_filter <- if (income == 'Low-Income') glue_sql("WHERE is_low_income > 0") else ""

    # SQL Query
    sql_query <- glue_sql("WITH aoe AS (
  SELECT geom
  FROM `replica-customer.Geos.cty`
  WHERE raw_id = '{county_fips}'
),

network_links AS (
  SELECT n.stableEdgeId, n.streetName, n.speed, n.distance, n.highway, n.flags, n.lanes,
  ST_Azimuth(st_startpoint(n.geometry), st_endpoint(n.geometry))*57.2958 as degrees, n.geometry
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
      WHEN household_size = '1_person' AND household_income <= 66100 THEN 1
      WHEN household_size = '2_person' AND household_income <= 75550 THEN 1
      WHEN household_size = '3_person' AND household_income <= 85000 THEN 1
      WHEN household_size = '4_person' AND household_income <= 94400 THEN 1
      WHEN household_size = '5_person' AND household_income <= 102000 THEN 1
      WHEN household_size = '6_person' AND household_income <= 109550 THEN 1
      WHEN household_size = '7_person' AND household_income <= 117100 THEN 1
      WHEN household_size = '7_plus_person' AND household_income <= 124650 THEN 1
      ELSE 0
    END AS is_low_income,
    COUNT(*) AS volume
  FROM `replica-customer.{region}.{region}_2024_{quarter}_{day}_trip` AS t
  CROSS JOIN UNNEST(network_link_ids) AS stableEdgeId
  JOIN network_links AS n ON n.stableEdgeId = stableEdgeId
  LEFT JOIN `replica-customer.{region}.{region}_2024_{quarter}_population` pop
    ON t.person_id = pop.person_id
  GROUP BY stableEdgeId, mode, household_size, household_income
),
filtered_data AS (
  SELECT *
  FROM base_data
  {income_filter}
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
n.degrees,
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

SELECT stableEdgeID, streetname, speed, distance, highway, flags, lanes, degrees, auto, carpool, commercial, tnc, biking, walking, transit, other, geometry,
FROM loaded_network", .con = DBI::ANSI()) |>
      suppressMessages()

    # Query BigQuery
    tb <- bq_project_query("replica-customer", sql_query) |>
      suppressMessages()

    df_network <- bq_table_download(tb) |>
      suppressMessages()

    # Convert to spatial
    sf_network <- st_as_sf(df_network, wkt = 'geometry', crs = 4326) |>
      suppressMessages()

    # Return as ArcGIS output
    arc.write(output_path, sf_network) |>
      suppressMessages()
}
