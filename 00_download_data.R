# ============================================================
# FINAL — Step 0: download crypto data from Yahoo Finance
# Tickers: BTC, ETH, BNB, SOL, XRP, ADA  (vs USD)
# Period : 2020-01-01 .. 2026-05-27
# Output : crypto_raw.csv  (long format: date, ticker, open, high, low, close, volume)
# ============================================================

suppressPackageStartupMessages({
  library(quantmod)
  library(xts)
})

tickers <- c("BTC-USD","ETH-USD","BNB-USD","SOL-USD","XRP-USD","ADA-USD")
from_d  <- as.Date("2020-01-01")
to_d    <- as.Date("2026-05-27")

raw_list <- list()
for (tk in tickers) {
  cat("Downloading", tk, "...\n")
  obj <- tryCatch(
    getSymbols(tk, src = "yahoo", from = from_d, to = to_d, auto.assign = FALSE),
    error = function(e) { cat("  FAIL:", conditionMessage(e), "\n"); NULL }
  )
  if (is.null(obj)) next
  df <- data.frame(date = index(obj), coredata(obj))
  colnames(df) <- c("date","open","high","low","close","volume","adjusted")
  df$ticker <- sub("-USD","", tk)
  raw_list[[tk]] <- df
}

raw <- do.call(rbind, raw_list)
rownames(raw) <- NULL
raw <- raw[, c("date","ticker","open","high","low","close","volume","adjusted")]

cat("\nTotal rows:", nrow(raw), "\n")
cat("Per ticker:\n"); print(table(raw$ticker))
cat("Date range:", as.character(min(raw$date)), "..", as.character(max(raw$date)), "\n")

write.csv(raw, "crypto_raw.csv", row.names = FALSE)
cat("\nSaved -> crypto_raw.csv\n")
