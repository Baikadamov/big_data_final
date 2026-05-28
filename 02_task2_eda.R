# ============================================================
# FINAL — Task 2 (6 pts): EDA & Visualization
# Inputs: crypto_clean.csv, crypto_returns.csv
# Plots : t2_prices_norm.png, t2_returns_hist.png,
#         t2_corr.png, t2_btc_vol30.png
# ============================================================

suppressPackageStartupMessages({
  library(corrplot)
})

prices  <- read.csv("crypto_clean.csv",   stringsAsFactors = FALSE)
returns <- read.csv("crypto_returns.csv", stringsAsFactors = FALSE)
prices$date  <- as.Date(prices$date)
returns$date <- as.Date(returns$date)
coins <- c("BTC","ETH","BNB","SOL","XRP","ADA")

# ------------------------------------------------------------
# (1) Descriptive statistics on daily log-returns
# ------------------------------------------------------------
desc <- function(x) {
  x <- x[!is.na(x)]
  c(n      = length(x),
    mean   = round(mean(x), 5),
    median = round(median(x), 5),
    sd     = round(sd(x), 4),
    min    = round(min(x), 4),
    max    = round(max(x), 4),
    q25    = round(quantile(x, 0.25), 4),
    q75    = round(quantile(x, 0.75), 4))
}
stats <- as.data.frame(t(sapply(returns[, coins], desc)))
cat("=== Descriptive stats — daily log-returns ===\n")
print(stats)

# annualised return / vol  (252 trading days for stocks; crypto trades 365 — use 365)
ann <- data.frame(
  coin   = coins,
  ann_ret = round(sapply(returns[, coins], function(x) mean(x, na.rm=TRUE)) * 365 * 100, 2),
  ann_vol = round(sapply(returns[, coins], function(x) sd  (x, na.rm=TRUE)) * sqrt(365) * 100, 2)
)
ann$sharpe_like <- round(ann$ann_ret / ann$ann_vol, 3)
cat("\n=== Annualised (365 days) ===\n"); print(ann)

# ------------------------------------------------------------
# (2) PRICE PLOT — normalised to 100 at first common date
# ------------------------------------------------------------
common <- prices[complete.cases(prices), ]
first_row <- common[1, coins]
norm <- as.data.frame(mapply(function(p, p0) 100 * p / p0,
                              common[, coins], first_row))
norm$date <- common$date

png("t2_prices_norm.png", width = 1000, height = 550)
op <- par(mar = c(4,4,3,1))
plot(norm$date, norm$BTC, type = "n",
     ylim = range(unlist(norm[, coins])),
     xlab = "Date", ylab = "Price (rebased to 100 at start)",
     main = "Cryptocurrencies — cumulative performance (start = 100)",
     log = "y")
grid()
cols <- c("orange","steelblue","gold3","purple","seagreen","firebrick")
for (i in seq_along(coins))
  lines(norm$date, norm[[ coins[i] ]], col = cols[i], lwd = 1.8)
legend("topleft", legend = coins, col = cols, lwd = 2, bty = "n", ncol = 3)
par(op); dev.off()

# ------------------------------------------------------------
# (3) RETURN DISTRIBUTIONS — histograms with normal overlay
# ------------------------------------------------------------
png("t2_returns_hist.png", width = 1100, height = 700)
op <- par(mfrow = c(2, 3), mar = c(4,4,3,1))
for (c in coins) {
  r <- returns[[c]]; r <- r[!is.na(r)]
  hist(r, breaks = 60, freq = FALSE, col = "lightsteelblue",
       border = "white", main = paste(c, "— daily log-returns"),
       xlab = "log-return", xlim = c(-0.3, 0.3))
  curve(dnorm(x, mean = mean(r), sd = sd(r)),
        add = TRUE, col = "red", lwd = 2)
  abline(v = 0, lty = 2, col = "gray40")
}
par(op); dev.off()

# ------------------------------------------------------------
# (4) CORRELATION MATRIX of returns
# ------------------------------------------------------------
ret_mat <- as.matrix(returns[, coins])
ret_mat <- ret_mat[complete.cases(ret_mat), ]
cor_mat <- cor(ret_mat)
cat("\n=== Return correlation matrix ===\n"); print(round(cor_mat, 3))

png("t2_corr.png", width = 700, height = 700)
corrplot(cor_mat, method = "color", type = "upper",
         addCoef.col = "black", number.cex = 1.0,
         tl.col = "black", tl.srt = 0,
         col = colorRampPalette(c("#b2182b","white","#2166ac"))(200),
         title = "Daily log-return correlations", mar = c(0,0,2,0))
dev.off()

# ------------------------------------------------------------
# (5) ROLLING 30-day VOLATILITY of BTC — shows regimes
# ------------------------------------------------------------
btc <- returns[!is.na(returns$BTC), c("date","BTC")]
roll_sd <- function(x, k) {
  out <- rep(NA_real_, length(x))
  for (i in k:length(x)) out[i] <- sd(x[(i-k+1):i])
  out
}
btc$vol30_ann <- roll_sd(btc$BTC, 30) * sqrt(365) * 100

png("t2_btc_vol30.png", width = 1000, height = 500)
plot(btc$date, btc$vol30_ann, type = "l", col = "steelblue", lwd = 1.5,
     xlab = "Date", ylab = "Annualised vol (%, 30-day window)",
     main = "BTC realised volatility — 30-day rolling, annualised")
grid()
abline(h = mean(btc$vol30_ann, na.rm = TRUE), col = "red", lty = 2)
legend("topright", lty = c(1,2), col = c("steelblue","red"),
       legend = c("rolling vol", "long-run mean"), bty = "n")
dev.off()

cat("\nPlots: t2_prices_norm.png, t2_returns_hist.png, t2_corr.png, t2_btc_vol30.png\n")
