main <- function() {
  pak::pak("Gotfrid/riskreports@report")

  assessment_packages <- list.files(
    "inst/assessments",
    full.names = FALSE,
    pattern = "\\.rds$",
    ignore.case = TRUE
  ) |> tools::file_path_sans_ext()

  assessment_paths <- normalizePath(list.files(
    "inst/assessments",
    full.names = TRUE,
    pattern = "\\.rds$",
    ignore.case = TRUE
  ))

  purrr::walk2(assessment_packages, assessment_paths, function(package, path) {
    cli::cli_alert_info(paste("Processing:", package))

    tar_path <- file.path("inst/repos/ubuntu-22.04/4.4/src/contrib", paste0(package, ".tar.gz"))
    untar(tar_path, exdir = "inst/repos/ubuntu-22.04/4.4/src/contrib")

    output_path <- file.path("inst", "validation")

    tryCatch({
      generated_path <- riskreports::package_report(
        x = file.path("inst/repos/ubuntu-22.04/4.4/src/contrib", package),
        template_path = NULL,
        params = list(
          repo = normalizePath("inst/repos/ubuntu-22.04/4.4/src/contrib"),
          package = package,
          image = "rhub/ref-image",
          assessment_path = path
        )
      )
      file.copy(generated_path, output_path, overwrite = TRUE)
      file.remove(generated_path)
    })
  })
}

main()
