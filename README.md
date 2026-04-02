# 🛡️ GigShield — AI-Powered Parametric Insurance for Q-Commerce Delivery Workers

> **Guidewire DEVTrails 2026 | University Hackathon**
> Phase 1 Submission | Team: FutureForge

---

## 🎯 Our Idea

**GigShield** is an AI-enabled parametric insurance platform that automatically detects external disruptions and compensates Q-Commerce delivery workers (Zepto/Blinkit) for **income loss** — with **zero manual claims**.

When a trigger event is detected (heavy rain, flood, curfew, platform outage), the system verifies worker activity, calculates the exact income gap, passes fraud checks, and releases an instant UPI payout — all automatically, in under 2 minutes.

---

## 💡 Problem Statement

> *"Delivery partners in quick-commerce platforms lose 20–30% of their monthly income when external disruptions reduce or stop order availability — even when they are active and ready to work. These disruptions are entirely beyond their control, and no automated financial protection system exists for this income loss."*

### Why Q-Commerce Workers Are Uniquely Vulnerable

Q-commerce delivery workers face a specific set of structural risks that make them more exposed than food or e-commerce delivery partners:

| Risk Factor | Impact |
|---|---|
| **Single Dark Store Dependency** | One store serves an entire zone — store disruption = zero orders = zero income |
| **Strict 10-Minute SLA** | Any delay causes order cancellations, reducing worker deliveries system-wide |
| **Hyper-Local Zones** | Workers operate in tiny 1–3 km zones — a local disruption has 100% impact |
| **Weather Events** | Rain, flood, extreme heat halts deliveries entirely |
| **Social Disruptions** | Curfews, local strikes block access to pickup and drop zones |
| **Platform-Side Failures** | App crashes, dark store shutdowns cause sudden zero-order periods |

**Critical constraint respected:** GigShield covers **income loss only**. No health, life, accident, or vehicle repair coverage.

---

## 👤 Persona

**Platform:** Zepto / Blinkit (Q-Commerce / Grocery Delivery)

**User Profile:**
- Delivery partner operating in a hyper-local zone (1–3 km radius)
- Earns ₹600–₹1,200/day depending on order volume
- Works 6–10 hours/day, 6 days/week
- Operates week-to-week financially with no existing safety net

### Real-World Scenario

> **Ravi**, a Zepto delivery partner in Bangalore's Koramangala zone, earns ~₹800/day. On a Tuesday afternoon, heavy rainfall triggers a flood alert in his zone. His dark store halts operations. Despite being active and online, Ravi receives zero orders for 6 hours — losing approximately ₹400.
>
> Under GigShield: the system detects rainfall crossing the T2 threshold, verifies Ravi's GPS location and active status, confirms no fraud signals, calculates the income gap (₹400), and releases a UPI payout of ₹400 — **without Ravi filing a single form.**

---

## ⚙️ System Workflow

```
Worker Registers (Mobile App)
        ↓
AI Calculates Weekly Premium
(Zone Risk Score + Weather Forecast + Tenure Factor + Dark Store Uptime)
        ↓
Worker Activates Weekly Policy (₹29 / ₹49 / ₹79 per week)
        ↓
Real-Time Monitoring Begins
(Weather API + GPS Activity + Platform Order Signals)
        ↓
Disruption Detected → Parametric Trigger Fires
        ↓
Worker Activity Verified (Was the worker online and within zone?)
        ↓
Income Loss Calculated (Expected Earnings − Actual Earnings during disruption)
        ↓
Fraud Detection Check (GPS validation + behavioral analysis + duplicate check)
        ↓
Payout Decision (Approved / Flagged / Rejected)
        ↓
Instant Payout Released (UPI / Wallet) + Push Notification Sent
```

---

## ⚡ Parametric Triggers

GigShield uses **parametric triggers** to automatically detect disruptions affecting gig workers. Instead of manual claims, payouts are triggered based on real-time external data with predefined thresholds.

### Trigger Threshold Table

| Trigger Type | Data Source | Threshold | Tier | Payout |
|---|---|---|---|---|
| Heavy Rainfall | OpenWeatherMap API | > 50mm in 3 hours | T2 | 50% of weekly coverage |
| Extreme Rainfall / Flood | OpenWeatherMap + IMD | > 100mm in 3 hours OR flood alert issued | T3 | 100% of weekly coverage |
| Extreme Heat | OpenWeatherMap API | > 43°C for 4+ consecutive hours | T1 | 25% of weekly coverage |
| Severe Air Pollution | AQICN / Government AQI API | AQI > 300 for 3+ hours | T2 | 50% of weekly coverage |
| Curfew / Local Strike | Government Alerts / News API | Verified curfew in worker's zone | T3 | 100% of weekly coverage |
| Zone / Market Closure | Dark Store Status + Order Volume | > 70% drop in zone orders for 2+ hours | T2 | 50% of weekly coverage |
| Full Platform Shutdown | Platform API / Order Signal | > 80% drop OR dark store closure confirmed | T3 | 100% of weekly coverage |

### Trigger Decision Logic

```
IF (External Trigger Fires)
AND (Worker GPS is within active zone)
AND (Worker is online in app)
AND (Actual Income < Expected Income by threshold gap)
AND (Fraud Check = PASSED)
→ Payout Approved and Released
```

### How Tier Payouts Map to Plans

| Tier | Basic (₹29/wk) | Standard (₹49/wk) | Pro (₹79/wk) |
|---|---|---|---|
| T1 — 25% | ₹125 | ₹225 | ₹375 |
| T2 — 50% | ₹250 | ₹450 | ₹750 |
| T3 — 100% | ₹500 | ₹900 | ₹1,500 |

---

## 💰 Weekly Pricing Model

GigShield uses a **weekly premium structure** aligned to the gig worker's earning and payout cycle.

### Base Weekly Plans

| Plan | Weekly Premium | Max Weekly Payout | Coverage |
|---|---|---|---|
| Basic | ₹29/week | ₹500/week | Up to 4 hrs/day income loss |
| Standard | ₹49/week | ₹900/week | Up to 6 hrs/day income loss |
| Pro | ₹79/week | ₹1,500/week | Full day income loss |

### AI-Adjusted Premium Formula

```
Final Weekly Premium = Base Premium
                     + (Zone Risk Score × 0.3)
                     + (Weather Forecast Risk Score × 0.2)
                     − (Tenure Discount)
                     + (Dark Store Reliability Penalty)
```

**Factor definitions:**

| Factor | Range | Description |
|---|---|---|
| Zone Risk Score | 0–30 (₹) | Historical flood/disruption frequency in worker's zone |
| Weather Forecast Risk | 0–20 (₹) | Upcoming week's predicted disruption probability |
| Tenure Discount | 0–10 (₹) | Workers with 3+ months and clean claim history get a reduction |
| Dark Store Reliability Penalty | 0–10 (₹) | Zones with frequent dark store downtime add a small surcharge |

**Worked Example:**

> Ravi (Standard Plan, ₹49 base) operates in a flood-prone Bangalore zone during monsoon.
> - Zone Risk Score: +₹18
> - Weather Forecast Risk (monsoon week): +₹12
> - Tenure Discount (4 months, 0 fraud flags): −₹8
> - Dark Store Penalty: +₹5
>
> **Final Weekly Premium = ₹49 + ₹18 + ₹12 − ₹8 + ₹5 = ₹76/week**

Premium is recalculated every week before policy renewal and auto-deducted from platform earnings.

---

## 🤖 AI/ML Integration Plan

### Core Philosophy: External Signal First

GigShield does not rely on worker-reported data. Every payout decision is driven by verified external signals combined with income gap analysis.

```
Verified External Trigger + Worker Active + Income Gap Confirmed + Fraud Check Passed
→ Payout
```

---

### Models Used

**1. Risk Assessment Model — XGBoost**
- Predicts zone-level disruption risk for premium calculation
- Input: Zone GPS coordinates, historical disruption frequency, weather forecast, season, dark store uptime history
- Output: Risk score (Low / Medium / High) → maps to premium adjustment (+₹0 / +₹15 / +₹30)

**2. Income Prediction Model — Prophet / LSTM**
- Predicts expected weekly earnings for each worker
- Input: Worker's past 4-week earnings history, day-of-week patterns, time-of-day peaks, local weather
- Output: Expected income baseline → compared against actual earnings during disruption to calculate loss gap

**3. Dynamic Premium Engine**
- Runs every Sunday night before the new week's policy activates
- Combines XGBoost risk score + Prophet income baseline + zone conditions
- Outputs a personalised weekly premium amount per worker

**4. Fraud Detection Model — Rule-Based + Isolation Forest**
- Flags anomalous claim patterns using statistical outlier detection
- Catches GPS spoofing, coordinated fraud rings, and duplicate claims

---

### Feature Engineering

| Raw Input | Engineered Feature | Used In |
|---|---|---|
| Zone GPS coordinates | Zone Risk Score (0–100) | Premium Engine |
| Weather API data | Disruption Probability (%) | Premium Engine + Trigger |
| Historical disruption events | Flood / Event Frequency per Zone | Risk Model |
| Worker tenure | Tenure Factor (discount multiplier) | Premium Engine |
| Past claim history | Claim Ratio | Fraud Model |
| Earnings history | Expected Weekly Income Baseline | Income Model |
| GPS movement logs | Movement Continuity Score | Fraud Model |

---

### Cold Start Strategy (New Workers)

GigShield starts without real worker data and solves this with a hybrid data approach:

| Week | Data Source |
|---|---|
| Week 1–2 | 100% zone-level average risk and income estimates |
| Week 3–4 | 70% zone data + 30% worker's own activity data |
| Week 5+ | Fully personalised model using worker's own history |

Pre-training data sources: IMD historical weather, OpenWeatherMap, synthetic income pattern generation, zone-level disruption event logs.

---

## 🔐 Fraud Detection System

GigShield uses multi-layer fraud validation before any payout is approved.

### Layer 1 — GPS Spoofing Detection
```
IF distance between consecutive GPS points > 5 km AND time < 60 seconds
→ Flag as GPS spoofing → Reject claim
```

### Layer 2 — Activity Verification
- Worker must be online in app AND GPS must place them within their registered delivery zone
- Cross-checks active session logs with GPS movement continuity

### Layer 3 — Behavioral Anomaly Detection
- Flags workers who log in only during disruption windows consistently
- Flags claim frequency exceeding 3 valid claims per week
- Uses Isolation Forest model for statistical outlier detection

### Layer 4 — Duplicate Claim Prevention
- Each disruption event is assigned a unique Event ID
- A worker can file only one claim per Event ID

### Layer 5 — Coordinated Fraud / Ring Detection
```
IF multiple accounts show identical GPS location + claim timing + device fingerprint
→ Flag as coordinated fraud ring → Block cluster + manual review
```

**Signals used for ring detection:**

| Signal | What It Catches |
|---|---|
| Device Fingerprinting | Multiple accounts on same device |
| IP / Network Clustering | Accounts operating from same VPN or IP range |
| Temporal Clustering | Many claims triggered at identical timestamps |
| Zone Anomaly Spikes | Unusual claim surge in a micro-zone |

### Fraud Response Tiers

| Suspicion Level | Action |
|---|---|
| 🟢 Low | Payout approved immediately |
| 🟡 Medium | Payout delayed 2 hours + secondary verification sent |
| 🔴 High | Payout blocked + flagged for manual review |

**Core design principle:** Honest workers experiencing genuine disruption are never instantly penalized. The system uses graceful degradation — delayed verification, not hard rejection.

---

## 📱 Platform Choice — Mobile First (Android)

**Why mobile over web:**

| Reason | Explanation |
|---|---|
| GPS tracking | Real-time location required for fraud detection and activity verification |
| Background monitoring | App tracks worker activity even when minimized |
| Push notifications | Instant disruption alerts and payout confirmations |
| User behaviour match | Delivery workers already use mobile apps daily (Zepto, Blinkit) |
| Low-connectivity reliability | Mobile apps handle poor network conditions better than web |

---

## 🗺️ UI / Screen Overview (Phase 1 Scope)

**Worker App (React Native):**
1. **Onboarding Screen** — Name, city, zone, platform (Zepto/Blinkit), avg. weekly earnings
2. **Premium Quote Screen** — Shows calculated weekly premium with breakdown of risk factors
3. **Active Policy Screen** — Current week's coverage, tier, max payout, days remaining
4. **Disruption Alert Screen** — Push notification + in-app banner when a trigger fires
5. **Payout Status Screen** — Claim ID, status (Processing / Approved / Paid), amount credited

**Admin Dashboard (Web — React.js):**
1. **Zone Risk Heatmap** — Visual map of disruption risk by zone
2. **Live Claims Monitor** — Real-time claim feed with fraud flags
3. **Loss Ratio Analytics** — Claims paid vs premiums collected
4. **Predictive Alerts** — Next week's high-risk zones based on weather forecast

---

## 🛠️ Tech Stack

### Mobile App (Worker-facing)
- **React Native** — Cross-platform mobile app, Android-first
- **Expo** — GPS, push notifications, background tasks
- **Zustand** — Lightweight state management

### Admin Dashboard (Web)
- **React.js + Tailwind CSS**
- **Recharts / Chart.js** — Analytics and heatmap visualisation

### Backend
- **Node.js + Express** — REST API server (registration, policies, claims, payouts)
- **Python + FastAPI** — AI/ML model serving (risk scoring, income prediction, fraud detection)

### Database
- **PostgreSQL** — Workers, policies, claims, payouts, audit logs
- **Redis** — Real-time trigger event caching

### AI/ML
- **scikit-learn + XGBoost** — Zone risk assessment model
- **Prophet / LSTM** — Income baseline prediction
- **Isolation Forest** — Fraud anomaly detection

### Integrations
- **OpenWeatherMap API** — Weather-based parametric triggers (free tier)
- **AQICN API** — AQI-based pollution triggers
- **Government / News APIs** — Curfew and alert detection (mocked in Phase 2)
- **Razorpay Test Mode / UPI Simulator** — Payout processing (sandbox)
- **Firebase** — Push notifications

### Infrastructure
- **Docker** — Containerisation
- **Render / Railway** — Backend deployment

---

## 📅 Development Plan

### Phase 1 (Mar 4–20) — Problem Understanding & System Design ✅
- [x] Identified core problem: income loss due to uncontrollable external disruptions
- [x] Defined coverage scope: income loss only, strictly no health/vehicle/accident coverage
- [x] Analysed Q-commerce structural vulnerabilities (dark store dependency, hyper-local zones)
- [x] Designed parametric insurance logic with tiered thresholds (T1/T2/T3)
- [x] Defined weekly premium formula with AI adjustment factors
- [x] Finalised AI/ML approach (XGBoost risk model + Prophet income prediction)
- [x] Designed multi-layer fraud detection strategy
- [x] Selected mobile-first architecture with justification
- [x] Completed full system architecture and README

### Phase 2 (Mar 21–Apr 4) — Core System Implementation
- [ ] Build React Native mobile app (onboarding, policy, payout status screens)
- [ ] Build Node.js backend (worker registration, policy management, claims API)
- [ ] Implement weekly premium calculation engine with dynamic AI adjustment
- [ ] Train XGBoost v1 risk model on synthetic + historical weather data
- [ ] Train Prophet v1 income prediction model on synthetic earnings data
- [ ] Build parametric trigger engine (weather API + threshold logic)
- [ ] Implement worker activity verification (GPS + online status check)
- [ ] Build automated claim pipeline (trigger → verification → payout logic)
- [ ] Integrate basic fraud detection (GPS spoof check + duplicate claim prevention)
- [ ] Connect Razorpay test mode for simulated payouts

### Phase 3 (Apr 5–17) — Intelligence, Security & Final Demo
- [ ] Upgrade fraud detection (behavioral ML + coordination ring detection)
- [ ] Build full decision engine (risk + income gap + fraud check combined)
- [ ] Complete admin dashboard (zone heatmap, claims monitor, loss ratio analytics)
- [ ] Build worker dashboard (earnings protected, active coverage, payout history)
- [ ] Simulate end-to-end disruption demo (trigger rainstorm → auto claim → payout)
- [ ] Optimise AI models with collected test data
- [ ] Prepare 5-minute demo video + final pitch deck (PDF)

---

## 👥 Team — FutureForge

| Name | Role |
|---|---|
| **Shreya Singh** | Backend + AI/ML — Risk Model & Income Prediction |
| **Prince Kumar** | Backend + AI/ML — API Development & Model Integration |
| **Kartik Srivastava** | Frontend + AI Integration — Mobile App & API Integration |
| **Ameya Tharkral** | Frontend + UI/UX — App Design & User Experience |
| **Abhinav Tripathi** | Frontend + AI Integration — Admin Dashboard & Data Visualisation |

---

## 🔗 Links

- **GitHub Repository:** [https://github.com/ssshreya24/gigshield-zepto-Blinkit](https://github.com/ssshreya24/gigshield-zepto-Blinkit)
- **Demo Video (Phase 1):** *(to be added before March 20)*

---

> Built with ❤️ for India's gig workers | Guidewire DEVTrails 2026
