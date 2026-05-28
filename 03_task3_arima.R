# ============================================================
# FINAL — Task 3 (8 pts): Time Series & ARIMA on BTC
# - ADF stationarity test on price & on log-returns
# - ACF / PACF
# - Fit ARIMA via auto.arima
# - Forecast 12 days ahead
# - RMSE / MAE on a held-out tail
# Plots: t3_acf_pacf.png, t3_forecast.png, t3_residuals.png
# ============================================================

suppressPackageStartupMessages({
  library(forecast)
  library(tseries)
})

prices  <- read.csv("crypto_clean.csv", stringsAsFactors = FALSE)
prices$date <- as.Date(prices$date)
btc_df  <- prices[, c("date","BTC")]

# Work on log-price (variance more stable in log space -> better ARIMA fit)
btc_df$log_btc <- log(btc_df$BTC)

# ------------------------------------------------------------
# Train / test split — hold out last 30 days for honest forecast accuracy
# ------------------------------------------------------------
H_eval <- 30                          # rolling test horizon
H_fc   <- 12                          # required forecast horizon
n      <- nrow(btc_df)
train_idx <- 1:(n - H_eval)
test_idx  <- (n - H_eval + 1):n

train_log <- btc_df$log_btc[train_idx]
test_log  <- btc_df$log_btc[test_idx]
train_p   <- btc_df$BTC    [train_idx]
test_p    <- btc_df$BTC    [test_idx]

cat("Train obs:", length(train_log), "  Test obs:", length(test_log), "\n")
cat("Train end:", as.character(btc_df$date[max(train_idx)]),
    " | Test end:", as.character(btc_df$date[n]), "\n")

# ------------------------------------------------------------
# (a) Stationarity — ADF on the level and on log-returns
# ------------------------------------------------------------
adf_lvl <- adf.test(train_log)        # log price
ret     <- diff(train_log)
adf_ret <- adf.test(ret)

cat("\n=== ADF tests ===\n")
cat(sprintf("Log-price : statistic = %7.3f  p-value = %.4f  -> %s\n",
            adf_lvl$statistic, adf_lvl$p.value,
            ifelse(adf_lvl$p.value < 0.05, "STATIONARY", "NON-stationary")))
cat(sprintf("Log-return: statistic = %7.3f  p-value = %.4f  -> %s\n",
            adf_ret$statistic, adf_ret$p.value,
            ifelse(adf_ret$p.value < 0.05, "STATIONARY", "NON-stationary")))

cat("\nndiffs(log-price) =", ndiffs(train_log), "\n")

# ------------------------------------------------------------
# (b) ACF / PACF — both on the level (shows non-stationarity) and on returns
# ------------------------------------------------------------
png("t3_acf_pacf.png", width = 1000, height = 700)
op <- par(mfrow = c(2,2), mar = c(4,4,3,1))
acf (train_log, lag.max = 40, main = "ACF — log-price (non-stationary)")
pacf(train_log, lag.max = 40, main = "PACF — log-price")
acf (ret,       lag.max = 40, main = "ACF — log-returns (stationary)")
pacf(ret,       lag.max = 40, main = "PACF — log-returns")
par(op); dev.off()

# ------------------------------------------------------------
# (c) Fit ARIMA on the log-price (auto.arima picks d itself)
# ------------------------------------------------------------
fit <- auto.arima(train_log, seasonal = FALSE,
                  stepwise = FALSE, approximation = FALSE,
                  max.p = 5, max.q = 5, ic = "aic")

cat("\n=== ARIMA model ===\n"); print(summary(fit))
cat("AIC =", round(AIC(fit), 2), "  BIC =", round(BIC(fit), 2), "\n")

# ------------------------------------------------------------
# (d) Forecast for H_eval days (= 30) to compute RMSE/MAE,
#     then a fresh forecast for the next H_fc days (= 12) from the full series.
# ------------------------------------------------------------
fc_eval <- forecast(fit, h = H_eval)

pred_log <- as.numeric(fc_eval$mean)
pred_p   <- exp(pred_log)             # back to USD

rmse <- sqrt(mean((test_p - pred_p)^2))
mae  <- mean(abs(test_p - pred_p))
mape <- mean(abs((test_p - pred_p) / test_p)) * 100

cat(sprintf("\n=== Out-of-sample accuracy (last %d days) ===\n", H_eval))
cat(sprintf("RMSE = %10.2f USD\n", rmse))
cat(sprintf("MAE  = %10.2f USD\n", mae))
cat(sprintf("MAPE = %10.2f %%\n", mape))

# Naive baseline (price unchanged) for comparison — beats most ARIMAs on prices
naive_pred <- rep(train_p[length(train_p)], H_eval)
naive_rmse <- sqrt(mean((test_p - naive_pred)^2))
naive_mae  <- mean(abs(test_p - naive_pred))
cat(sprintf("Naive RMSE = %10.2f  MAE = %10.2f\n", naive_rmse, naive_mae))

# Refit on the FULL series and forecast the next 12 days (the actual deliverable)
fit_full <- auto.arima(btc_df$log_btc, seasonal = FALSE,
                       stepwise = FALSE, approximation = FALSE,
                       max.p = 5, max.q = 5, ic = "aic")
fc_fwd <- forecast(fit_full, h = H_fc)

last_date <- max(btc_df$date)
fc_dates  <- seq(last_date + 1, by = "day", length.out = H_fc)

fc_tbl <- data.frame(
  date     = fc_dates,
  forecast = round(exp(as.numeric(fc_fwd$mean)), 2),
  lo80     = round(exp(as.numeric(fc_fwd$lower[, "80%"])), 2),
  hi80     = round(exp(as.numeric(fc_fwd$upper[, "80%"])), 2),
  lo95     = round(exp(as.numeric(fc_fwd$lower[, "95%"])), 2),
  hi95     = round(exp(as.numeric(fc_fwd$upper[, "95%"])), 2)
)
cat("\n=== 12-day forecast (next trading days) ===\n"); print(fc_tbl)
write.csv(fc_tbl, "t3_forecast.csv", row.names = FALSE)

# ------------------------------------------------------------
# (e) Plot — last 180 days of history + 30-day held-out forecast + 12-day forward
# ------------------------------------------------------------
png("t3_forecast.png", width = 1100, height = 600)
show_n <- 180
hist_dates  <- tail(btc_df$date, show_n)
hist_prices <- tail(btc_df$BTC,  show_n)

eval_dates <- btc_df$date[test_idx]
all_dates  <- c(hist_dates, fc_dates)
y_all      <- c(hist_prices,
                exp(as.numeric(fc_fwd$upper[, "95%"])))
ylim_use   <- range(c(hist_prices, pred_p,
                      exp(as.numeric(fc_fwd$lower[, "95%"])),
                      exp(as.numeric(fc_fwd$upper[, "95%"])),
                      test_p))

plot(hist_dates, hist_prices, type = "l", lwd = 2, col = "steelblue",
     xlim = range(all_dates), ylim = ylim_use,
     xlab = "Date", ylab = "BTC price, USD",
     main = paste("BTC — ARIMA forecast (", as.character(fit_full), ")", sep = ""))
grid()

# 30-day held-out evaluation overlay
lines(eval_dates, test_p, col = "black", lwd = 2)
lines(eval_dates, pred_p, col = "purple", lwd = 2, lty = 2)

# Forward 12-day forecast with 95% band
band_x <- c(fc_dates, rev(fc_dates))
band_y <- c(exp(as.numeric(fc_fwd$lower[, "95%"])),
            rev(exp(as.numeric(fc_fwd$upper[, "95%"]))))
polygon(band_x, band_y, col = rgb(1, 0.5, 0, 0.25), border = NA)
lines(fc_dates, exp(as.numeric(fc_fwd$mean)), col = "darkorange", lwd = 2)

abline(v = last_date, lty = 3, col = "gray40")
legend("topleft", bty = "n",
       legend = c("History (BTC close)", "Held-out actual (last 30d)",
                  "ARIMA prediction on held-out", "12-day forecast", "95% PI"),
       col = c("steelblue","black","purple","darkorange",
               rgb(1, 0.5, 0, 0.4)),
       lwd = c(2,2,2,2,8), lty = c(1,1,2,1,1))
dev.off()

# Residual diagnostics
png("t3_residuals.png", width = 1000, height = 700)
checkresiduals(fit_full)
dev.off()

cat("\nPlots: t3_acf_pacf.png, t3_forecast.png, t3_residuals.png\n")
cat("CSV  : t3_forecast.csv\n")
