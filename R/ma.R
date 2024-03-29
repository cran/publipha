#' Class \code{mafit}: Fitted Meta-analysis Model
#'
#' @name mafit-class
#' @rdname mafit-class
#' @exportClass mafit

setClass(
  Class = "mafit",
  contains = "stanfit",
  representation = representation(
    bias = "character",
    alpha = "numeric",
    yi = "numeric",
    vi = "numeric",
    parameters = "list",
    tau_prior = "character"
  )
)

#' Meta-analysis Correcting for Publication Bias or p-hacking
#'
#' Bayesian random effects meta-analysis. Correct for publication bias,
#'    correct for p-hacking, or run an ordinary meta-analysis without any
#'    correction.
#'
#' `ma` does a Bayesian meta-analysis with the type of correction used specified
#'    by `bias`. `psma` is a wrapper for `ma` with
#'    `bias = "publication selection"`, `phma` is a wrapper with
#'    `bias = "p-hacking"`, while `cma` has `bias = "none"`. The function
#'    `allma` runs all `bias` options and returns a list.
#'
#' The `bias` options are:
#'
#' 1. `publication selection`: The model of publication bias described in
#'    Hedges (1992).
#' 2. `p-hacking`: The model for *p*-hacking described in Moss & De Bin (2019).
#' 3. `none`: Classical random effects meta-analysis with no correction for
#'    selection bias.
#'
#' The effect size distribution is normal with mean \code{theta0} and standard
#'    deviation \code{tau}. The prior for \code{theta0} is normal with
#'    parameters \code{theta0_mean} (default: 0), \code{theta0_sd} (default: 1).
#'    \code{eta} is the vector of \code{K} normalized publication probabilities
#'    (publication bias model) or \code{K} *p*-hacking probabilities
#'    (*p*-hacking model). The prior of eta is Dirchlet with parameter eta0,
#'    which defaults to \code{rep(1, K)} for the publication bias model and
#'    the p-hacking model. `eta0` is the prior for the Dirichlet distribution
#'    over the non-normalized etas in the publication bias model, and they are
#'    forced to be decreasing.
#'
#'    The standard prior for \code{tau} is half-normal with parameters
#'    \code{tau_mean} (default: 0), \code{tau_sd} (default: 1). If the uniform
#'    prior is used, the parameter are \code{u_min} (default: 0), and \code{u_max}
#'    with a default of 3. The inverse Gamma has parameters \code{shape}
#'    (default: 1) and scale \code{default: 1}.
#'
#'    To change the prior parameters, pass them to `prior` in a list.
#'
#' @export
#' @name ma
#' @param yi Numeric vector of length code{k} with observed effect size
#'     estimates.
#' @param vi Numeric vector of length code{k} with sampling variances.
#' @param bias String; If "publication bias", corrects for publication bias. If
#'     "p-hacking", corrects for p-hacking.
#' @param data Optional list or data frame containing \code{yi} and \code{vi}.
#' @param alpha Numeric vector; Specifies the cutoffs for significance.
#'     Should include 0 and 1. Defaults to (0, 0.025, 0.05, 1).
#' @param prior Optional list of prior parameters. See the details.
#' @param tau_prior Which prior to use for `tau`, the heterogeneity parameter.
#'     Defaults to "`half-normal`"; "`uniform`" and "`inv_gamma` are also
#'     supported.
#' @param ... Passed to \code{rstan::sampling}.
#' @return An S4 object of class `mafit` when `ma`, `psma`, `phma` or `cma` is
#'    run. A list of `mafit` objects when `allma` is run.
#' @examples \donttest{
#' phma_model <- phma(yi, vi, data = metadat::dat.begg1989)
#' }
#' prior <- list(
#'   eta0 = c(3, 2, 1),
#'   theta0_mean = 0.5,
#'   theta0_sd = 10,
#'   tau_mean = 1,
#'   tau_sd = 1
#' )
#' \donttest{
#' psma_model <- psma(yi, vi, data = metadat::dat.begg1989, prior = prior)
#' }
#' \donttest{
#' cma_model <- psma(yi, vi, data = metadat::dat.begg1989, prior = prior)
#' }
#' \donttest{
#' model <- allma(yi, vi, data = metadat::dat.begg1989, prior = prior)
#' }
#' @references Hedges, Larry V. "Modeling publication selection effects
#' in meta-analysis." Statistical Science (1992): 246-255.
#'
#' Moss, Jonas and De Bin, Riccardo. "Modelling publication
#' bias and p-hacking" (2019) arXiv:1911.12445
#'
ma <- function(yi,
               vi,
               bias = c("publication selection", "p-hacking", "none"),
               data,
               alpha = c(0, 0.025, 0.05, 1),
               prior = NULL,
               tau_prior = c("half-normal", "uniform", "inv_gamma"),
               ...) {
  dots <- list(...)

  alpha <- sort(alpha)
  bias <- match.arg(bias, c("publication selection", "p-hacking", "none"))
  tau_prior <- match.arg(tau_prior)

  ## Finds `yi` and `vi` in `data` if it is supplied.
  if (!missing(data)) {
    yi_name <- deparse(substitute(yi))
    vi_name <- deparse(substitute(vi))
    if (!is.null(data[[yi_name]])) yi <- data[[yi_name]]
    if (!is.null(data[[vi_name]])) vi <- data[[vi_name]]
  }

  ## Populate unspecified priors with the default values.
  if (is.null(prior$eta0)) prior$eta0 <- rep(1, length(alpha) - 1)
  if (is.null(prior$theta0_mean)) prior$theta0_mean <- 0
  if (is.null(prior$theta0_sd)) prior$theta0_sd <- 1
  if (is.null(prior$tau_mean)) prior$tau_mean <- 0
  if (is.null(prior$tau_sd)) prior$tau_sd <- 1
  if (is.null(prior$min)) prior$u_min <- 0
  if (is.null(prior$max)) prior$u_max <- 3
  if (is.null(prior$shape)) prior$shape <- 1
  if (is.null(prior$scale)) prior$scale <- 1

  ## Add prior
  prior$tau_prior = switch(tau_prior,
                          "half-normal" = 1,
                          "uniform" = 2,
                          "inv_gamma" = 3)

  ## Allowed names are checked.

  allowed_names <- c(
    "eta0", "theta0_mean", "theta0_sd", "tau_mean",
    "tau_sd", "u_min", "u_max", "shape", "scale", "tau_prior"
  )

  if (!all(names(prior) %in% allowed_names)) {
    stop(paste0(
      "prior can only contain elements with names: ",
      paste0(allowed_names, collapse = ", ")
    ))
  }

  ## `parameters` in ultimately passed to stan.
  parameters <- prior
  parameters$alpha <- alpha

  ## Changes stan default parameters to something conservative.
  if (is.null(dots$control$max_treedepth)) dots$control$max_treedepth <- 15
  if (is.null(dots$control$adapt_delta)) dots$control$adapt_delta <- 0.99

  sizes <- list(
    N = length(yi),
    k = length(alpha)
  )

  input_data <- c(
    list(
      yi = yi,
      vi = vi
    ),
    sizes,
    parameters
  )

  if (bias == "publication selection") {
    eta_start <- 1 + (1:(length(alpha) - 1)) / 10
    theta_start <- rep(0, length(yi))

    if (is.null(dots$init)) {
      dots$init <- function() {
        list(
          theta0 = 0,
          tau = 1,
          theta = theta_start,
          eta = eta_start
        )
      }
    }
    model <- stanmodels$psma
  } else if (bias == "p-hacking") {
    eta_start <- rep(1, length(alpha) - 1) / (length(alpha) - 1)
    theta_start <- rep(0, length(yi))

    if (is.null(dots$init)) {
      dots$init <- function() {
        list(
          theta0 = 0,
          tau = 1,
          theta = theta_start,
          eta = eta_start
        )
      }
    }

    model <- stanmodels$phma
  } else {
    model <- stanmodels$cma
  }

  obj <- as(
    object = do_call(rstan::sampling, c(
      list(
        object = model,
        data = input_data
      ),
      dots
    )),
    Class = "mafit"
  )

  parameters$alpha <- NULL
  obj@yi <- yi
  obj@vi <- vi
  obj@parameters <- parameters
  obj@alpha <- alpha
  obj@bias <- bias
  obj@tau_prior < tau_prior
  obj
}

#' @export
#' @rdname ma
psma <- function(yi,
                 vi,
                 data,
                 alpha = c(0, 0.025, 0.05, 1),
                 prior = NULL,
                 tau_prior = c("half-normal", "uniform", "inv_gamma"),
                 ...) {
  args <- arguments(expand_dots = TRUE)
  do_call(ma, c(args, bias = "publication selection"))
}


#' @export
#' @rdname ma
phma <- function(yi,
                 vi,
                 data,
                 alpha = c(0, 0.025, 0.05, 1),
                 prior = NULL,
                 tau_prior = c("half-normal", "uniform", "inv_gamma"),
                 ...) {
  args <- arguments(expand_dots = TRUE)
  do_call(ma, c(args, bias = "p-hacking"))
}

#' @export
#' @rdname ma
cma <- function(yi,
                vi,
                data,
                prior = NULL,
                tau_prior = c("half-normal", "uniform", "inv_gamma"),
                ...) {
  args <- arguments(expand_dots = TRUE)
  do_call(ma, c(args, bias = "none"))
}

#' @export
#' @rdname ma
allma <- function(yi,
                  vi,
                  data,
                  alpha = c(0, 0.025, 0.05, 1),
                  prior = NULL,
                  tau_prior = c("half-normal", "uniform", "inv_gamma"),
                  ...) {
  args <- arguments(expand_dots = TRUE)
  list(
    phma = do_call(ma, c(args, bias = "p-hacking")),
    psma = do_call(ma, c(args, bias = "publication selection")),
    cma = do_call(ma, c(args, bias = "none"))
  )
}
