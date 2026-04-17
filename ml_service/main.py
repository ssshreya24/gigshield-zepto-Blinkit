# ═══════════════════════════════════════════════════════════════
# Insurify ML Service — FastAPI
# 4 endpoints:
#   POST /predict/risk       → Zone risk score + premium adjustment
#   POST /predict/income     → Expected income baseline
#   POST /predict/fraud      → Fraud probability score
#   POST /predict/next-week  → Next-week disruption forecast per zone
#   GET  /health             → Health check
# ═══════════════════════════════════════════════════════════════

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from sklearn.preprocessing import LabelEncoder
import joblib, os, json, math, random
from datetime import datetime, timedelta
import requests

app = FastAPI(title="Insurify ML Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── ZONE METADATA ────────────────────────────────────────────
ZONES = {
    "Koramangala":  {"lat": 12.9352, "lon": 77.6245, "base_risk": 72, "flood_history": 0.68, "heat_history": 0.30},
    "Indiranagar":  {"lat": 12.9784, "lon": 77.6408, "base_risk": 45, "flood_history": 0.40, "heat_history": 0.35},
    "Whitefield":   {"lat": 12.9698, "lon": 77.7500, "base_risk": 30, "flood_history": 0.25, "heat_history": 0.45},
    "HSR Layout":   {"lat": 12.9116, "lon": 77.6389, "base_risk": 65, "flood_history": 0.60, "heat_history": 0.28},
    "Marathahalli": {"lat": 12.9591, "lon": 77.6974, "base_risk": 55, "flood_history": 0.48, "heat_history": 0.38},
    "Bellandur":    {"lat": 12.9259, "lon": 77.6762, "base_risk": 48, "flood_history": 0.42, "heat_history": 0.33},
    "Jayanagar":    {"lat": 12.9308, "lon": 77.5839, "base_risk": 40, "flood_history": 0.35, "heat_history": 0.30},
    "Andheri":      {"lat": 19.1136, "lon": 72.8697, "base_risk": 60, "flood_history": 0.55, "heat_history": 0.40},
    "Kothrud":      {"lat": 18.5074, "lon": 73.8077, "base_risk": 35, "flood_history": 0.30, "heat_history": 0.50},
    "Baner":        {"lat": 18.5590, "lon": 73.7868, "base_risk": 32, "flood_history": 0.28, "heat_history": 0.48},
}

WEATHER_API_KEY = os.getenv("WEATHER_API_KEY", "e5662aa8fdcc219ae6d83e1e588ca6fd")

# ─── SYNTHETIC TRAINING DATA GENERATOR ────────────────────────
def generate_risk_training_data(n=2000):
    """Generate realistic training data for zone risk model"""
    X, y = [], []
    for _ in range(n):
        base_risk     = random.uniform(20, 80)
        flood_history = random.uniform(0.1, 0.9)
        heat_history  = random.uniform(0.2, 0.7)
        season        = random.randint(0, 3)   # 0=winter 1=summer 2=monsoon 3=autumn
        rainfall_7d   = random.uniform(0, 120) # mm last 7 days
        temp_avg      = random.uniform(22, 48)
        aqi_avg       = random.uniform(50, 350)
        worker_count  = random.randint(20, 200)

        # Risk formula (ground truth with noise)
        risk = (
            base_risk * 0.35
            + flood_history * 30
            + heat_history * 15
            + (2 if season == 2 else 0)          # monsoon boost
            + min(rainfall_7d / 4, 20)
            + max(0, (temp_avg - 38) * 1.5)
            + min(aqi_avg / 20, 12)
            + random.gauss(0, 3)
        )
        risk = max(0, min(100, risk))

        X.append([base_risk, flood_history, heat_history, season,
                  rainfall_7d, temp_avg, aqi_avg, worker_count])
        y.append(risk)
    return np.array(X), np.array(y)

def generate_income_training_data(n=3000):
    """Generate realistic income prediction training data"""
    X, y = [], []
    for _ in range(n):
        avg_daily       = random.uniform(400, 1400)
        day_of_week     = random.randint(0, 6)    # 0=Mon
        hour_start      = random.randint(6, 12)
        hours_worked    = random.uniform(4, 12)
        rainfall        = random.uniform(0, 100)
        temperature     = random.uniform(22, 48)
        aqi             = random.uniform(50, 350)
        tenure_weeks    = random.randint(1, 52)
        platform_factor = random.uniform(0.8, 1.2) # zepto vs blinkit

        # Income prediction formula
        base   = avg_daily * platform_factor
        dow_adj = 1.2 if day_of_week in [4, 5] else (0.85 if day_of_week == 0 else 1.0)
        weather_pen = max(0, 1 - (rainfall / 80) - max(0, (temperature - 40) / 20) - (aqi - 200) / 500)
        tenure_bonus = min(1.15, 1 + tenure_weeks * 0.003)
        expected = base * dow_adj * weather_pen * tenure_bonus * (hours_worked / 8)
        expected = max(0, expected + random.gauss(0, 40))

        X.append([avg_daily, day_of_week, hour_start, hours_worked,
                  rainfall, temperature, aqi, tenure_weeks, platform_factor])
        y.append(expected)
    return np.array(X), np.array(y)

def generate_fraud_training_data(n=2000):
    """Generate fraud detection training data"""
    X, y = [], []
    for _ in range(n):
        claims_this_week   = random.randint(0, 8)
        days_since_signup  = random.randint(1, 365)
        avg_claim_interval = random.uniform(1, 30)   # days
        login_before_trigger = random.uniform(0, 120) # minutes
        gps_distance_jump  = random.uniform(0, 20)   # km
        trigger_overlap    = random.randint(0, 3)     # claims from same trigger
        income_ratio       = random.uniform(0, 2)     # actual/expected

        # Fraud label
        fraud_score = (
            (1 if claims_this_week > 3 else 0) * 40
            + (1 if gps_distance_jump > 5 else 0) * 35
            + (1 if login_before_trigger < 2 else 0) * 20
            + (1 if trigger_overlap > 1 else 0) * 25
            + (1 if income_ratio > 1.5 else 0) * 15
            + (1 if days_since_signup < 7 else 0) * 10
        )
        is_fraud = 1 if fraud_score > 50 else 0

        X.append([claims_this_week, days_since_signup, avg_claim_interval,
                  login_before_trigger, gps_distance_jump, trigger_overlap, income_ratio])
        y.append(is_fraud)
    return np.array(X), np.array(y)

# ─── TRAIN MODELS ON STARTUP ──────────────────────────────────
print("[ML] Training models...")

# Risk model
X_risk, y_risk = generate_risk_training_data(2000)
risk_model = GradientBoostingRegressor(n_estimators=150, max_depth=4, learning_rate=0.1, random_state=42)
risk_model.fit(X_risk, y_risk)
print("[ML] Risk model trained ✓")

# Income model
X_inc, y_inc = generate_income_training_data(3000)
income_model = GradientBoostingRegressor(n_estimators=150, max_depth=5, learning_rate=0.08, random_state=42)
income_model.fit(X_inc, y_inc)
print("[ML] Income model trained ✓")

# Fraud model
X_fraud, y_fraud = generate_fraud_training_data(2000)
fraud_model = RandomForestClassifier(n_estimators=200, max_depth=6, random_state=42, class_weight="balanced")
fraud_model.fit(X_fraud, y_fraud)
print("[ML] Fraud model trained ✓")

print("[ML] All models ready 🚀")

# ─── REQUEST SCHEMAS ──────────────────────────────────────────
class RiskRequest(BaseModel):
    zone: str
    plan_type: str             # basic / standard / pro
    tenure_weeks: int = 1
    rainfall_7d: float = 0.0   # mm last 7 days
    temp_avg: float = 28.0     # celsius
    aqi_avg: float = 100.0
    season: int = 0            # 0=winter 1=summer 2=monsoon 3=autumn

class IncomeRequest(BaseModel):
    avg_daily_income: float
    zone: str
    platform: str              # Zepto / Blinkit
    tenure_weeks: int = 1
    day_of_week: int = 0
    hours_worked: float = 8.0
    rainfall: float = 0.0
    temperature: float = 28.0
    aqi: float = 100.0

class FraudRequest(BaseModel):
    worker_id: int
    claims_this_week: int
    days_since_signup: int
    avg_claim_interval: float = 7.0
    login_before_trigger_minutes: float = 60.0
    gps_distance_jump_km: float = 0.0
    trigger_overlap_count: int = 0
    income_ratio: float = 1.0  # actual / expected

class NextWeekRequest(BaseModel):
    zone: str
    week_offset: int = 1

# ─── HELPER FUNCTIONS ─────────────────────────────────────────
def fetch_weather(lat, lon):
    """Fetch real weather or return defaults"""
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={WEATHER_API_KEY}&units=metric"
        r = requests.get(url, timeout=5)
        d = r.json()
        return {
            "rainfall":    d.get("rain", {}).get("1h", 0),
            "temperature": d["main"]["temp"],
            "humidity":    d["main"]["humidity"],
            "wind_speed":  d["wind"]["speed"],
        }
    except:
        return {"rainfall": 0, "temperature": 28, "humidity": 60, "wind_speed": 5}

def get_season():
    m = datetime.now().month
    if m in [12, 1, 2]:   return 0  # winter
    if m in [3, 4, 5]:    return 1  # summer
    if m in [6, 7, 8, 9]: return 2  # monsoon
    return 3                         # autumn

def zone_to_features(zone_name):
    z = ZONES.get(zone_name, ZONES["Koramangala"])
    return z["base_risk"], z["flood_history"], z["heat_history"]

PLAN_BASE = {"basic": 29, "standard": 49, "pro": 79}
PLAN_PAYOUT = {"basic": 500, "standard": 900, "pro": 1500}

# ─── ENDPOINTS ────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "models": ["risk_gbm", "income_gbm", "fraud_rf"],
        "zones":  list(ZONES.keys()),
        "time":   datetime.utcnow().isoformat()
    }

@app.post("/predict/risk")
def predict_risk(req: RiskRequest):
    """
    XGBoost-style Gradient Boosting risk scoring.
    Returns: risk_score, risk_level, premium_breakdown
    """
    base_risk, flood_hist, heat_hist = zone_to_features(req.zone)
    season = req.season if req.season >= 0 else get_season()

    features = np.array([[
        base_risk, flood_hist, heat_hist, season,
        req.rainfall_7d, req.temp_avg, req.aqi_avg,
        100  # worker_count proxy
    ]])

    risk_score = float(np.clip(risk_model.predict(features)[0], 0, 100))

    # Premium calculation using ML risk score
    base_premium   = PLAN_BASE.get(req.plan_type, 49)
    zone_adj       = round(risk_score / 100 * 20)
    weather_adj    = round(min(req.rainfall_7d / 10, 1.0) * 10 + max(0, req.temp_avg - 38) * 0.5)
    tenure_disc    = 8 if req.tenure_weeks > 8 else (5 if req.tenure_weeks > 4 else 0)
    final_premium  = base_premium + zone_adj + weather_adj - tenure_disc

    risk_level = "HIGH" if risk_score > 60 else ("MEDIUM" if risk_score > 35 else "LOW")

    # Feature importances (for explaining to judges)
    importances = risk_model.feature_importances_
    feature_names = ["base_risk", "flood_history", "heat_history", "season",
                     "rainfall_7d", "temp_avg", "aqi_avg", "worker_count"]
    top_factors = sorted(
        zip(feature_names, importances),
        key=lambda x: x[1], reverse=True
    )[:3]

    return {
        "zone":             req.zone,
        "plan_type":        req.plan_type,
        "risk_score":       round(risk_score, 2),
        "risk_level":       risk_level,
        "max_payout":       PLAN_PAYOUT.get(req.plan_type, 900),
        "premium": {
            "base":             base_premium,
            "zone_adjustment":  zone_adj,
            "weather_adjustment": weather_adj,
            "tenure_discount":  tenure_disc,
            "final":            final_premium,
        },
        "top_risk_factors": [{"factor": f, "importance": round(i * 100, 1)} for f, i in top_factors],
        "model":            "GradientBoostingRegressor"
    }

@app.post("/predict/income")
def predict_income(req: IncomeRequest):
    """
    Predicts expected income for a worker given conditions.
    Returns: expected_income, income_loss (if trigger fired), confidence
    """
    platform_factor = 1.05 if req.platform.lower() == "zepto" else 1.0

    features = np.array([[
        req.avg_daily_income,
        req.day_of_week,
        8,  # hour_start default
        req.hours_worked,
        req.rainfall,
        req.temperature,
        req.aqi,
        req.tenure_weeks,
        platform_factor
    ]])

    expected = float(np.clip(income_model.predict(features)[0], 0, 2000))

    # Disruption scenario (actual income drops)
    disruption_factor = max(0.0,
        1.0
        - min(req.rainfall / 60, 0.8)
        - max(0, (req.temperature - 40) / 15)
        - max(0, (req.aqi - 200) / 400)
    )
    actual_income = expected * disruption_factor

    income_loss    = max(0, expected - actual_income)
    loss_pct       = round((income_loss / expected * 100) if expected > 0 else 0, 1)
    confidence     = round(0.75 + min(req.tenure_weeks / 52 * 0.15, 0.15), 2)

    return {
        "zone":             req.zone,
        "platform":         req.platform,
        "expected_income":  round(expected),
        "actual_income":    round(actual_income),
        "income_loss":      round(income_loss),
        "loss_percentage":  loss_pct,
        "confidence":       confidence,
        "disruption_factor": round(disruption_factor, 3),
        "model":            "GradientBoostingRegressor"
    }

@app.post("/predict/fraud")
def predict_fraud(req: FraudRequest):
    """
    Random Forest fraud detection.
    Returns: fraud_probability, fraud_level, reason_codes
    """
    features = np.array([[
        req.claims_this_week,
        req.days_since_signup,
        req.avg_claim_interval,
        req.login_before_trigger_minutes,
        req.gps_distance_jump_km,
        req.trigger_overlap_count,
        req.income_ratio
    ]])

    fraud_prob    = float(fraud_model.predict_proba(features)[0][1])
    fraud_level   = "HIGH" if fraud_prob > 0.7 else ("MEDIUM" if fraud_prob > 0.35 else "LOW")
    allow_payout  = fraud_prob < 0.7

    # Human-readable reason codes
    reasons = []
    if req.claims_this_week > 3:
        reasons.append(f"High claim frequency: {req.claims_this_week} claims this week")
    if req.gps_distance_jump_km > 5:
        reasons.append(f"GPS anomaly: {req.gps_distance_jump_km:.1f}km jump detected")
    if req.login_before_trigger_minutes < 2:
        reasons.append("Suspicious: logged in immediately before trigger event")
    if req.trigger_overlap_count > 1:
        reasons.append(f"Duplicate trigger claims: {req.trigger_overlap_count} overlaps")
    if req.income_ratio > 1.5:
        reasons.append("Claimed amount exceeds expected income baseline")
    if req.days_since_signup < 7:
        reasons.append("New account: less than 7 days old")

    action = "BLOCK" if fraud_level == "HIGH" else ("REVIEW" if fraud_level == "MEDIUM" else "APPROVE")

    return {
        "worker_id":         req.worker_id,
        "fraud_probability": round(fraud_prob, 3),
        "fraud_level":       fraud_level,
        "action":            action,
        "allow_payout":      allow_payout,
        "reason_codes":      reasons,
        "model":             "RandomForestClassifier"
    }

@app.post("/predict/next-week")
def predict_next_week(req: NextWeekRequest):
    """
    Forecasts next week's disruption probability per zone.
    Combines real current weather + historical zone data + seasonal model.
    This is the 'predictive analytics' feature for the admin dashboard.
    """
    zone_meta = ZONES.get(req.zone, ZONES["Koramangala"])
    current   = fetch_weather(zone_meta["lat"], zone_meta["lon"])
    season    = get_season()

    # Next week is typically monsoon-boosted if currently raining
    rainfall_forecast = current["rainfall"] * 7 * (1.3 if season == 2 else 0.8)
    temp_forecast     = current["temperature"] + (1.5 if season == 1 else -0.5)
    aqi_forecast      = 150 + (50 if season == 1 else 0) + (zone_meta["base_risk"] * 0.5)

    # Risk prediction for next week
    features = np.array([[
        zone_meta["base_risk"],
        zone_meta["flood_history"],
        zone_meta["heat_history"],
        season,
        rainfall_forecast,
        temp_forecast,
        aqi_forecast,
        100
    ]])
    predicted_risk = float(np.clip(risk_model.predict(features)[0], 0, 100))

    # Trigger probability estimates
    rain_prob  = min(0.95, zone_meta["flood_history"] * (1 + current["rainfall"] / 20))
    heat_prob  = min(0.85, zone_meta["heat_history"]  * (1 + max(0, temp_forecast - 38) / 10))
    flood_prob = min(0.80, zone_meta["flood_history"]  * (1 + rainfall_forecast / 60))
    aqi_prob   = min(0.70, (aqi_forecast - 100) / 300)

    trigger_forecasts = [
        {"trigger": "heavy_rain",   "probability": round(rain_prob, 2),  "severity": "T2"},
        {"trigger": "extreme_heat", "probability": round(heat_prob, 2),  "severity": "T1"},
        {"trigger": "flood_alert",  "probability": round(flood_prob, 2), "severity": "T3"},
        {"trigger": "severe_aqi",   "probability": round(max(0, aqi_prob), 2), "severity": "T2"},
    ]
    trigger_forecasts.sort(key=lambda x: x["probability"], reverse=True)

    # Expected claims and payout
    avg_workers_in_zone = 45
    expected_claims = round(avg_workers_in_zone * predicted_risk / 100 * 0.6)
    expected_payout = round(expected_claims * 750)

    return {
        "zone":               req.zone,
        "week_offset":        req.week_offset,
        "predicted_risk":     round(predicted_risk, 1),
        "risk_level":         "HIGH" if predicted_risk > 60 else ("MEDIUM" if predicted_risk > 35 else "LOW"),
        "weather_forecast": {
            "rainfall_mm":    round(rainfall_forecast, 1),
            "temperature_c":  round(temp_forecast, 1),
            "aqi":            round(aqi_forecast),
        },
        "trigger_forecasts":  trigger_forecasts,
        "expected_claims":    expected_claims,
        "expected_payout_inr": expected_payout,
        "confidence":         0.72,
        "model":              "GradientBoostingRegressor + WeatherAPI"
    }

@app.get("/model/info")
def model_info():
    """Returns model architecture info for the pitch deck / demo"""
    return {
        "models": [
            {
                "name": "Zone Risk Scorer",
                "type": "GradientBoostingRegressor",
                "features": 8,
                "training_samples": 2000,
                "purpose": "Calculates hyper-local zone risk score (0-100) to adjust weekly premium"
            },
            {
                "name": "Income Predictor",
                "type": "GradientBoostingRegressor",
                "features": 9,
                "training_samples": 3000,
                "purpose": "Predicts expected daily income baseline to calculate income loss gap"
            },
            {
                "name": "Fraud Detector",
                "type": "RandomForestClassifier",
                "features": 7,
                "training_samples": 2000,
                "purpose": "Multi-factor fraud scoring — GPS spoofing, claim frequency, behavioral anomaly"
            }
        ],
        "pipeline": "Weather API → Risk Score → Premium → [Trigger Event] → Income Loss → Fraud Check → Payout"
    }
