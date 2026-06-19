<div align="center">

<img src="https://img.shields.io/badge/Python-3.10+-blue.svg" alt="Python">
<img src="https://img.shields.io/badge/FastAPI-0.100+-green.svg" alt="FastAPI">
<img src="https://img.shields.io/badge/Flutter-3.x-blue.svg" alt="Flutter">
<img src="https://img.shields.io/badge/XGBoost-2.x-orange.svg" alt="XGBoost">
<img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">

# 🤖 Market Insight

### AI-Powered Smart Trading System

</div>

---

## 📖 Overview

**Market Insight** is an intelligent trading system designed to empower individual traders with data-driven investment decisions. It combines **Technical Analysis** with **Financial News Sentiment Analysis** using Artificial Intelligence and Machine Learning to generate **BUY / SELL / HOLD** recommendations with confidence scores and automatic risk management.

> 🎯 **Goal:** Provide a comprehensive analytical tool for Arab traders, integrating everything they need in one application with a transparent mechanism for reviewing recommendation accuracy.

---

## 🚀 Key Features

| Feature | Description |
|---------|-------------|
| 📊 **15 Technical Indicators** | EMA, RSI, MACD, ATR, Stochastic, and more |
| 📰 **News Sentiment Analysis** | NLP + TF-IDF + XGBoost on 11,000+ news articles |
| 🤖 **Hybrid Model** | 19 features (15 technical + 4 sentiment) |
| 📱 **Cross-Platform App** | Flutter (Android + iOS) |
| 🛡️ **Risk Management** | Dynamic TP/SL using ATR |
| ✅ **Signal Review** | Track and evaluate past recommendations |
| 🌍 **4 Financial Markets** | Crypto, Forex, Metals, Stocks |
| ⏱️ **9 Timeframes** | From 1 minute to 1 month |
| 🔄 **Real-Time Updates** | Prices every second, news every 5 minutes |
| 🌐 **Bilingual Support** | Arabic and English |

---

## 📊 Model Performance

| Model | Metric | Result |
|-------|--------|--------|
| Technical Analysis (XGBoost) | Accuracy | **64%** |
| News Sentiment (TF-IDF + XGBoost) | F1-Score | **0.72** |
| **Hybrid Model** | Accuracy | **68%** |
| Signal Generation Speed | Response Time | **< 0.9 sec** |
| API Response Speed | Response Time | **< 1.2 sec** |

---

## 🛠️ Tech Stack

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.10+ | Core programming language |
| **FastAPI** | 0.100+ | REST API framework |
| **XGBoost** | 2.x | Machine learning model |
| **scikit-learn** | 1.3+ | TF-IDF and data preprocessing |
| **ccxt** | - | Binance data fetching |
| **yfinance** | - | Yahoo Finance data fetching |

### Frontend

| Technology | Purpose |
|------------|---------|
| **Flutter 3.x** | UI framework |
| **Dart 3.3+** | Programming language |
| **Riverpod 2.x** | State management |
| **GoRouter 12.x** | Navigation management |

### Infrastructure

| Technology | Purpose |
|------------|---------|
| **Firebase Auth** | User authentication |
| **Firebase Firestore** | Cloud NoSQL database |
| **Render.com** | Backend hosting |

---

## 🧠 Hybrid Model – The Core

The system uses an **XGBoost Multiclass Classifier** that combines:

| Feature Type | Count | Source |
|--------------|-------|--------|
| **Technical Features** | 15 | EMA, RSI, MACD, ATR, Stochastic... |
| **News Features** | 4 | Sentiment, Confidence, Impact, Count |
| **Total** | **19** | Input to XGBoost |

**Outputs:**
- BUY / SELL / HOLD
- Confidence Score
- 3 Take-Profit Levels (TP1, TP2, TP3)
- Stop-Loss (SL)

**Confidence Threshold: 0.42** (selected after multiple experiments for optimal Precision/Recall balance).

---

## 📁 Project Structure
