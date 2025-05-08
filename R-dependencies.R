load.lib<-c("crsuggest", "sf", "tidyverse", "tidycensus", "tigris", "arcgisbinding", "mapboxapi", "lwgeom", "units", "osmdata", "overturemapsr", "bigrquery", "glue")

install.lib <- load.lib[!load.lib %in% installed.packages()]
                        
for(lib in install.lib) install.packages(lib,dependencies=TRUE)

# Census API
tidycensus::census_api_key("YOUR_CENSUS_API_KEY", install = TRUE)

# Mapbox API
mapboxapi::mb_access_token("pk.eyas...", install = TRUE)

# BigQuery Authentication
bigrquery::bq_auth(email = "")
