
functions {
#include /functions/prior_increment.stan
}

data {
  // actual data inputs
  int M; // number of categories
  int N; // number of observations
  int P; // dimentionality of kappa parameter
  int K; // number of sites
  int pooling_type; //0 if none, 1 if partial, 2 if full
  int cat[N]; // category indicator
  int N_neg; // number of obvs in negative tail
  int N_pos; // number of obvs in positive tail
  vector[P] x[N]; // covariates
  int site[N]; // site indicator
  vector[N_neg] treatment_neg; // treatment in neg tail
  vector[N_pos] treatment_pos; // treatment in pos tail
  int site_neg[N_neg]; // site indicator in neg tail
  int site_pos[N_pos]; // site indicator in pos tail
  real y_neg[N_neg]; // the negative tail
  real y_pos[N_pos]; // the positive tail

  // now the prior inputs
  int prior_control_fam;
  int prior_hypermean_fam;
  int prior_scale_control_fam;
  int prior_scale_fam;
  int prior_control_sd_fam;
  int prior_hypersd_fam;
  int prior_scale_control_sd_fam;
  int prior_scale_sd_fam;
  int prior_kappa_fam;
  int prior_kappa_sd_fam;

  vector[3] prior_control_val;
  vector[3] prior_hypermean_val;
  vector[3] prior_scale_control_val;
  vector[3] prior_scale_val;
  vector[3] prior_kappa_val;
  vector[3] prior_control_sd_val;
  vector[3] prior_hypersd_val;
  vector[3] prior_scale_control_sd_val;
  vector[3] prior_scale_sd_val;
  vector[3] prior_kappa_sd_val;

  /* //cross-validation variables:
  int test_N;
  int test_cat[test_N]; // category indicator
  int test_N_neg; // number of obvs in negative tail
  int test_N_pos; // number of obvs in positive tail
  vector[P] test_x[N]; // covariates
  int test_site[test_N]; // site indicator
  vector[test_N_neg] test_treatment_neg; // treatment in neg tail
  vector[test_N_pos] test_treatment_pos; // treatment in pos tail
  int test_site_neg[test_N_neg]; // site indicator in neg tail
  int test_site_pos[test_N_pos]; // site indicator in pos tail
  real test_y_neg[test_N_neg]; // the negative tail
  real test_y_pos[test_N_pos]; // the positive tail */
}

transformed data {
  int K_pooled = (pooling_type == 2? 0: K); // number of modelled sites if we take pooling into account
}

parameters {
  real mu[pooling_type != 0? 2: 0];
  real tau[pooling_type != 0? 2: 0];
  real<lower=0> hypersd_mu[pooling_type == 1? 2: 0];
  real<lower=0> hypersd_tau[pooling_type == 1? 2: 0];
  real sigma_control[pooling_type != 0? 2: 0];
  real sigma_TE[pooling_type != 0? 2: 0];
  real<lower=0> hypersd_sigma_control[pooling_type == 1? 2: 0];
  real<lower=0> hypersd_sigma_TE[pooling_type == 1? 2: 0];
  matrix[K_pooled,2] eta_mu_k;
  matrix[K_pooled,2] eta_tau_k;
  matrix[K_pooled,2] eta_sigma_control_k;
  matrix[K_pooled,2] eta_sigma_TE_k;
  matrix[M-1,P] kappa[pooling_type != 0? 1: 0]; // the parent parameters, minus the Mth category
  matrix<lower=0>[M-1,P] hypersd_kappa[pooling_type == 1? 1: 0]; // the set of parent variances (not a covariance matrix)
  matrix[M-1,P] kappa_k_raw[K_pooled]; // the hierarchical increments, without the ref category
  //RM attempt 1 note: let me make kappa_k full dimensional and kappa_k_raw MINUS the ref cat
}

transformed parameters{
  matrix[M,P] kappa_k[K_pooled]; // Now this includes the ref category!
  matrix[K_pooled,2] mu_k;
  matrix[K_pooled,2] tau_k;
  matrix[K_pooled,2] sigma_control_k;
  matrix[K_pooled,2] sigma_TE_k;

  if(pooling_type == 0){
    mu_k = eta_mu_k;
    tau_k = eta_tau_k;
    sigma_control_k = eta_sigma_control_k;
    sigma_TE_k = eta_sigma_TE_k;
    for(k in 1:K){
    kappa_k[k] = append_row(kappa_k_raw[k], rep_row_vector(0, P)); // this adds the ref category
    }
  }

  if(pooling_type == 1){
    for (i in 1:2){
      mu_k[,i] = mu[i] + hypersd_mu[i]*eta_mu_k[,i];
      tau_k[,i] = tau[i] + hypersd_tau[i]*eta_tau_k[,i];
      sigma_control_k[,i] = sigma_control[i] + hypersd_sigma_control[i]*eta_sigma_control_k[,i];
      sigma_TE_k[,i] = sigma_TE[i] + hypersd_sigma_TE[i]*eta_sigma_TE_k[,i];
    }
    for (k in 1:K_pooled)
      //The last category, the reference category, must be zero
      // RM note for attempt 1: I am not sure about this multiplication operator here
      kappa_k[k] = append_row(kappa[1] + hypersd_kappa[1] .* kappa_k_raw[k], rep_row_vector(0, P));
  }
}

model {

  // PRIORS
  if(pooling_type==0){
    for (m in 1:(M-1)) // RM attempt 1 note: prior is not relevant to ref category
      for (k in 1:K)
        target += prior_increment_vec(prior_kappa_fam, kappa_k_raw[k,m]', prior_kappa_val);

    for (k in 1:K){ // should have the HYPERPARAMETER'S PRIORS WHEN YOU FIX PRIORS
      for (i in 1:2){
        target += prior_increment_real(prior_control_fam, eta_mu_k[k,i], prior_control_val);
        target += prior_increment_real(prior_hypermean_fam, eta_tau_k[k,i], prior_hypermean_val);
        target += prior_increment_real(prior_scale_control_fam, eta_sigma_control_k[k,i], prior_scale_control_val);
        target += prior_increment_real(prior_scale_fam, eta_sigma_TE_k[k,i], prior_scale_val);
      }
    }
  } // closes the pooling = 0 case

  if(pooling_type == 1){
    for (i in 1:2){
      target += prior_increment_real(prior_control_fam, mu[i], prior_control_val);
      target += prior_increment_real(prior_hypermean_fam, tau[i], prior_hypermean_val);
      target += prior_increment_real(prior_control_sd_fam, hypersd_mu[i], prior_control_sd_val);
      target += prior_increment_real(prior_hypersd_fam, hypersd_tau[i], prior_hypersd_val);
      target += prior_increment_real(prior_scale_control_fam, sigma_control[i], prior_scale_control_val);
      target += prior_increment_real(prior_scale_control_sd_fam, hypersd_sigma_control[i], prior_scale_control_sd_val);
      target += prior_increment_real(prior_scale_fam, sigma_TE[i], prior_scale_val);
      target += prior_increment_real(prior_scale_sd_fam, hypersd_sigma_TE[i], prior_scale_sd_val);
    } // closes the i loop
    target += prior_increment_vec(prior_kappa_fam, to_vector(kappa[1]) , prior_kappa_val);
    // WW: HYPERSD_kappa matrix here is converted to vector and then iid priors given on each element of this matrix
    //     is this ok?
    // RM: Yes this is right
    target += prior_increment_vec(prior_kappa_sd_fam, to_vector(hypersd_kappa[1]) , prior_kappa_sd_val);
  } // closes the pooling = 1 case

  if(pooling_type ==2){
    target += prior_increment_vec(prior_kappa_fam, to_vector(kappa[1]) , prior_kappa_val);
    for (i in 1:2){
      target += prior_increment_real(prior_control_fam, mu[i], prior_control_val);
      target += prior_increment_real(prior_hypermean_fam, tau[i], prior_hypermean_val);
      target += prior_increment_real(prior_scale_control_fam, sigma_control[i], prior_scale_control_val);
      target += prior_increment_real(prior_scale_fam, sigma_TE[i], prior_scale_val);
    } // closes the for loop indexed by i
  } // closes the pooling = 2 case



  // LIKELIHOOD
  if(N > 0){
    //Likelihood: 1/ hierarchy
    if(pooling_type==1){
      for (k in 1:K){
        for (m in 1:(M-1)){
          kappa_k_raw[k,m] ~ normal(0,1);
        }
        eta_mu_k[k] ~ normal(0,1);
        eta_tau_k[k] ~ normal(0,1);
        eta_sigma_control_k[k] ~ normal(0,1);
        eta_sigma_TE_k[k] ~ normal(0,1);
      }
    } // closes the if pooling = 1 statement


    // Likelihood: 2/ categorical logit
    // All pooling types need the data level but split up as follows
    if(pooling_type < 2){
      for (n in 1:N)
        cat[n] ~ categorical_logit(kappa_k[site[n]] * x[n]);
    } else if(pooling_type == 2){
      for (n in 1:N)
        cat[n] ~ categorical_logit(append_row(kappa[1],rep_row_vector(0, P)) * x[n]);
    }

    //Likelihood: 3/ log-normal components
    if(pooling_type < 2) {
      y_pos ~ lognormal(mu_k[site_pos,2] + tau_k[site_pos,2].*treatment_pos,
                           exp(sigma_control_k[site_pos,2] + sigma_TE_k[site_pos,2].*treatment_pos)) ;
      y_neg ~ lognormal(mu_k[site_neg,1] + tau_k[site_neg,1].*treatment_neg,
                           exp(sigma_control_k[site_neg,1] + sigma_TE_k[site_neg,1].*treatment_neg));
    } else if(pooling_type == 2) {
      y_pos ~ lognormal(mu[2] + tau[2]*treatment_pos,
                        exp(sigma_control[2] + sigma_TE[2]*treatment_pos));
      y_neg ~ lognormal(mu[1] + tau[1]*treatment_neg,
                        exp(sigma_control[1] + sigma_TE[1]*treatment_neg));
    }
  }
}
