# Auto-extracted helper functions for standalone step tutorials.
# Do not edit generated blocks manually unless updating all step usage.

# @first_intro_step: 2
simulate_sim_iot_endogenous <- function(calib,
                                        T = 20,
                                        c_y = 0.82,
                                        c_v = 0.03,
                                        g_G = 0.01,
                                        transition_speed = 0.0015,
                                        transition_signal_weight = 1) {
  years <- calib$base_year + seq_len(T) - 1
  out <- data.frame(
    year = years,
    GDP = NA_real_, TAX = NA_real_, YD = NA_real_, C = NA_real_, G = NA_real_,
    V = NA_real_, DEF = NA_real_, B = NA_real_, betaC_brown = NA_real_, betaC_green = NA_real_
  )

  V_prev <- calib$V0
  B_prev <- calib$B0
  G_prev <- calib$G0
  x_prev <- as.numeric(calib$L %*% (calib$beta_C * sum(calib$I_i0) + calib$beta_G * calib$G0 + calib$I_i0))
  beta_C <- calib$beta_C
  beta_G <- calib$beta_G

  for (tt in seq_len(T)) {
    G_t <- if (tt == 1) calib$G0 else G_prev * (1 + g_G)

    if (is.finite(calib$idx$idx_green) && is.finite(calib$idx$idx_brown)) {
      signal <- (x_prev[calib$idx$idx_green] - x_prev[calib$idx$idx_brown]) / pmax(sum(abs(x_prev)), 1)
      shift <- max(0, transition_speed * (1 + transition_signal_weight * signal))
      shift <- min(shift, max(beta_C[calib$idx$idx_brown] - 1e-8, 0))
      beta_C[calib$idx$idx_brown] <- beta_C[calib$idx$idx_brown] - shift
      beta_C[calib$idx$idx_green] <- beta_C[calib$idx$idx_green] + shift
    }

    k <- as.numeric(t(calib$va_coeff) %*% (calib$L %*% beta_C))
    b <- as.numeric(t(calib$va_coeff) %*% (calib$L %*% (beta_G * G_t + calib$I_i0)))
    den <- 1 - c_y * (1 - calib$tau_y) * k
    C_t <- max((c_y * (1 - calib$tau_y) * b + c_v * V_prev) / den, 0)

    fd_t <- beta_C * C_t + beta_G * G_t + calib$I_i0
    x_t <- pmax(as.numeric(calib$L %*% fd_t), 0)
    Y_t <- sum(calib$va_coeff * x_t)
    TAX_t <- calib$tau_y * Y_t
    YD_t <- Y_t - TAX_t

    V_t <- V_prev + YD_t - C_t
    DEF_t <- G_t - TAX_t
    B_t <- B_prev + DEF_t

    out[tt, c("GDP", "TAX", "YD", "C", "G", "V", "DEF", "B", "betaC_brown", "betaC_green")] <- c(
      Y_t, TAX_t, YD_t, C_t, G_t, V_t, DEF_t, B_t,
      if (is.finite(calib$idx$idx_brown)) beta_C[calib$idx$idx_brown] else NA_real_,
      if (is.finite(calib$idx$idx_green)) beta_C[calib$idx$idx_green] else NA_real_
    )

    x_prev <- x_t
    V_prev <- V_t
    B_prev <- B_t
    G_prev <- G_t
  }

  out
}
