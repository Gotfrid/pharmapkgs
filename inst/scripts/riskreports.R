repo_path <- function() {
  platform <- Sys.getenv("PLATFORM", "ubuntu-22.04")
  r_version <- Sys.getenv("R_VERSION", "4.4")
  file.path("inst", "repos", platform, r_version, "src", "contrib")
}

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

    tar_path <- file.path(repo_path(), paste0(package, ".tar.gz"))
    untar(tar_path, exdir = repo_path())

    output_path <- file.path("inst", "report")

    tryCatch({
      generated_path <- riskreports::package_report(
        x = file.path(repo_path(), package),
        template_path = NULL,
        params = list(
          repo = normalizePath(repo_path()),
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
