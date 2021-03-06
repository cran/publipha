functions {
#include /chunks/phma_likelihoods.stan
}

data {

  // Input data.
  int<lower = 0> N;   // Number of observations.
  int<lower = 0> k;   // Length of alpha.
  real alpha[k];      // The vector of cuttoffs.
  real yi[N];         // The estimated effect sizes.
  real vi[N];         // The study-specific variances.

  // Prior parameters.
  vector[k - 1] eta0;
  real theta0_mean;
  real <lower = 0> theta0_sd;
  real tau_mean;
  real <lower = 0> tau_sd;


}

parameters {
  real theta0;
  real theta_tilde[N];
  real <lower = 0> tau;
  simplex[k - 1] eta;

}

transformed parameters {

  real theta[N];
  for (n in 1:N) theta[n] = theta0 + tau * theta_tilde[n];

}


model {

  theta0 ~ normal(theta0_mean, theta0_sd);
  tau ~  normal(tau_mean, tau_sd) T[0, ];
  eta ~ dirichlet(eta0);
  theta_tilde ~ normal(0, 1);

  for(n in 1:N) yi[n] ~ phma_normal_lpdf(theta[n], sqrt(vi[n]), alpha, eta);

}

generated quantities {

  vector[N] log_lik;

  for(n in 1:N)
    log_lik[n] = phma_normal_lpdf(yi[n] | theta[n], sqrt(vi[n]), alpha, eta);

}
