# ============================================================
# FINAL — Task 4 (6 pts): PCA on daily log-returns of 6 cryptos
# Why PCA: returns are multivariate, strongly correlated.
# We expect PC1 to represent the common "crypto market" factor.
# Plots: t4_scree.png, t4_biplot.png, t4_pc1_time.png
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
})

returns <- read.csv("crypto_returns.csv", stringsAsFactors = FALSE)
returns$date <- as.Date(returns$date)
coins <- c("BTC","ETH","BNB","SOL","XRP","ADA")

ret <- returns[, c("date", coins)]
ret <- ret[complete.cases(ret), ]
cat("Observations used (common-date intersection):", nrow(ret), "\n")
cat("Date range:", as.character(min(ret$date)), "..",
    as.character(max(ret$date)), "\n")

# ------------------------------------------------------------
# Standardise — even though all variables are returns (same scale),
# different coins have very different vol (SOL >> BTC), so scaling avoids
# SOL dominating the first component just because it is noisier.
# ------------------------------------------------------------
X <- scale(ret[, coins])
cat("\nScaled means (~0):\n"); print(round(colMeans(X), 4))
cat("Scaled sd (~1):\n");    print(round(apply(X, 2, sd), 4))

# ------------------------------------------------------------
# PCA
# ------------------------------------------------------------
pca <- prcomp(X, center = FALSE, scale. = FALSE)   # already scaled
ev  <- pca$sdev^2
pv  <- ev / sum(ev)
cv  <- cumsum(pv)

var_tbl <- data.frame(
  PC         = paste0("PC", seq_along(ev)),
  eigenvalue = round(ev, 4),
  prop_var   = round(pv, 4),
  cum_var    = round(cv, 4)
)
cat("\n=== Variance explained ===\n"); print(var_tbl)

cat("\n=== Loadings (rotation matrix) ===\n")
print(round(pca$rotation, 3))

# ------------------------------------------------------------
# Plot 1 — scree + cumulative variance
# ------------------------------------------------------------
png("t4_scree.png", width = 900, height = 450)
op <- par(mfrow = c(1,2), mar = c(4,4,3,1))
barplot(pv, names.arg = var_tbl$PC, col = "steelblue",
        ylim = c(0, 1), main = "Scree — proportion of variance",
        ylab = "Proportion")
abline(h = 1/length(coins), col = "red", lty = 2)   # equal-share line
plot(seq_along(cv), cv, type = "b", pch = 19, col = "darkorange",
     ylim = c(0,1), xlab = "Number of components", ylab = "Cum. variance",
     main = "Cumulative variance explained")
abline(h = 0.80, col = "red", lty = 2)
grid()
par(op); dev.off()

# ------------------------------------------------------------
# Plot 2 — PC1 vs PC2 scatter (observations) with loading arrows (biplot)
# ------------------------------------------------------------
png("t4_biplot.png", width = 800, height = 700)
biplot(pca, scale = 0, cex = c(0.4, 1.0),
       col = c("gray70","red"),
       xlab = sprintf("PC1 (%.1f%%)", 100 * pv[1]),
       ylab = sprintf("PC2 (%.1f%%)", 100 * pv[2]),
       main = "PCA biplot — crypto daily returns")
abline(h = 0, v = 0, lty = 2, col = "gray40")
dev.off()

# ------------------------------------------------------------
# Plot 3 — PC1 score over time = "synthetic crypto market index"
# ------------------------------------------------------------
scores <- as.data.frame(pca$x)
scores$date <- ret$date

# cumulative PC1 = a synthetic market index
scores$PC1_cum <- cumsum(scores$PC1)
scores$PC2_cum <- cumsum(scores$PC2)

png("t4_pc1_time.png", width = 1000, height = 600)
op <- par(mfrow = c(2,1), mar = c(4,4,3,1))
plot(scores$date, scores$PC1, type = "l", col = "steelblue",
     xlab = "Date", ylab = "PC1 daily score",
     main = sprintf("PC1 daily score over time (%.1f%% of variance)", 100*pv[1]))
abline(h = 0, lty = 2, col = "gray40"); grid()

plot(scores$date, scores$PC1_cum, type = "l", col = "darkorange", lwd = 2,
     xlab = "Date", ylab = "Cumulative PC1",
     main = "Cumulative PC1 — interpretation: 'crypto market' index")
grid()
par(op); dev.off()

# ------------------------------------------------------------
# Interpretation helper
# ------------------------------------------------------------
cat("\n=== Quick interpretation ===\n")
cat("PC1 loadings (sign and magnitude):\n")
print(round(pca$rotation[, 1], 3))
cat("\nAll PC1 loadings have the same sign and similar magnitude => PC1 is\n",
    "the COMMON CRYPTO-MARKET FACTOR (everything moves together).\n")
cat("\nPC2 loadings (sign matters — contrasts coins):\n")
print(round(pca$rotation[, 2], 3))

# Save
write.csv(var_tbl,                "t4_variance.csv", row.names = FALSE)
write.csv(round(pca$rotation, 4), "t4_loadings.csv", row.names = TRUE)

cat("\nPlots: t4_scree.png, t4_biplot.png, t4_pc1_time.png\n")
cat("CSV  : t4_variance.csv, t4_loadings.csv\n")
