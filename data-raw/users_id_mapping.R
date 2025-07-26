## code to prepare `users_id_mapping` dataset goes here

library(tidyverse)
tjnu_scanner <- read_csv(
  "data-raw/tjnu-scanner.csv",
  show_col_types = FALSE
) |>
  deframe()
users_fmri <- fs::dir_ls(
  "data-raw/fMRI",
  all = TRUE,
  recurse = TRUE,
  type = "file",
  regexp = "user"
) |>
  read_csv(show_col_types = FALSE, id = "path") |>
  filter(id < 999) |>
  mutate(
    site = if_else(
      str_detect(path, "20230526"),
      "SICNU",
      "TJNU"
    ),
    .before = 1L,
    .keep = "unused"
  ) |>
  distinct() |>
  mutate(
    user_name = case_match(
      name,
      "扎木热" ~ "扎米热",
      .default = name
    ),
    user_sex = (sex == "女") + 1,
    user_dob = as.Date(dob),
    suffix = if_else(
      site == "TJNU",
      tjnu_scanner[sprintf("%03d", id)],
      ""
    )
  )
users <- tarflow.iquizoo::fetch_iquizoo_mem()(
  readr::read_file("data-raw/users.sql")
)
users_match_all <- users_fmri |>
  left_join(users, by = join_by(user_name, user_sex, user_dob))
users_match_remained <- users_match_all |>
  filter(is.na(user_id)) |>
  select(names(users_fmri), -user_dob) |>
  left_join(users, by = join_by(user_name, user_sex))
users_id_mapping <- users_match_all |>
  filter(!is.na(user_id)) |>
  bind_rows(users_match_remained) |>
  mutate(subject = sprintf("%s%003d%s", site, id, suffix)) |>
  pull(user_id, name = subject)
usethis::use_data(users_id_mapping, overwrite = TRUE)
