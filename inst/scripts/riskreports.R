main <- function() {
  pak::pak("Gotfrid/riskreports@report")

  assessment_packages <- list.files(
    "inst/assessments",
    full.names = FALSE,
    pattern = "\\.rds$",
    ignore.case = TRUE
  )

  assessment_paths <- normalizePath(list.files(
    "inst/assessments",
    full.names = TRUE,
    pattern = "\\.rds$",
    ignore.case = TRUE
  ))

  purrr::walk2(assessment_packages, assessment_paths, function(package, path) {
    cli::cli_alert_info(paste("Processing:", package))

    package_meta <- package |>
      tools::file_path_sans_ext() |>
      strsplit("___") |>
      unlist()

    package_name <- package_meta[1]
    package_version <- package_meta[2]

    output_path <- file.path(
      "inst", "validation",
      paste0(package_name, "_", package_version, ".html")
    )

    tryCatch({
      generated_path <- riskreports::package_report_gh_action(
        package_name = package_name,
        package_version = package_version,
        template_path = "inst/templates/template.qmd",
        repository = "inst/repos",
        docker_image = NULL,
        assessment_path = path,
        quiet = TRUE
      )
      file.copy(generated_path, output_path, overwrite = TRUE)
      file.remove(generated_path)
    })
  })
}

main()
