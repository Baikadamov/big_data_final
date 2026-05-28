# ============================================================
# FINAL — Task 1 (6 pts): Data Loading and Cleaning
# Input : crypto_raw.csv
# Output: crypto_clean.csv (wide, one row per date, columns = close per coin)
# Plots : t1_missing.png, t1_outliers_box.png
# ============================================================

suppressPackageStartupMessages({
  library(xts)
})

raw <- read.csv("crypto_raw.csv", stringsAsFactors = FALSE)
raw$date <- as.Date(raw$date)
cat("=== RAW ===\n"); print(dim(raw)); print(head(raw, 3))

# ------------------------------------------------------------
# 1. Pivot to wide: rows = date, cols = ticker close
# ------------------------------------------------------------
coins  <- sort(unique(raw$ticker))
wide   <- reshape(raw[, c("date","ticker","close")],
                  idvar = "date", timevar = "ticker", direction = "wide")
colnames(wide) <- sub("close\\.","", colnames(wide))
wide <- wide[order(wide$date), ]
rownames(wide) <- NULL

cat("\n=== WIDE (head) ===\n"); print(head(wide, 3))
cat("Dim:", dim(wide), "\n")

# ------------------------------------------------------------
# 2. Missing values
# ------------------------------------------------------------
na_per_col <- sapply(wide[, coins], function(x) sum(is.na(x)))
cat("\n=== Missing values per coin ===\n"); print(na_per_col)

# Visualise where NAs are (SOL started later -> NA at the top)
png("t1_missing.png", width = 900, height = 500)
op <- par(mar = c(4,4,3,1))
plot(wide$date, rep(1, nrow(wide)), type = "n",
     ylim = c(0.5, length(coins) + 0.5), yaxt = "n",
     xlab = "Date", ylab = "",
     main = "Data availability per coin (red = missing)")
axis(2, at = seq_along(coins), labels = coins, las = 1)
for (i in seq_along(coins)) {
  na_mask <- is.na(wide[[ coins[i] ]])
  points(wide$date[!na_mask], rep(i, sum(!na_mask)), pch = 15, col = "steelblue", cex = 0.3)
  points(wide$date[ na_mask], rep(i, sum( na_mask)), pch = 15, col = "red",       cex = 0.5)
}
par(op); dev.off()

# Treatment:
# - SOL has leading NAs (listed Apr-2020) -> we keep the full series and accept it
#   for plots; for modelling we use the common-date intersection.
# - Any sporadic mid-series NA (rare) -> forward-fill with previous close, which is
#   the standard treatment for daily prices (a non-trading gap should not be
#   imputed with mean/median because that destroys the time structure).
for (c in coins) {
  v <- wide[[c]]
  na_idx <- which(is.na(v))
  if (length(na_idx) > 0) {
    # leading NAs stay NA; only fill internal ones
    first_obs <- which(!is.na(v))[1]
    for (k in na_idx) if (k > first_obs) v[k] <- v[k-1]
    wide[[c]] <- v
  }
}
cat("After forward-fill (internal NAs only):\n")
print(sapply(wide[, coins], function(x) sum(is.na(x))))

# ------------------------------------------------------------
# 3. Outliers — based on log-returns (price level itself trends, so its "outliers"
#    are just rallies, not anomalies). Returns should be ~stationary, so IQR is
#    meaningful here.
# ------------------------------------------------------------
returns <- as.data.frame(lapply(wide[, coins], function(p) c(NA, diff(log(p)))))
returns$date <- wide$date
returns <- returns[, c("date", coins)]

iqr_summary <- data.frame(coin = coins,
                          n = NA_integer_,
                          n_outlier = NA_integer_,
                          pct_outlier = NA_real_,
                          lower_fence = NA_real_,
                          upper_fence = NA_real_)
for (i in seq_along(coins)) {
  r  <- returns[[ coins[i] ]]
  r  <- r[!is.na(r)]
  q1 <- quantile(r, 0.25); q3 <- quantile(r, 0.75); iqr <- q3 - q1
  lo <- q1 - 1.5 * iqr;    hi <- q3 + 1.5 * iqr
  out <- sum(r < lo | r > hi)
  iqr_summary[i, ] <- list(coins[i], length(r), out, round(100 * out / length(r), 2),
                           round(lo, 4), round(hi, 4))
}
cat("\n=== Outlier summary (IQR on log-returns) ===\n"); print(iqr_summary)

png("t1_outliers_box.png", width = 900, height = 500)
boxplot(returns[, coins], main = "Daily log-returns — boxplot per coin",
        ylab = "log-return", col = "lightsteelblue", outcol = "red")
abline(h = 0, lty = 2, col = "gray40")
dev.off()

# We KEEP the outliers (do not winsorise/drop) — extreme daily moves in crypto are
# real market events (e.g. May-2021, FTX-Nov-2022, Mar-2020 COVID). Dropping them
# would bias volatility downward and hide tail risk. Cleaning here = "flag, not remove".

# ------------------------------------------------------------
# 4. Save clean dataset (full + common-date sub-sample for modelling)
# ------------------------------------------------------------
write.csv(wide,    "crypto_clean.csv",         row.names = FALSE)
write.csv(returns, "crypto_returns.csv",       row.names = FALSE)

common <- wide[complete.cases(wide), ]
write.csv(common,  "crypto_clean_common.csv",  row.names = FALSE)
cat("\nFull rows (with NA tail of SOL):", nrow(wide),
    " | Common-date rows:", nrow(common), "\n")

cat("\nSaved: crypto_clean.csv, crypto_returns.csv, crypto_clean_common.csv\n")
cat("Plots: t1_missing.png, t1_outliers_box.png\n")
