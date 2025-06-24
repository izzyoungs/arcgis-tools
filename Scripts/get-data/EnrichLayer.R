tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    library(tidyverse)
    library(tidycensus)
    library(tigris)
    library(arcgisbinding)
  })
  arc.check_product()

  arc.progress_label("Reading in data...")

  source_dataset <- in_params[[1]]
  concepts_params <- in_params[[2]]
  selected_concepts <- unlist(concepts_params)

  # replace shortened names with full concept names
  selected_concepts <- selected_concepts |>
    str_replace_all("Limited English Households", "Household Language by Household Limited English Speaking Status") |>
    str_replace_all("Vehicle Availablility", "Tenure by Vehicles Available") |>
    str_replace_all("Poverty Status in the Past 12 Months for Households", "Poverty Status in the Past 12 Months by Household Type by Age of Householder")

  acs_year <- in_params[[3]] |> as.numeric()
  out_fc <- out_params[[1]]
  open <- arc.open(source_dataset)
  input_df <- arc.select(open)
  study_area <- arc.data2sf(input_df) |>
    st_transform(4269)

  print("Finding study area state and county...")

  arc.progress_pos(40)

  # Get the counties for the entire US
  sf_counties <- counties(year = 2020, progress_bar = FALSE) |>
    suppressMessages()

  # Get the counties that intersect with the study area
  state_customarea <- st_intersection(sf_counties, study_area) |>
    select(STATEFP, COUNTYFP) |>
    st_drop_geometry() |>
    suppressWarnings()

  # Get the state and county FIPS codes
  state <- state_customarea$STATEFP[1]
  county <- state_customarea$COUNTYFP[1]

  # Get the blocks for the study area with the population totals from 2020
  blocks_customarea <- blocks(state = state, county = county, year = 2020, progress_bar = FALSE) |>
    mutate(GEOID = paste0(STATEFP20, COUNTYFP20, TRACTCE20, str_sub(BLOCKCE20, 1, 1))) |>
    suppressMessages()

  # Get the block groups for the study area with the population totals from 2020
  blockgroups_customarea <- blocks_customarea |>
    st_drop_geometry() |>
    group_by(GEOID) |>
    summarise(total_population = sum(POP20, na.rm = TRUE))

  # Get the block centroids that intersect with the study area and calcualte the weight for each block in a block group (ACS geo)
  block_centroids <- blocks_customarea |>
    st_centroid() |>
    left_join(blockgroups_customarea, by = "GEOID") |>
    mutate(weight = POP20 / total_population) |>
    suppressWarnings()

  # Get the weights for the block groups that intersect with the study area
  study_area_weights <- st_intersection(block_centroids, study_area) |>
    st_drop_geometry() |>
    suppressWarnings()

  arc.progress_pos(60)

  print(paste0("Getting ACS data for ", acs_year, "..."))

  vars <- load_variables(year = acs_year, dataset = "acs5") |>
    mutate(
      label = str_replace_all(label, "!!", " "),
      label = str_replace_all(label, ":$", ""),
      label = str_replace_all(label, "\n", ""),
      label = str_replace_all(label, '\"', ""),
      label = str_replace_all(label, "Estimate Total: ", "")
    )



  # Filter variables based on selected concepts
  variables_to_get <- vars |>
    # Get total population and housing units totals
    filter(
      concept %in% selected_concepts | name == "B01003_001" | name == "B25001_001",
      # Remove variables that are not limited English speaking
      !(concept == "Household Language by Household Limited English Speaking Status" & !str_detect(label, "Limited English speaking household")),
      # Remove variables that are not limited or no vehicle availability
      !(concept == "Tenure by Vehicles Available" & !str_detect(label, "1 vehicle|No vehicle")),
      # Keep only the most used race categories
      !(concept == "Hispanic or Latino Origin by Race" & !str_detect(name, "B03002_012|B03002_003|B03002_004|B03002_005|B03002_006|B03002_007|B03002_008")),
      # Remove variables that are not relevant to educational attainment
      !(concept == "Educational Attainment for the Population 25 Years and Over" & str_detect(label, "grade|Some college|Kindergarten|Nursery")),
      # Remove variables that are not relevant to employment status
      !(concept == "Employment Status for the Population 16 Years and Over" & !str_detect(label, "In labor force: Civilian labor force")),
      # Only return the households under the poverty rate
      !(concept == "Poverty Status in the Past 12 Months by Household Type by Age of Householder" & !str_detect(name, "B17017_002")),
      # Remove variables that are not relevant to transportation
      !(concept == "Means of Transportation to Work" & str_detect(label, "carpool|Bus|subway|train|Ferryboat|rail")),
      # Remove drove alone variable; it can be determined in another way
      !(name == "B08301_003"),
      # Remove the total population variable if it is not the total population concept
      (label != "Estimate Total" | name == "B01003_001" | name == "B25001_001")
    ) |>
    # Rename the labels to be more user friendly
    mutate(
      label = case_when(concept == "Housing Units" ~ "Total Housing Units",
        concept == "Total Population" ~ "Total Population",
        .default = label
      ),
      concept = ifelse(concept == "Tenure by Vehicles Available", "Tenure by Vehicles Available for Households", concept),
      # Create a denominator for the variables
      Denominator = case_when(str_detect(concept, "Housing|Household") ~ "Housing Units",
        label == "Estimate Median gross rent" ~ "Other",
        label == "In labor force: Civilian labor force" ~ "Other",
        str_detect(label, "In labor force: Civilian labor force: Employed|In labor force: Civilian labor force: Unemployed") ~ "Labor Force",
        .default = "Population"
      )
    )

  variable_codes <- variables_to_get$name

  var_lookup <- variables_to_get |>
    select(name, label)

  acs_data <- get_acs(
    geography = "block group",
    variables = variable_codes,
    state = state,
    county = county,
    year = acs_year,
    geometry = TRUE,
    progress = FALSE
  ) |>
    st_filter(study_area) |>
    suppressMessages() |>
    suppressWarnings()

  replace_words <- function(text) {
    replacements <- c(
      "estimate" = "est",
      "total" = "tot",
      "housing units" = "hhs",
      "income" = "inc",
      "in the past 12 months" = "", # Remove this completely
      " at or" = "", # Remove this completely
      "for the " = "", # Remove this completely
      " 5 years and over" = "", # Remove this completely
      " alone" = "", # Remove this completely
      " of one" = " 1", # Remove this completely
      " est median" = "med",
      " american indian and alaska native" = "ai_an",
      "native hawaiian and other pacific islander" = "nh_pi",
      " black or african american" = "black",
      " some other race" = "oth",
      "worked from home" = "wfh",
      ", truck, or van" = "",
      "public transportation" = "transit",
      "drove" = "",
      "other means" = "oth_transp",
      "excluding taxicab" = "",
      "carpooled" = "carpool",
      "schooling" = "schl",
      "completed" = "comp",
      "regular high school diploma" = "hs",
      "associate's" = "assoc",
      "bachelor's" = "bach",
      "doctorate" = "dr",
      "degree" = "deg",
      "graduate" = "grad",
      "professional" = "prof",
      " or alternative credential" = "",
      "in labor force" = "ilf",
      "civilian labor force" = "",
      "poverty" = "pov",
      "level" = "lvl",
      "limited" = "ltd",
      "english" = "eng",
      "occupied" = "occ",
      "vehicle" = "veh",
      "available" = "avlbl",
      "owner" = "own",
      "renter" = "rent",
      "population" = "pop",
      "years" = "yrs",
      "minutes" = "mins",
      " grade" = "", # Remove this completely
      "not hispanic or latino" = "",
      "or latino" = ""
    )

    # Apply replacements using gsub
    Reduce(function(x, pattern) gsub(pattern, replacements[pattern], x, ignore.case = TRUE),
      names(replacements),
      init = text
    )
  }

  acs_wide <- acs_data |>
    select(GEOID, variable, estimate, geometry) |>
    left_join(variables_to_get, by = c("variable" = "name")) |>
    mutate(
      concept = case_when(concept == "Household Language by Household Limited English Speaking Status" ~ "Limited English Households",
        concept == "Tenure by Vehicles Available" ~ "Vehicle Availablility",
        .default = concept
      ),
      label = case_when(concept == "Limited English Households" ~ "Limited English Households",
        str_detect(label, "1 vehicle") ~ "One vehicle available",
        str_detect(label, "No vehicle") ~ "No vehicle available",
        .default = label
      ),
      label = replace_words(label)
    )

  study_area_acs <- left_join(study_area_weights, acs_wide, by = "GEOID", relationship = "many-to-many") |>
    mutate(weighted_sum = weight * estimate) |>
    group_by(label, Denominator) |>
    summarise(estimate = round(sum(weighted_sum))) |>
    ungroup() |>
    pivot_wider(names_from = c(label, Denominator), values_from = estimate) |>
    ungroup() |>
    rename_with(janitor::make_clean_names) |>
    # Create percentages with the correct denominators
    mutate(
      across(
        ends_with("_population") & !matches("tot_pop"), # select columns ending in _population
        ~ (.x / tot_pop_population) * 100, # transformation
        .names = "{.col}_pct" # name of new columns
      ),
      across(
        ends_with("_housing_units") & !matches("tot_hhs"), # select columns ending in _housing_units
        ~ (.x / tot_hhs_housing_units) * 100, # transformation
        .names = "{.col}_pct" # name of new columns
      ),
      across(
        ends_with("_labor_force"), # select columns ending in _labor_force
        ~ (.x / ilf_other) * 100, # transformation
        .names = "{.col}_pct" # name of new columns
      )
    ) |>
    mutate(across(everything(), ~ replace_na(., 0))) |>
    rename_with(~ str_remove_all(.x, "_population|_housing_units|_labor_force|_other")) |>
    suppressMessages()

  arc.progress_pos(90)

  print("Joining results and writing out data...")

  output_data <- study_area |>
    cbind(study_area_acs)

  # Test if the max length of the field names is less than 30 characters
  if (max(nchar(names(output_data))) > 30) {
    stop("Field names are too long. Please address field abbreviation logic in script or tool will crash.")
  } else {
    arc.write(out_fc, output_data, overwrite = TRUE)
  }

  arc.progress_pos(100)

  print("Done!")
}
