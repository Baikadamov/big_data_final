# Final Exam — Comprehensive Analysis of Real Financial Data

**Student:** Baikadamov
**Date:** 2026-05-28
**Topic:** Cryptocurrency basket (BTC, ETH, BNB, SOL, XRP, ADA)
**Tools:** R 4.3.3 — `quantmod`, `forecast`, `tseries`, `randomForest`, `pROC`, `TTR`, `corrplot`

---

## Introduction — dataset & objective

**Dataset.** Daily OHLCV quotes for the six largest cryptocurrencies by market cap:
**BTC, ETH, BNB, SOL, XRP, ADA** (vs USD), period **2020-01-01 → 2026-05-27**. Source: Yahoo Finance via `quantmod::getSymbols`. **13,934** rows in raw long format; after pivoting to wide — **2,339** daily observations (SOL starts in April 2020).

**Business objective.** Assess the structure of the crypto market and the predictability of BTC price:

1. understand risk/return characteristics of each coin;
2. build an ARIMA forecast of BTC price for the next 12 days;
3. use PCA to extract the common market factor and sector-specific factors;
4. test whether daily BTC direction can be predicted from technical + cross-asset features (a weak-form efficiency test).

---

## Task 1. Data Loading and Cleaning (6 points)

### 1.1 Import and pivot

Script `00_download_data.R` pulls 6 tickers from Yahoo Finance; `01_task1_cleaning.R` pivots to wide format (one row per date, six close columns) and saves `crypto_clean.csv`.

### 1.2 Missing values

| Coin | NA in close | Reason |
|------|-------------|--------|
| BTC, ETH, BNB, XRP, ADA | 0 | trades 24/7 from 2020-01-01 |
| **SOL** | **100** | exchange listing only **2020-04-11** — all NAs are leading |

**Treatment:**
- **Leading NAs for SOL** are kept as `NA` — this is not a missing value but absence of the asset before listing. Mean imputation would inject a fake "return" on the listing day.
- **Internal NAs (if any)** are forward-filled (`x[t] = x[t-1]`) — the standard treatment for daily prices; mean/median would destroy the temporal structure.
- For modelling (PCA, classification) we use the **common-date intersection** — `crypto_clean_common.csv`, **2,239 rows**.

### 1.3 Outliers

Outliers are detected on **log-returns**, not on prices: the price level trends, so its "outliers" are just rallies, not anomalies. Returns should be approximately stationary, so the IQR rule is meaningful here.

| Coin | n | Outliers | % outliers | Lower fence | Upper fence |
|------|---|----------|------------|-------------|-------------|
| BTC  | 2338 | 169 | 7.2 % | −5.5 % | +5.7 % |
| ETH  | 2338 | 151 | 6.5 % | −7.7 % | +8.0 % |
| BNB  | 2338 | 190 | 8.1 % | −6.5 % | +6.9 % |
| SOL  | 2238 | 114 | 5.1 % | −12.4 % | +12.5 % |
| XRP  | 2338 | 182 | 7.8 % | −7.8 % | +7.8 % |
| ADA  | 2338 | 146 | 6.2 % | −9.7 % | +9.5 % |

**Decision — outliers are NOT removed.** Extreme daily moves in crypto are real market events (COVID crash March 2020, LUNA/UST May 2022, FTX November 2022). Removing them would understate volatility and hide tail risk (VaR, CVaR). The goal of cleaning here is **to flag outliers, not delete them**.

**Plots:** `t1_missing.png` (missing-value heatmap by date/coin), `t1_outliers_box.png` (return boxplot).

---

## Task 2. EDA & Visualization (6 points)

### 2.1 Descriptive statistics — daily log-returns

| Coin | mean | median | sd | min | max | Q1 | Q3 |
|------|------|--------|----|-----|-----|----|----|
| BTC | 0.10 % | 0.04 % | 3.20 % | −46.5 % | 17.2 % | −1.3 % | 1.5 % |
| ETH | 0.12 % | 0.10 % | 4.28 % | −55.1 % | 23.1 % | −1.8 % | 2.1 % |
| BNB | 0.17 % | 0.14 % | 4.31 % | −54.3 % | 52.9 % | −1.5 % | 1.8 % |
| SOL | 0.20 % | −0.04 % | 6.25 % | −55.0 % | 38.7 % | −3.0 % | 3.2 % |
| XRP | 0.08 % | −0.00 % | 5.25 % | −55.1 % | 54.9 % | −2.0 % | 1.9 % |
| ADA | 0.08 % | −0.04 % | 5.13 % | −50.4 % | 53.8 % | −2.5 % | 2.3 % |

### 2.2 Annualised (365 trading days, crypto trades 24/7)

| Coin | Ann. return | Ann. vol | Return / Vol |
|------|-------------|----------|--------------|
| BTC | 36.45 % | 61.23 % | **0.595** |
| ETH | 42.75 % | 81.85 % | 0.522 |
| **BNB** | **60.22 %** | 82.36 % | **0.731** |
| SOL | 72.76 % | 119.44 % | 0.609 |
| XRP | 29.88 % | 100.29 % | 0.298 |
| ADA | 30.57 % | 98.08 % | 0.312 |

**Insights:**
- **BNB** has the best return-to-risk ratio (0.73), better than BTC. SOL has higher return but almost double the vol.
- **XRP / ADA — worst**: high vol with mediocre return. The two weakest assets in the basket.
- **BTC = "conservative" crypto** — lowest vol with reasonable return.

### 2.3 Return correlation matrix

|       | BTC | ETH | BNB | SOL | XRP | ADA |
|-------|-----|-----|-----|-----|-----|-----|
| BTC | 1.00 | **0.81** | 0.66 | 0.56 | 0.58 | 0.67 |
| ETH | 0.81 | 1.00 | 0.68 | 0.63 | 0.61 | 0.72 |
| BNB | 0.66 | 0.68 | 1.00 | 0.55 | 0.53 | 0.59 |
| SOL | 0.56 | 0.63 | 0.55 | 1.00 | 0.49 | 0.57 |
| XRP | 0.58 | 0.61 | 0.53 | 0.49 | 1.00 | 0.63 |
| ADA | 0.67 | 0.72 | 0.59 | 0.57 | 0.63 | 1.00 |

All pairwise correlations are positive in the range **0.49 – 0.81**. **BTC–ETH = 0.81** — the two coins move almost as one. Most independent pair: SOL–XRP (0.49). The takeaway for diversification: a pure crypto basket offers **weak** diversification — all coins fall and rise together.

### 2.4 Visualizations (4, exceeding the required 3)

| File | What it shows |
|------|---------------|
| `t2_prices_norm.png` | **Time series**: prices rebased to 100 at the common start, log scale. Shows the late-2021 bubble, the 2022 "crypto winter", and 2023-2024 recovery. |
| `t2_returns_hist.png` | **Histograms** of daily log-returns for all 6 coins with normal density overlay (red). Visible **fat tails** — normality clearly rejected. |
| `t2_corr.png` | **Correlation plot** of returns. Blue dominates (positive correlations). |
| `t2_btc_vol30.png` | **Rolling 30-day annualised volatility** of BTC. Spikes: COVID (March 2020 ~140 %), LUNA crash (May 2022 ~90 %), FTX (Nov 2022). Long-run mean ~60 %. |

---

## Task 3. Time Series Analysis & ARIMA (8 points)

Goal — build an ARIMA forecast of **BTC price** for the next 12 days.

### 3.1 Stationarity test

The model is fit on **log-price** (`log(BTC)`) — this stabilises the variance (on raw price, spread grows with the level).

**ADF test:**

| Series | Statistic | p-value | Conclusion |
|--------|-----------|---------|-----------|
| `log(BTC)` (level) | −1.804 | 0.661 | **NOT stationary** (trend present) |
| `diff(log(BTC))` = log-return | −12.023 | < 0.01 | **Stationary** |

`forecast::ndiffs(log(BTC))` → **d = 1**. One differencing is enough.

### 3.2 ACF / PACF

See `t3_acf_pacf.png`:

- ACF of log-price — slow exponential decay → classic non-stationary pattern.
- ACF of log-returns — almost all lags inside the confidence band → "white noise", with small significance at lags 1-3.
- PACF of returns — sharp cut after the first lags → hint for AR terms.

### 3.3 Model selection

`auto.arima(log_btc, seasonal=FALSE, stepwise=FALSE, approximation=FALSE)` selected:

$$\boxed{\text{ARIMA}(0, 1, 4) \text{ with drift}}$$

| Parameter | Estimate | Std. error |
|---|---|---|
| `ma1` | −0.0578 | 0.0208 |
| `ma2` |  0.0399 | 0.0208 |
| `ma3` | −0.0136 | 0.0205 |
| `ma4` |  0.0601 | 0.0215 |
| `drift` | 0.0010 | 0.0007 |

**In-sample quality:** AIC = −9316.08, BIC = −9281.62, σ² = 0.00103.
**Residual diagnostics** (`t3_residuals.png`): Ljung-Box Q* = 10.14 (df = 6), **p = 0.119 > 0.05** → residuals are indistinguishable from white noise, the model is adequate.

### 3.4 Forecast and accuracy

Validation strategy: split train = 2309 obs, test = last 30 days. Forecast 30 days ahead and compare with actual.

| Metric (USD) | ARIMA | Naive (last value) |
|---|---|---|
| RMSE | 2,425.29 | 2,293.96 |
| MAE  | 2,133.15 | 1,835.08 |
| MAPE | **2.73 %** | — |

ARIMA is **slightly worse** than the naive "price unchanged" forecast — a typical result for an efficient market (the random walk in daily price is extremely hard to beat). Nevertheless, **MAPE 2.73 %** means the forecast deviates from actual by less than 3 % on average — quite practical.

### 3.5 Final 12-day forecast (from 2026-05-28)

| Date | Forecast, USD | 80 % PI | 95 % PI |
|------|--------------:|--------|---------|
| 2026-05-28 | 74,480 | 71,493 — 77,592 | 69,960 — 79,291 |
| 2026-05-29 | 74,516 | 70,440 — 78,828 | 68,374 — 81,210 |
| 2026-05-30 | 74,532 | 69,553 — 79,867 | 67,054 — 82,844 |
| 2026-05-31 | 74,504 | 68,797 — 80,684 | 65,956 — 84,160 |
| 2026-06-01 | 74,578 | 68,151 — 81,612 | 64,976 — 85,600 |
| 2026-06-02 | 74,653 | 67,584 — 82,461 | 64,117 — 86,920 |
| 2026-06-03 | 74,727 | 67,076 — 83,252 | 63,347 — 88,152 |
| 2026-06-04 | 74,802 | 66,613 — 83,998 | 62,647 — 89,315 |
| 2026-06-05 | 74,877 | 66,187 — 84,707 | 62,003 — 90,423 |
| 2026-06-06 | 74,952 | 65,792 — 85,387 | 61,405 — 91,486 |
| 2026-06-07 | 75,027 | 65,422 — 86,041 | 60,846 — 92,512 |
| 2026-06-08 | 75,101 | 65,075 — 86,673 | 60,320 — 93,504 |

**Interpretation:** the central forecast is almost flat (~$74,500 — $75,100), with very weak positive drift (~+$60/day — the `drift` parameter). The 95 % prediction interval widens from ±$5,000 to ±$16,500 by day 12 — this is **the model honestly admitting limited predictability of price**. Plot: `t3_forecast.png`.

---

## Task 4. PCA on returns of 6 cryptocurrencies (6 points)

**PCA was chosen** (over clustering) because the goal is to understand the **structure of joint asset movements**, a classic portfolio-analysis use case. Clustering would answer "which coins are similar"; PCA answers "how many independent factors drive the market".

### 4.1 Preparation

- Daily log-returns of 6 coins are computed on the common-date intersection (**2,238 days**, from 2020-04-11).
- All features are **standardised** (z-score). Even though units are identical (returns), volatility differs by 2× (SOL ~6 % vs BTC ~3 %); without standardisation, SOL would dominate PC1 just because of its higher variance.

### 4.2 Variance explained (eigenvalues)

| Component | Eigenvalue | Prop. var | Cum. var |
|-----------|-----------|-----------|---------|
| **PC1** | 4.11 | **68.5 %** | 68.5 % |
| PC2 | 0.53 | 8.8 % | 77.3 % |
| PC3 | 0.48 | 8.0 % | 85.3 % |
| PC4 | 0.38 | 6.4 % | 91.7 % |
| PC5 | 0.32 | 5.3 % | 97.0 % |
| PC6 | 0.18 | 3.0 % | 100 % |

The first component explains **68.5 %** of total variance — a huge share.

### 4.3 Loadings (how coins compose the components)

|     | PC1 | PC2 | PC3 |
|-----|-----|-----|-----|
| BTC | 0.429 | 0.032 | 0.388 |
| ETH | 0.447 | 0.076 | 0.205 |
| BNB | 0.399 | **0.266** | 0.430 |
| SOL | 0.374 | **0.588** | −0.703 |
| XRP | 0.379 | **−0.720** | −0.349 |
| ADA | 0.418 | −0.243 | −0.082 |

### 4.4 Financial interpretation

**PC1 = "crypto market factor" (CRYPTO BETA).**
All six loadings are positive and roughly equal in magnitude (0.37 — 0.45). This means the **first principal component is just the "common crypto-market movement"**: when the market rises, all 6 coins rise proportionally. Analogous to the "S&P 500 factor" in equities.

Practical implication: **diversification inside crypto is largely illusory** — 68.5 % of all variation is explained by one common factor.

**PC2 = "alt-sector vs XRP" (~9 %).**
PC2 contrasts **SOL (+0.59) + BNB (+0.27)** against **XRP (−0.72) + ADA (−0.24)**. This looks like a contrast between "new smart-contract platforms" and "legacy payment coins". When investors rotate out of older utility coins (XRP, ADA) into newer L1 chains (SOL, BNB), PC2 moves up.

**PC3 = "BTC/BNB vs SOL" (~8 %)** — less interpretable, more idiosyncratic.

**Plots:** `t4_scree.png`, `t4_biplot.png`, `t4_pc1_time.png`.

---

## Task 5. Predictive Modeling — BTC direction classification (8 points)

**Task:** predict the **sign** of tomorrow's BTC log-return (1 = UP, 0 = DOWN) using technical and cross-asset features available **at time t**.

### 5.1 Features (14 total)

| Group | Features |
|-------|----------|
| BTC return lags | `lag1, lag2, lag3, lag5` |
| Momentum | `mom5` (rolling-mean return 5 days), `mom10` |
| Volatility | `vol10`, `vol30` (rolling sd) |
| Technical indicators | `rsi14` (RSI 14), `macd_v`, `macd_sig`, `macd_hist` |
| Cross-asset | `eth_lag`, `bnb_lag` (yesterday's ETH, BNB returns) |

**Protection against look-ahead leakage:** all features are computed using data **up to and including time t**, while the target is the direction at **t + 1**.

### 5.2 Split

**Chronological 80/20 (NOT shuffled — mandatory for time series!):**
- Train: 1,764 days (2020-05-13 → 2025-03-11)
- Test:  441 days (2025-03-12 → 2026-05-26)

Class balance in the test set: **DOWN 49.9 %, UP 50.1 %** — almost perfectly balanced.

### 5.3 Model comparison

| Model | Accuracy | ROC-AUC |
|-------|---------:|--------:|
| **Naive (always UP)** | 50.11 % | — |
| Logistic regression | 47.39 % | 0.537 |
| **Random forest** (mtry=3, 800 trees) | 46.03 % | **0.564** |

The `mtry` hyperparameter was selected via OOB-accuracy on train: {2, 3, 4, 5} → best = **3** (51.6 %).

### 5.4 Confusion matrix (Random forest)

|        | Pred 0 | Pred 1 |
|--------|--------|--------|
| Actual 0 (DOWN) | 99 | 121 |
| Actual 1 (UP)   | 117 | **104** |

### 5.5 Variable importance

Top 3 by MeanDecreaseGini: **`rsi14`, `vol30`, `macd_v`**. Return lags are less informative than technical indicators and volatility measures.

### 5.6 **Interpretation (this IS the financial answer)**

- **AUC = 0.564 > 0.5** → the model contains a **weak but statistically real signal** about price direction.
- **Accuracy 46 % < naive 50 %** → that signal is not strong enough to beat the simple "always UP" rule. At threshold 0.5 the model is wrong more often than right.
- **This is the classic "weak-form efficient market" result**: daily BTC direction is **largely unpredictable** from lags and technical indicators. If predictability were strong, arbitrageurs would have already eaten it.
- **Practical implication:** a trading strategy based on these features will not be profitable after spread and fees. Random forest is useful **not for trading**, but for **risk management** — the model is slightly better at distinguishing calm vs volatile periods (note the importance of `vol30`).

**Plots:** `t5_roc.png`, `t5_importance.png`, `t5_confusion.png`.

---

## Task 6. Final Interpretation and Financial Conclusions (6 points)

### 6.1 What the data tells us about the crypto market

1. **High volatility and fat tails.** Annualised vol of 60 – 120 % (vs S&P 500's ~16 %). Daily moves of ±50 % during crises (LUNA, FTX, COVID) — these are normal, not anomalies.
2. **Strong internal correlation.** All six coins have daily return correlations of 0.49 – 0.81. PCA confirms it: 68.5 % of total variance is **a single market factor**.
3. **Risk/return leaders (2020-2026):** BNB (Sharpe-like 0.73) > SOL (0.61) ≈ BTC (0.60). **Laggards:** XRP, ADA — high vol with no compensating return.
4. **Weak directional predictability.** ML model AUC of 0.56 — **a weak signal exists**, but it is not enough to make a profitable trading strategy after transaction costs. **The market is close to weak-form efficient.**

### 6.2 Which factors influence BTC price most

By Random Forest variable importance (next-day direction):

1. **RSI(14)** — overbought/oversold indicator.
2. **30-day volatility** — regime shifts ("high vol → reversal").
3. **MACD** — trend indicator.
4. BTC return lags matter less — autocorrelation in daily returns is essentially zero (consistent with the ADF and ACF on returns from Task 3).

### 6.3 Reliability of the models

| Model | Reliability | Comment |
|-------|-------------|---------|
| ARIMA(0,1,4) on BTC | MAPE 2.73 %, residuals = white noise | Suitable for short-term 1-5 day forecasts; wide PI at day 12. Does not beat naive in point accuracy — typical for a random walk. |
| PCA | PC1 share 68.5 % is stable | Market structure is stable; recommend re-estimating loadings every 6 months. |
| Random forest (classification) | AUC 0.564 — weak signal | Not for trading. For risk management — useful (the model picks up volatility regimes). |

### 6.4 Recommendations

**For a portfolio investor:**
1. **Don't confuse "many coins" with "diversification"**. 6 cryptos = ~1 asset in risk terms (PC1 = 68.5 %). Real diversification requires moving into **other asset classes** (equities, gold, bonds).
2. **BNB and BTC** — best core-holding by risk/return ratio. SOL — for aggressive risk appetite.
3. **Avoid concentration in XRP and ADA** — asymmetrically poor risk-return profile over the past 6 years.

**For a trader:**
1. **Do not try to predict daily BTC direction** from pure technical features — the naive "always UP" strategy beats ML on accuracy. To build a trading system, **alternative data** is needed (on-chain metrics, futures funding rates, sentiment).
2. The ARIMA 12-day forecast gives a central estimate of **$74,500** ± **$17,000** (95 % PI). Use it **not as a signal**, but as a baseline for VaR.

**For a risk manager:**
1. **Stress test:** a daily −50 % shock has occurred 5 times in 6 years. VaR must account for this.
2. **30-day rolling volatility** (Task 2.4) is a good indicator of the transition between calm and crisis regimes. Trigger: vol30 > 80 % annualised → reduce leverage.
3. Correlations **rise** in crisis periods (standard crisis correlation lift) — actual diversification during crises is even worse than the average 0.65.

---

## Conclusion

A complete analytical cycle on daily data for 6 cryptocurrencies (≈ 13,900 raw observations) revealed three key features of the crypto market:

1. **A single factor:** PCA showed that 68.5 % of total variance is explained by a common "crypto beta". Diversification inside crypto is illusory.
2. **Weak short-term predictability:** ARIMA gives MAPE ~3 % (but does not beat random walk), the directional classifier has AUC 0.56 (a weak signal, insufficient for trading).
3. **Risk structure:** BNB / BTC — best return/risk ratio; SOL — most volatile; XRP / ADA — weakest.

These findings are robust because (a) the data spans the full 2020-2026 cycle including all major shocks (COVID, LUNA, FTX, AI rally), (b) the ARIMA residuals pass the Ljung-Box test, (c) classifier metrics come from an honest 441-day out-of-sample holdout.

---

## Project files

| File | Description |
|------|-------------|
| `00_download_data.R` | Download 6 tickers from Yahoo Finance |
| `01_task1_cleaning.R` | Pivot, NA handling, outlier detection |
| `02_task2_eda.R` | Descriptive statistics + 4 visualizations |
| `03_task3_arima.R` | ARIMA on BTC: ADF, ACF/PACF, 12-day forecast, RMSE/MAE |
| `04_task4_pca.R` | PCA on returns of 6 coins, scree + biplot + interpretation |
| `05_task5_classification.R` | Logistic + Random Forest on 14 features, ROC, importance |
| `crypto_raw.csv` | Raw data (13,934 rows) |
| `crypto_clean.csv` | Wide, close price for 6 coins (2,339 rows) |
| `crypto_returns.csv` | Daily log-returns |
| `crypto_clean_common.csv` | Common-date intersection (2,239 rows) |
| `t3_forecast.csv` | 12-day BTC forecast with PI |
| `t4_variance.csv`, `t4_loadings.csv` | PCA outputs |
| `t5_metrics.csv` | Classification metrics |
| `t1_*.png` … `t5_*.png` | 15 PNG plots (see below) |

**Plot list:**
- `t1_missing.png` — missing-value heatmap
- `t1_outliers_box.png` — return boxplot
- `t2_prices_norm.png` — prices rebased to 100
- `t2_returns_hist.png` — return histograms
- `t2_corr.png` — correlation matrix
- `t2_btc_vol30.png` — BTC 30-day rolling vol
- `t3_acf_pacf.png` — ACF/PACF of price and returns
- `t3_forecast.png` — ARIMA forecast
- `t3_residuals.png` — residual diagnostics
- `t4_scree.png` — scree + cumulative variance
- `t4_biplot.png` — PC1-PC2 biplot
- `t4_pc1_time.png` — PC1 over time = synthetic market index
- `t5_roc.png` — ROC curves of both models
- `t5_importance.png` — RF variable importance
- `t5_confusion.png` — confusion matrices

---

## R packages used

- **`quantmod`** — Yahoo Finance data download
- **`forecast`** — `auto.arima`, `ndiffs`, `forecast`
- **`tseries`** — ADF test
- **`randomForest`** — classification
- **`pROC`** — ROC and AUC
- **`TTR`** — RSI, MACD
- **`corrplot`** — correlation matrix
- **`xts`** — time-series objects
