# Selected normal effect size distribution.
# Copyright (C) 2019 Jonas Moss
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.

#' Selected Normal Effect Size Distribution
#'
#' Density, random variate generation, and expectation calculation for the
#'     effect size distribution of the one-sided normal publication bias model.
#'
#' The effect size distribution for the publication selection model is not
#'     normal, but has itself been selected for. These functions assume a
#'     normal underlying effect size distribution and one-sided selection on the
#'     effects.
#'
#' @name snorm
#' @export
#' @param x vector of quantiles.
#' @param n number of observations. If \code{length(n) > 1}, the length is taken
#'     to be the number required.
#' @param theta0 vector of means.
#' @param tau vector of heterogeneity parameters.
#' @param sigma vector of study standard deviations.
#' @param alpha vector of thresholds for publication bias.
#' @param eta vector of publication probabilities, normalized to sum to 1.
#' @param log logical; If \code{TRUE}, probabilities are given as
#'     \code{log(p)}.
#' @return `dsnorm` gives the density, `psnorm` gives the distribution
#'    function, and `rsnorm` generates random deviates.
#' @references Hedges, Larry V. "Modeling publication selection effects
#' in meta-analysis." Statistical Science (1992): 246-255.
#'
#' Moss, Jonas and De Bin, Riccardo. "Modelling publication
#' bias and p-hacking" (2019) arXiv:1911.12445
#'
#' @examples
#' rsnorm(100, theta0 = 0, tau = 0.1, sigma = 0.1, eta = c(1, 0.5, 0.1))
dsnorm <- Vectorize(function(x, theta0, tau, sigma,
                             alpha = c(0, 0.025, 0.05, 1),
                             eta, log = FALSE) {
  stopifnot(length(alpha) == (length(eta) + 1))
  density_input_checker(x, theta0 = theta0, tau = tau, sigma = sigma)

  if (log) {
    log(I(sigma, x, alpha, eta)) + stats::dnorm(x, theta0, tau, log = TRUE) -
      log(J(sigma, theta0, tau, alpha, eta))
  } else {
    I(sigma, x, alpha, eta) * stats::dnorm(x, theta0, tau) /
      J(sigma, theta0, tau, alpha, eta)
  }
}, vectorize.args = c("x", "theta0", "tau"))

#' @rdname snorm
#' @export
rsnorm <- function(n, theta0, tau, sigma, alpha = c(0, 0.025, 0.05, 1), eta) {
  stopifnot(length(alpha) == (length(eta) + 1))
  density_input_checker(1, theta0 = theta0, tau = tau, sigma = sigma)
  if (length(n) > 1) n <- length(n)

  stopifnot(length(alpha) == (length(eta) + 1))

  samples <- rep(NA, n)
  sigma <- rep_len(sigma, length.out = n)
  theta0 <- rep_len(theta0, length.out = n)
  tau <- rep_len(tau, length.out = n)

  for (i in 1:n) {
    while (TRUE) {
      proposal <- stats::rnorm(1, theta0[i], tau[i])
      probability <- I(sigma[i], proposal, alpha, eta)

      if (probability > stats::runif(1)) {
        samples[i] <- proposal
        break
      }
    }
  }

  samples
}

#' @rdname snorm
#' @export
esnorm <- Vectorize(function(theta0, tau, sigma, alpha, eta) {
  stopifnot(length(alpha) == (length(eta) + 1))
  density_input_checker(1, theta0 = theta0, tau = tau, sigma = sigma)
  integrand <- function(theta) {
    theta * dsnorm(theta, theta0, tau, sigma, alpha, eta)
  }

  integrate(integrand, lower = -Inf, upper = Inf)$value
}, vectorize.args = c("sigma", "theta0", "tau"))
