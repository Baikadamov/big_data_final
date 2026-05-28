# ============================================================
# FINAL — Task 5 (8 pts): Classification — predict next-day BTC direction
# Target  : sign of tomorrow's log-return  (UP = 1, DOWN = 0)
# Features: lag returns, rolling vol, RSI, MACD, ETH/BNB cross-signals
# Models  : Logistic Regression vs Random Forest  (champion + baseline)
# Split   : chronological 80/20 (no look-ahead!)
# Metrics : accuracy, ROC-AUC, confusion matrix
# Plots   : t5_roc.png, t5_importance.png, t5_confusion.png
# ============================================================

suppressPackageStartupMessages({
  library(randomForest)
  library(pROC)
  library(TTR)
})

prices <- read.csv("crypto_clean.csv", stringsAsFactors = FALSE)
prices$date <- as.Date(prices$date)
prices <- prices[order(prices$date), ]

# Restrict to common dates (SOL drives the start)
prices <- prices[complete.cases(prices), ]
cat("Rows after common-date filter:", nrow(prices), "\n")

# ------------------------------------------------------------
# Feature engineering — all features use info AVAILABLE AT t,
# target is direction of t+1 -> no look-ahead leakage
# ------------------------------------------------------------
btc <- prices$BTC
n   <- length(btc)

ret_btc <- c(NA, diff(log(btc)))
ret_eth <- c(NA, diff(log(prices$ETH)))
ret_bnb <- c(NA, diff(log(prices$BNB)))

# Lags
lag1  <- c(NA, ret_btc[-n])
lag2  <- c(NA, NA, ret_btc[-c(n-1, n)])
lag3  <- c(NA, NA, NA, ret_btc[-c(n-2, n-1, n)])
lag5  <- c(rep(NA, 5), ret_btc[1:(n-5)])

# Rolling features at time t (use only past data)
roll_mean <- function(x, k) {
  out <- rep(NA_real_, length(x))
  for (i in k:length(x)) out[i] <- mean(x[(i-k+1):i], na.rm = TRUE)
  out
}
roll_sd <- function(x, k) {
  out <- rep(NA_real_, length(x))
  for (i in k:length(x)) out[i] <- sd(x[(i-k+1):i], na.rm = TRUE)
  out
}
mom5  <- roll_mean(ret_btc, 5)
mom10 <- roll_mean(ret_btc, 10)
vol10 <- roll_sd  (ret_btc, 10)
vol30 <- roll_sd  (ret_btc, 30)

# Technical indicators (TTR uses price, not return)
rsi14 <- as.numeric(RSI (btc, n = 14))
macd  <- MACD(btc, nFast = 12, nSlow = 26, nSig = 9)
macd_v   <- as.numeric(macd[, "macd"])
macd_sig <- as.numeric(macd[, "signal"])
macd_hist <- macd_v - macd_sig

# Cross-asset signals
eth_lag <- c(NA, ret_eth[-n])
bnb_lag <- c(NA, ret_bnb[-n])

# Target: sign of next-day return
target_ret  <- c(ret_btc[-1], NA)
target_dir  <- ifelse(target_ret > 0, 1L, 0L)

df <- data.frame(
  date   = prices$date,
  lag1, lag2, lag3, lag5,
  mom5, mom10, vol10, vol30,
  rsi14, macd_v, macd_sig, macd_hist,
  eth_lag, bnb_lag,
  target = target_dir
)
df <- df[complete.cases(df), ]
cat("Rows after feature engineering:", nrow(df), "\n")
cat("Class balance:\n"); print(prop.table(table(df$target)))

# ------------------------------------------------------------
# Chronological split — 80% train, 20% test (NO shuffling!)
# ------------------------------------------------------------
split_idx <- floor(0.80 * nrow(df))
train <- df[1:split_idx, ]
test  <- df[(split_idx + 1):nrow(df), ]
cat("\nTrain:", nrow(train), "(", as.character(train$date[1]), "->",
    as.character(train$date[nrow(train)]), ")\n")
cat( "Test :", nrow(test),  "(", as.character(test$date[1]), "->",
    as.character(test$date[nrow(test)]),  ")\n")

predictors <- setdiff(colnames(df), c("date","target"))

# ------------------------------------------------------------
# Model A — Logistic regression
# ------------------------------------------------------------
fit_lr <- glm(target ~ ., data = train[, c(predictors, "target")],
              family = binomial())
cat("\n=== Logistic regression — significant coefficients ===\n")
print(round(coef(summary(fit_lr)), 4))

p_lr <- predict(fit_lr, newdata = test[, predictors], type = "response")
yhat_lr <- as.integer(p_lr > 0.5)
acc_lr  <- mean(yhat_lr == test$target)
auc_lr  <- as.numeric(auc(roc(test$target, p_lr, quiet = TRUE)))

# ------------------------------------------------------------
# Model B — Random forest (champion)
# Hyperparameter: try mtry in {2,3,4,5}, pick best by OOB accuracy
# ------------------------------------------------------------
set.seed(42)
oob_grid <- sapply(c(2,3,4,5), function(m) {
  rf <- randomForest(x = train[, predictors],
                     y = factor(train$target),
                     ntree = 500, mtry = m)
  1 - rf$err.rate[500, "OOB"]
})
names(oob_grid) <- c(2,3,4,5)
cat("\nOOB accuracy by mtry:\n"); print(round(oob_grid, 4))
best_mtry <- as.integer(names(oob_grid)[which.max(oob_grid)])
cat("Best mtry:", best_mtry, "\n")

set.seed(42)
fit_rf <- randomForest(x = train[, predictors],
                       y = factor(train$target),
                       ntree = 800, mtry = best_mtry,
                       importance = TRUE)
p_rf  <- predict(fit_rf, newdata = test[, predictors], type = "prob")[, "1"]
yhat_rf <- as.integer(p_rf > 0.5)
acc_rf  <- mean(yhat_rf == test$target)
auc_rf  <- as.numeric(auc(roc(test$target, p_rf, quiet = TRUE)))

# ------------------------------------------------------------
# Baseline — always predict UP (majority class)
# ------------------------------------------------------------
acc_naive <- mean(1 == test$target)

cat(sprintf("\n=== Results on hold-out test ===\n"))
cat(sprintf("Naive 'always up' : accuracy = %.4f\n", acc_naive))
cat(sprintf("Logistic regr.   : accuracy = %.4f   AUC = %.4f\n", acc_lr, auc_lr))
cat(sprintf("Random forest    : accuracy = %.4f   AUC = %.4f\n", acc_rf, auc_rf))

# ------------------------------------------------------------
# Confusion matrices
# ------------------------------------------------------------
cat("\n=== Confusion (Logistic) ===\n")
print(table(actual = test$target, pred = yhat_lr))
cat("\n=== Confusion (Random forest) ===\n")
print(table(actual = test$target, pred = yhat_rf))

# ------------------------------------------------------------
# Plots
# ------------------------------------------------------------
png("t5_roc.png", width = 700, height = 600)
roc_lr <- roc(test$target, p_lr, quiet = TRUE)
roc_rf <- roc(test$target, p_rf, quiet = TRUE)
plot(roc_lr, col = "steelblue", lwd = 2,
     main = "ROC — next-day BTC direction")
lines(roc_rf, col = "darkorange", lwd = 2)
abline(0, 1, lty = 2, col = "gray40")
legend("bottomright", bty = "n",
       legend = c(sprintf("Logistic   AUC = %.3f", auc_lr),
                  sprintf("Random forest AUC = %.3f", auc_rf),
                  "random"),
       col = c("steelblue","darkorange","gray40"), lwd = c(2,2,1), lty = c(1,1,2))
dev.off()

png("t5_importance.png", width = 800, height = 500)
imp <- importance(fit_rf)[, "MeanDecreaseGini"]
imp <- sort(imp, decreasing = TRUE)
op <- par(mar = c(4, 8, 3, 1))
barplot(rev(imp), horiz = TRUE, las = 1, col = "steelblue",
        main = "Random forest — variable importance (MeanDecreaseGini)",
        xlab = "Importance")
par(op); dev.off()

png("t5_confusion.png", width = 900, height = 400)
op <- par(mfrow = c(1,2), mar = c(4,4,3,1))
cm_lr <- table(actual = test$target, pred = yhat_lr)
cm_rf <- table(actual = test$target, pred = yhat_rf)
plot_cm <- function(cm, title) {
  image(t(as.matrix(cm))[, 2:1], axes = FALSE, col = colorRampPalette(c("white","steelblue"))(20),
        main = title)
  axis(1, at = c(0, 1), labels = c("Pred 0", "Pred 1"))
  axis(2, at = c(0, 1), labels = c("Actual 1", "Actual 0"), las = 1)
  for (i in 1:2) for (j in 1:2) {
    text((j - 1), (2 - i), cm[i, j], cex = 1.6, font = 2)
  }
}
plot_cm(cm_lr, "Logistic")
plot_cm(cm_rf, "Random forest")
par(op); dev.off()

# Save metrics + forecast log
metrics <- data.frame(
  model   = c("naive_up","logistic","random_forest"),
  accuracy = round(c(acc_naive, acc_lr, acc_rf), 4),
  auc      = round(c(NA, auc_lr, auc_rf), 4)
)
write.csv(metrics, "t5_metrics.csv", row.names = FALSE)
cat("\nSaved: t5_metrics.csv, t5_roc.png, t5_importance.png, t5_confusion.png\n")
