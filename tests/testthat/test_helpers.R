context("baggr helper functions")
library(baggr)
set.seed(1990)

test_that("prepare_ma()", {
  expect_error(prepare_ma(schools), "individual-level")
  expect_error(prepare_ma(microcredit_simplified), "no column")
  expect_warning(prepare_ma(microcredit, outcome = "consumption"))
  expect_warning(prepare_ma(microcredit[!is.na(microcredit$treatment),],
                            outcome = "consumption"))
  expect_error(prepare_ma(microcredit_simplified, outcome = "consumption",
                          effect = "logRR"), "not binary")
  expect_error(prepare_ma(microcredit_simplified, outcome = "consumption",
                          effect = "logOR"), "not binary")

  # Prepare MA without summarising:
  df <- prepare_ma(microcredit_simplified, outcome = "consumption", summarise = F)
  expect_is(df, "data.frame")
  expect_identical(dim(df), dim(microcredit_simplified))
  expect_identical(names(df), c("treatment", "group", "outcome"))

  pm <- prepare_ma(microcredit_simplified, outcome = "consumption")
  expect_is(pm, "data.frame")
  expect_equal(dim(pm), c(5,5))
  expect_identical(names(pm), c("group", "mu", "tau", "se.mu", "se.tau"))

  pm <- prepare_ma(microcredit_simplified, outcome = "consumption", summarise = FALSE)
  expect_identical(dim(pm), dim(microcredit_simplified))

  mc2 <- microcredit_simplified
  names(mc2)[1] <- "study"
  expect_error(prepare_ma(mc2, outcome = "consumption"), "must be individual")
  expect_is(prepare_ma(mc2, group = "study", outcome = "consumption"), "data.frame")

  # prepare_ma for binary data
  df_pat2 <- data.frame(treatment = rbinom(900, 1, .5),
                        group = rep(paste("Trial", LETTERS[1:10]), each = 90))
  df_pat2$outcome <- ifelse(df_pat2$treatment, rbinom(900, 1, .3), rbinom(900, 1, .15))
  expect_is(prepare_ma(df_pat2, effect = "logOR"), "data.frame")
  expect_is(prepare_ma(df_pat2, effect = "logRR"), "data.frame")

})

test_that("binary_to_individual() and prepare_ma() with summary data", {
  df_yusuf <- read.table(text="
  trial  a n1i  c n2i
  Balcon 14  56 15  58
  Clausen 18  66 19  64
  Multicentre 15 100 12  95
  Barber 10  52 12  47
  Norris 21 226 24 228
  Kahler  3  38  6  31
  Ledwich  2  20  3  20
  ", header=TRUE)

  expect_error(binary_to_individual(df_yusuf), "group")
  expect_error(binary_to_individual(cars, group = "speed"), "undefined")

  bti <- binary_to_individual(df_yusuf, group = "trial")
  expect_is(bti, "data.frame")
  expect_equal(nrow(bti), 1101)
  expect_equal(ncol(bti), 3)

  expect_error(prepare_ma(df_yusuf, effect="logOR"))
  agg <- prepare_ma(df_yusuf, group="trial", effect="logOR")
  expect_is(agg, "data.frame")
  expect_equal(nrow(agg), 7)
  expect_equal(ncol(agg), 9)


  expect_identical(
    prepare_ma(bti, effect = "logOR"),
    agg)

  # What if we had different cols
  df_yusuf$b <- df_yusuf$n1i
  df_yusuf$d <- df_yusuf$n2i
  bti <- binary_to_individual(df_yusuf, group = "trial")
  expect_is(bti, "data.frame")
  expect_equal(nrow(bti), 1101)
  expect_equal(ncol(bti), 3)
})



test_that("labbe()", {
  df_yusuf <- read.table(text="
  trial  a n1i  c n2i
  Balcon 14  56 15  58
  Clausen 18  66 19  64
  Multicentre 15 100 12  95
  Barber 10  52 12  47
  Norris 21 226 24 228
  Kahler  3  38  6  31
  Ledwich  2  20  3  20
  ", header=TRUE)

  gg <- labbe(df_yusuf, group = "trial")
  expect_is(gg, "gg")

  expect_is(labbe(df_yusuf, shade_se = "rr"), "gg")
  expect_is(labbe(df_yusuf, plot_model = TRUE, shade_se = "rr", labels = FALSE), "gg")


})



test_that("convert_inputs()", {
  # Rubin model
  expect_is(convert_inputs(schools, "rubin"), "list")
  expect_error(convert_inputs(schools, "mutau"))
  expect_is(convert_inputs(schools, "rubin", test_data = schools[7:8,]), "list")
})

test_that("mint()", {
  # Rubin model
  expect_length(mint(rnorm(100)), 3)
  expect_length(mint(rnorm(100), sd = TRUE), 4)
  expect_length(mint(rnorm(100), median = TRUE, sd = TRUE), 5)
  expect_length(mint(rnorm(100), median = TRUE, sd = TRUE, int = .5), 5)
  expect_identical(names(mint(rnorm(100), median = TRUE, sd = TRUE, int = .5)),
                   c("25%", "mean", "75%", "median", "sd"))
})

test_that("We can set and get baggr theme", {
  expect_is(baggr_theme_get(), "theme")
  expect_is(baggr_theme_update(), "theme")
  expect_is(baggr_theme_replace(), "theme")
  capture_output(baggr_theme_set(ggplot2::theme_bw()))
})

test_that("silent_messages option", {
  expect_message(baggr(schools,
                       control = list(adapt_delta = 0.99999),
                       refresh = 0
                       )
  )
  expect_silent(baggr(schools,
                      control = list(adapt_delta = 0.99999),
                      refresh = 0,
                      silent = TRUE)
  )
}
)
