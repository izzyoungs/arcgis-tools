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
  equity_area <- if (is.null(in_params[[2]])) NULL else arc.open(in_params[[2]]) |> arc.select()
  year <- in_params[[3]] # Year
  quarter <- in_params[[4]] # Quarter
  day <- in_params[[5]] # Day
  email <- in_params[[6]] # Email for authentication
  output_path <- out_params[[1]] # Output path

  if (is.null(equity_area)) {
    print("Equity area not provided")
  } else {
    print("Equity area provided")
  }

  study_area_sf <- arc.data2sf(study_area) |>
    st_transform(4326) |>
    st_make_valid() |>
    summarize()

  if (is.null(equity_area)) {
    equity_area_wkt <- "None" |> glue_sql()
  } else {
    equity_area_sf <- arc.data2sf(equity_area) |>
      st_transform(4326) |>
      st_make_valid() |>
      summarize()
    equity_area_wkt <- st_as_text(equity_area_sf$geom) |> glue_sql()

    if (nchar(equity_area_wkt) > 1000) {
      bbox_equity <- st_bbox(equity_area_sf)

      bbox_equity_coords <- matrix(
        c(
          bbox_equity["xmin"], bbox_equity["ymin"], # Bottom-left
          bbox_equity["xmax"], bbox_equity["ymin"], # Bottom-right
          bbox_equity["xmax"], bbox_equity["ymax"], # Top-right
          bbox_equity["xmin"], bbox_equity["ymax"], # Top-left
          bbox_equity["xmin"], bbox_equity["ymin"] # Close the polygon
        ),
        ncol = 2, byrow = TRUE
      )

      bbox_equity_polygon <- st_polygon(list(bbox_equity_coords))
      equity_area_wkt <- st_as_text(bbox_equity_polygon) |> glue_sql()
    }
  }

  study_area_wkt <- st_as_text(study_area_sf$geom) |> glue_sql()
  if (nchar(study_area_wkt) > 1000) {
    bbox_study <- st_bbox(study_area_sf)

    bbox_study_coords <- matrix(
      c(
        bbox_study["xmin"], bbox_study["ymin"], # Bottom-left
        bbox_study["xmax"], bbox_study["ymin"], # Bottom-right
        bbox_study["xmax"], bbox_study["ymax"], # Top-right
        bbox_study["xmin"], bbox_study["ymax"], # Top-left
        bbox_study["xmin"], bbox_study["ymin"] # Close the polygon
      ),
      ncol = 2, byrow = TRUE
    )

    bbox_study_polygon <- st_polygon(list(bbox_study_coords))
    study_area_wkt <- st_as_text(bbox_study_polygon) |> glue_sql()
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
  sql_query <- glue_sql("
/* ───────────────────────── 1.  Study area & equity geometry ───────────────────────── */
WITH aoe AS (
  SELECT ST_GEOGFROMTEXT('{study_area_wkt}') AS geom
),
equity_areas AS (
  SELECT CASE
           WHEN '{equity_area_wkt}' = 'None' THEN NULL
           ELSE ST_GEOGFROMTEXT('{equity_area_wkt}')
         END AS geom
),

/* ───────────────────────── 2.  Network links inside study area ────────────────────── */
network_links AS (
  SELECT n.stableEdgeId,
         n.streetName,
         n.speed,
         n.distance,
         n.highway,
         n.flags,
         n.lanes,
         n.geometry
  FROM  `replica-customer.{region}.{region}_2024_{quarter}_network_segments` n
  JOIN  aoe a ON ST_INTERSECTS(a.geom, n.geometry)
),

/* ───────────────────────── 3.  Trip records exploded to edges ─────────────────────── */

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
      WHEN ea.geom IS NULL THEN '0'
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
  WHERE t.travel_purpose != 'HOME' AND t.mode != 'commercial' AND pop.school_grade_attending = 'not_attending_school'
  AND (ST_WITHIN(ST_GEOGPOINT(t.start_lng, t.start_lat), ea.geom) OR ST_WITHIN(ST_GEOGPOINT(t.end_lng, t.end_lat), ea.geom))
  GROUP BY stableEdgeId, v_mode, is_equity_area
),

/* ───────────────────────── 4a.  Total volumes by mode (all trips) ─────────────────── */
total_links AS (
  SELECT *
  FROM (
        SELECT stableEdgeId, v_mode, SUM(volume) AS volume
        FROM   base_data
        GROUP  BY stableEdgeId, v_mode
       )
  PIVOT ( SUM(volume) FOR v_mode IN
          ('auto','tnc','biking','carpool','walking','transit','commercial','other') )
),

/* ───────────────────────── 4b.  Equity‑area volumes by mode ───────────────────────── */
equity_links AS (
  SELECT *
  FROM (
        SELECT stableEdgeId, v_mode, SUM(volume) AS volume
        FROM   base_data
        WHERE  is_equity_area = '1'
        GROUP  BY stableEdgeId, v_mode
       )
  PIVOT ( SUM(volume) FOR v_mode IN
          ('auto','tnc','biking','carpool','walking','transit','commercial','other') )
),

/* ───────────────────────── 5.  Join totals + equity and derive roll‑ups ───────────── */

joined_links AS (
  SELECT
     COALESCE(t.stableEdgeId, e.stableEdgeId)            AS stableEdgeId,

     /* ---- mode‑specific totals ---- */
     IFNULL(t.auto,0) AS auto_total, IFNULL(e.auto,0) AS auto_equity,
     IFNULL(t.tnc,0)  AS tnc_total, IFNULL(e.tnc,0) AS tnc_equity,
     IFNULL(t.biking,0)  AS bike_total, IFNULL(e.biking,0) AS bike_equity,
     IFNULL(t.walking,0)  AS walk_total, IFNULL(e.walking,0) AS walk_equity,
     IFNULL(t.transit,0)  AS transit_total, IFNULL(e.transit,0) AS transit_equity,
     IFNULL(t.carpool,0)  AS carpool_total, IFNULL(e.carpool,0) AS carpool_equity,
     IFNULL(t.other,0)  AS oth_total, IFNULL(e.other,0) AS oth_equity,

     /* ---- roll‑ups ---- */
     /* sustainable  = transit + walk + bike */
     IFNULL(t.transit,0)+IFNULL(t.walking,0)+IFNULL(t.biking,0) AS sust_total ,
     IFNULL(e.transit,0)+IFNULL(e.walking,0)+IFNULL(e.biking,0) AS sust_equity,

     /* active = walk + bike */
     IFNULL(t.walking,0)+IFNULL(t.biking,0) AS active_total ,
     IFNULL(e.walking,0)+IFNULL(e.biking,0) AS active_equity,

     /* all = every mode above */
     (IFNULL(t.auto,0)+IFNULL(t.tnc,0)+IFNULL(t.carpool,0)+
      IFNULL(t.other,0)+IFNULL(t.transit,0)+IFNULL(t.walking,0)+IFNULL(t.biking,0)) AS all_total,
     (IFNULL(e.auto,0)+IFNULL(e.tnc,0)+IFNULL(e.carpool,0)+
      IFNULL(e.other,0)+IFNULL(e.transit,0)+IFNULL(e.walking,0)+IFNULL(e.biking,0)) AS all_equity,

  FROM   total_links  AS t
  FULL OUTER JOIN equity_links AS e USING (stableEdgeId)
),

/* ───────────────────────── 6.  Attach network attributes ──────────────────────────── */


loaded_network AS (
  SELECT n.* EXCEPT(stableEdgeId),
         j.*
  FROM   network_links n
  LEFT  JOIN joined_links j USING (stableEdgeId)
)

/* ───────────────────────── 7.  Final result ───────────────────────────────────────── */
SELECT
  stableEdgeId,
  streetName,
  speed,
  distance,
  highway,
  flags,
  lanes,

  /* mode‑specific totals + equity */
  auto_total,      auto_equity,
  tnc_total,       tnc_equity,
  bike_total,      bike_equity,
  walk_total,      walk_equity,
  transit_total,   transit_equity,
  carpool_total,   carpool_equity,
  oth_total,       oth_equity,

  /* roll‑ups */
  sust_total,      sust_equity,
  active_total,    active_equity,
  all_total,       all_equity,

  /* calculations */
  SAFE_DIVIDE(all_equity , all_total) * 100  AS total_equity_pct, /* percent of all trips that are equity */
  SAFE_DIVIDE(sust_equity, sust_total) * 100  AS sust_equity_pct, /* percent of all sustainable trips that are equity */
  SAFE_DIVIDE(active_equity, active_total) * 100  AS active_equity_pct, /* percent of all active trips that are equity */

  geometry
FROM loaded_network;", .con = DBI::ANSI()) |>
    suppressMessages() |>
    suppressWarnings()

  # Query BigQuery
  tb <- bq_project_query("replica-customer", sql_query) |>
    suppressMessages() |>
    suppressWarnings()

  print("Successfully queried BigQuery. Writing to output...")

  df_network <- bq_table_download(tb) |>
    suppressMessages() |>
    suppressWarnings()

  # Convert to spatial
  df_network <- st_as_sf(df_network, wkt = "geometry", crs = 4326) |>
    st_filter(study_area_sf) |>
    st_make_valid() |>
    mutate_if(is.numeric, ~ replace(., is.na(.), 0)) |>
    suppressMessages() |>
    suppressWarnings()

  if (nrow(df_network) > 60000) {
    temp_file <- paste0(tempdir(), "/network_large.shp")
    print(paste0("Network very large. ", nrow(df_network), " rows in data. May crash tool. Writing to shapefile in temp directory as backup: ", temp_file))

    st_write(df_network, temp_file, delete_dsn = TRUE, quiet = TRUE)
  }

  # Return as ArcGIS output
  arc.write(output_path, df_network) |>
    suppressMessages() |>
    suppressWarnings()

  print("Successfully wrote to output.")
}
