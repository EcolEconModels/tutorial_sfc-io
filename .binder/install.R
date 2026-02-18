options(repos = c(CRAN = "https://cloud.r-project.org"))

required_packages <- c("jsonlite", "ggplot2")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}
