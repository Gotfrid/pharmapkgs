# Constants
RHUB_BASE_URL <- "https://raw.githubusercontent.com/r-hub/repos/main/"
PHARMA_BASE_URL <- "inst/repos"
PACKAGES_FILE <- "src/contrib/PACKAGES"

# Action inputs
platform <- Sys.getenv("PLATFORM", "ubuntu-22.04")
r_version <- Sys.getenv("R_VERSION", "4.4")

if (startsWith(platform, "macos")) {
  PACKAGES_FILE <- sprintf("bin/macosx/big-sur-arm64/contrib/%s/PACKAGES", r_version)
}

# Utility functions
read_packages <- function(path) {
  read.dcf(path) |>
    tibble::as_tibble()
}

load_rhub_packages <- function() {
  cli::cli_alert_info("Loading packages from r-hub")
  url <- file.path(RHUB_BASE_URL, platform, r_version, PACKAGES_FILE)
  file <- tempfile()
  readLines(url) |> writeLines(file)
  read_packages(file)
}

load_pharma_packages <- function() {
  cli::cli_alert_info("Loading packages from pharmapkgs")
  file <- file.path(PHARMA_BASE_URL, platform, r_version, PACKAGES_FILE)
  read_packages(file)
}

get_new_packages <- function(rhub_packages, pharma_packages) {
  cli::cli_alert_info("Identifying new packages")
  rhub_packages |>
    dplyr::left_join(pharma_packages, by = "Package") |>
    dplyr::mutate(
      has_new_version = purrr::map2_int(
        Version.x,
        Version.y,
        ~ utils::compareVersion(.x, .y)
      )
    ) |>
    dplyr::filter(has_new_version > 0) |>
    dplyr::select(Package, Version.x, Version.y)
}

get_package_scores <- function(packages, rhub_packages, limit) {
  cli::cli_alert_info("Scoring new packages")
  if (is.null(limit) || !is.finite(limit)) {
    limit <- length(packages)
  } else {
    limit <- min(limit, length(packages))
  }
  packages <- packages[seq_len(limit)]
  progress_bar_id <- cli::cli_progress_bar(
    name = "Assessing package:",
    status = packages[1],
    total = limit,
    type = "tasks"
  )

  # NOTE: there is a bug in riskmetric::pkg_ref
  # it doesn't respect repos argument when x is a vector
  purrr::map(packages, function(pkg) {
    download_url <- rhub_packages[rhub_packages$Package == pkg, "DownloadURL", drop = TRUE]
    curl::curl_download(
      url = download_url,
      destfile = file.path(PHARMA_BASE_URL, platform, r_version, "src/contrib", paste0(pkg, ".tar.gz"))
    )
    riskmetric::pkg_ref(
      x = pkg,
      source = "pkg_cran_remote",
      repos = file.path(RHUB_BASE_URL, platform, r_version)
    )
  }) |>
    purrr::map_dfr(function(ref) {
      cli::cli_progress_update(1, status = ref$name, id = progress_bar_id)
      assessment <- suppressMessages(riskmetric::pkg_assess(ref))
      saveRDS(
        assessment,
        file.path("inst", "assessments", paste0(ref$name, ".rds"))
      )
      assessment |>
        riskmetric::pkg_score() |>
        tibble::as_tibble() |>
        dplyr::mutate(Package = ref$name, Version = ref$version) |>
        dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
    })
}

add_new_packages <- function(
    rhub_packages,
    pharma_packages,
    new_rhub_packages_scored) {
  cli::cli_alert_info("Adding new packages to pharmapkgs")
  new_rhub_packages_with_metrics <- rhub_packages |>
    dplyr::inner_join(new_rhub_packages_scored, by = c("Package", "Version"))

  pharma_packages |>
    dplyr::filter(!Package %in% new_rhub_packages_with_metrics$Package) |>
    dplyr::bind_rows(new_rhub_packages_with_metrics) |>
    dplyr::arrange(Package)
}

#' @export
main <- function(limit = NULL) {
  rhub_packages <- load_rhub_packages()
  pharma_packages <- load_pharma_packages()
  new_rhub_packages <- get_new_packages(rhub_packages, pharma_packages)

  if (NROW(new_rhub_packages) == 0) {
    cli::cli_alert_info("No new packages found")
    return()
  }

  new_rhub_packages_scored <- get_package_scores(
    new_rhub_packages$Package,
    rhub_packages,
    limit
  )
  new_pharma_packages <- add_new_packages(
    rhub_packages,
    pharma_packages,
    new_rhub_packages_scored
  )

  write.dcf(
    new_pharma_packages,
    file = file.path(PHARMA_BASE_URL, platform, r_version, PACKAGES_FILE)
  )
}

main(limit = as.numeric(Sys.getenv("LIMIT", 5)))
