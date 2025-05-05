tool_exec<- function(in_params, out_params){

  suppressMessages(require(sf))
  suppressMessages(require(crsuggest))
  
  input_xy <- in_params[[1]]
  crs_string <- in_params[[2]]
  crs_object <- st_crs(crs_string)
  wkt <- arc.fromWktToP4(crs_object$wkt)

  arc.progress_label("Evaluating CRS...")
  arc.progress_pos(40)
  
  
  coords <- as.numeric(unlist(strsplit(input_xy, " ")))
  bbox_matrix <- matrix(c(coords[1], coords[2], coords[3], coords[4]), nrow = 2, byrow = TRUE)
  centroid_x <- mean(bbox_matrix[, 1])
  centroid_y <- mean(bbox_matrix[, 2])
  centroid_point <- st_sfc(st_point(c(centroid_x, centroid_y)), crs = wkt)
  crs_suggestions <- suggest_crs(centroid_point)
  
  print(crs_suggestions)
}