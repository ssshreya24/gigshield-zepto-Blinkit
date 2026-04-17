"""
GigShield ML API — Zone Risk Prediction + Model Info
Serves the trained XGBoost model via FastAPI.
Run: uvicorn api:app --host 0.0.0.0 --port 8001
"""

from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import json
import os

app = FastAPI(
    title="GigShield Risk Prediction API",
    description="XGBoost-based zone risk classification for parametric insurance",
    version="2.0",
)

model = joblib.load("risk_model.pkl")

# Load metrics if available
metrics = {}
if os.path.exists("model_metrics.json"):
    with open("model_metrics.json") as f:
        metrics = json.load(f)


class ZoneInput(BaseModel):
    """Features for zone risk prediction."""
    avg_monthly_rain_mm: float
    flood_events_per_year: float
    aqi_bad_days_per_month: float
    dark_store_outages_month: float
    avg_wind_speed_kmh: float = 10.0       # Optional — defaults if not provided
    extreme_heat_days_month: float = 3.0   # Optional — defaults if not provided


@app.post("/predict-risk")
def predict_risk(data: ZoneInput):
    """
    Predict zone risk level and premium multiplier.

    Returns:
    - risk_score: 0 (LOW), 1 (MEDIUM), 2 (HIGH)
    - risk_label: human-readable label
    - premium_multiplier: factor applied to base premium
    - confidence: prediction probability for the chosen class
    """
    features = [[
        data.avg_monthly_rain_mm,
        data.flood_events_per_year,
        data.aqi_bad_days_per_month,
        data.dark_store_outages_month,
        data.avg_wind_speed_kmh,
        data.extreme_heat_days_month,
    ]]

    score = int(model.predict(features)[0])
    proba = model.predict_proba(features)[0]

    multipliers = {0: 1.0, 1: 1.3, 2: 1.6}
    labels      = {0: "LOW", 1: "MEDIUM", 2: "HIGH"}

    return {
        "risk_score":         score,
        "risk_label":         labels[score],
        "premium_multiplier": multipliers[score],
        "confidence":         round(float(proba[score]), 4),
        "probabilities": {
            "LOW":    round(float(proba[0]), 4),
            "MEDIUM": round(float(proba[1]), 4),
            "HIGH":   round(float(proba[2]), 4),
        },
    }


@app.get("/model-info")
def model_info():
    """
    Returns model metadata, accuracy, feature importance, and class distribution.
    Useful for admin dashboard and pitch presentations.
    """
    return {
        "model_type":         metrics.get("model_type", "XGBoost Classifier"),
        "accuracy":           metrics.get("accuracy", "N/A"),
        "cv_accuracy":        metrics.get("cv_accuracy_mean", "N/A"),
        "training_samples":   metrics.get("training_samples", "N/A"),
        "features":           metrics.get("features", []),
        "feature_importance": metrics.get("feature_importance", {}),
        "class_distribution": metrics.get("class_distribution", {}),
    }


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}
