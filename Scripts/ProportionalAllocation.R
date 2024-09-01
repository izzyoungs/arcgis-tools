tool_exec<- function(in_params, out_params){
  
  arc.progress_label("Loading libraries...")
  arc.progress_pos(0)

  suppressMessages(require(sf))
  suppressMessages(library(dplyr))
  suppressMessages(library(tidycensus))
  suppressMessages(library(tigris))
  
  input_fc <- in_params[[1]]
  crs_string <- in_params[[2]]
  crs_object <- st_crs(crs_string)
  wkt <- arc.fromWktToP4(crs_object$wkt)

  arc.progress_label("Evaluating CRS...")
  arc.progress_pos(40)
  
  
  

  
  print(crs_suggestions)
}