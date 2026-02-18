# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
calibrate_sim_iot <- function(iot, wealth_init, tau_y = NULL) {
  tau_guess <- if (is.null(tau_y)) min(max(iot$G0 / pmax(iot$Y0, 1), 0.1), 0.5) else tau_y
  list(
    base_year = iot$base_year,
    n = iot$n,
    sector_codes = iot$sector_codes,
    sector_labels = iot$sector_labels,
    L = iot$L0,
    va_coeff = iot$va_coeff,
    beta_C = iot$beta_C,
    beta_G = iot$beta_G,
    I_i0 = iot$I_i0,
    G0 = iot$G0,
    tau_y = tau_guess,
    V0 = wealth_init$V0,
    B0 = wealth_init$B0,
    idx = find_energy_indices(iot$sector_codes)
  )
}

# @first_intro_step: 4
calibrate_sim_iot_row <- function(iot, wealth_init, tau_y = NULL) {
  tau_guess <- if (is.null(tau_y)) min(max(iot$G0 / pmax(iot$Y0, 1), 0.1), 0.5) else tau_y
  list(
    base_year = iot$base_year,
    n = iot$n,
    sector_codes = iot$sector_codes,
    sector_labels = iot$sector_labels,
    L = iot$L0,
    va_coeff = iot$va_coeff,
    beta_C = iot$beta_C,
    beta_G = iot$beta_G,
    I_i0 = iot$I_i0,
    EX_i0 = iot$EX_i0,
    m_i = iot$m_i,
    G0 = iot$G0,
    tau_y = tau_guess,
    V0 = wealth_init$V0,
    B0 = wealth_init$B0,
    idx = find_energy_indices(iot$sector_codes)
  )
}
