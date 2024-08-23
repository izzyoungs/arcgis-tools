tool_exec<- function(in_params, out_params){

  require(sf)
  require(crsuggest)
  
  input_xy <- in_params[[1]]

  arc.progress_label("Evaluating CRS...")
  arc.progress_pos(40)
  
  
  coords <- as.numeric(unlist(strsplit(input_xy, " ")))
  bbox_matrix <- matrix(c(coords[1], coords[2], coords[3], coords[4]), nrow = 2, byrow = TRUE)
  centroid_x <- mean(bbox_matrix[, 1])
  centroid_y <- mean(bbox_matrix[, 2])
  centroid_point <- st_sfc(st_point(c(centroid_x, centroid_y)), crs = 3857)
  centroid_wgs84 <- st_transform(centroid_point, crs = 4326)
  crs_suggestions <- suggest_crs(centroid_wgs84)
  
  print(crs_suggestions)
}