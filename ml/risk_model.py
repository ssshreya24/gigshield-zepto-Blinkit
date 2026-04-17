"""
GigShield — XGBoost Zone Risk Classifier
Trained on 500+ synthetic samples derived from real Indian city weather patterns.
Outputs: LOW (0), MEDIUM (1), HIGH (2) risk classification per zone.
Used by premiumEngine.js to dynamically adjust weekly premiums.
"""

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import joblib
import json
import os

# ─── Generate 500+ realistic synthetic training data ─────────────
# Based on real Indian metro zone weather/disruption patterns
np.random.seed(42)
N = 600

# Feature distributions modeled after Indian cities
avg_monthly_rain_mm      = np.concatenate([
    np.random.normal(180, 60, N // 3),   # High rain zones (Mumbai, Chennai monsoon)
    np.random.normal(80, 30, N // 3),    # Medium rain zones (Bangalore, Pune)
    np.random.normal(30, 15, N // 3),    # Low rain zones (Delhi, Hyderabad dry season)
]).clip(0, 500)

flood_events_per_year    = np.concatenate([
    np.random.poisson(5, N // 3),        # Flood-prone (Mumbai, Chennai)
    np.random.poisson(2, N // 3),        # Moderate
    np.random.poisson(0.5, N // 3),      # Low flood risk
]).clip(0, 15)

aqi_bad_days_per_month   = np.concatenate([
    np.random.normal(10, 3, N // 3),     # Polluted zones (Delhi, Gurgaon)
    np.random.normal(5, 2, N // 3),      # Moderate (Bangalore, Pune)
    np.random.normal(2, 1, N // 3),      # Clean zones
]).clip(0, 25)

dark_store_outages_month = np.concatenate([
    np.random.poisson(3, N // 3),        # Disruption-prone
    np.random.poisson(1.5, N // 3),      # Moderate
    np.random.poisson(0.5, N // 3),      # Stable
]).clip(0, 10)

# Additional features for richer model
avg_wind_speed_kmh       = np.concatenate([
    np.random.normal(25, 10, N // 3),    # Coastal / storm-prone
    np.random.normal(15, 5, N // 3),     # Moderate
    np.random.normal(8, 3, N // 3),      # Calm
]).clip(0, 80)

extreme_heat_days_month  = np.concatenate([
    np.random.normal(8, 3, N // 3),      # North India summer
    np.random.normal(4, 2, N // 3),      # Moderate
    np.random.normal(1, 1, N // 3),      # Coastal / mild
]).clip(0, 20)

# Generate labels using a scoring function (simulates expert labeling)
def compute_risk_label(rain, flood, aqi, outage, wind, heat):
    score = (
        (rain / 300) * 25 +
        (flood / 10) * 25 +
        (aqi / 15) * 20 +
        (outage / 5) * 15 +
        (wind / 60) * 8 +
        (heat / 15) * 7
    )
    if score > 55:
        return 2  # HIGH
    elif score > 30:
        return 1  # MEDIUM
    else:
        return 0  # LOW

risk_labels = np.array([
    compute_risk_label(r, f, a, o, w, h)
    for r, f, a, o, w, h in zip(
        avg_monthly_rain_mm, flood_events_per_year,
        aqi_bad_days_per_month, dark_store_outages_month,
        avg_wind_speed_kmh, extreme_heat_days_month
    )
])

# Build DataFrame
df = pd.DataFrame({
    'avg_monthly_rain_mm':      avg_monthly_rain_mm,
    'flood_events_per_year':    flood_events_per_year,
    'aqi_bad_days_per_month':   aqi_bad_days_per_month,
    'dark_store_outages_month': dark_store_outages_month,
    'avg_wind_speed_kmh':       avg_wind_speed_kmh,
    'extreme_heat_days_month':  extreme_heat_days_month,
    'risk_label':               risk_labels,
})

print(f"Dataset: {len(df)} samples")
print(f"Class distribution:\n{df['risk_label'].value_counts().sort_index()}\n")

# ─── Train / Test Split ──────────────────────────────────────────
X = df.drop('risk_label', axis=1)
y = df['risk_label']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Train: {len(X_train)} | Test: {len(X_test)}")

# ─── Train XGBoost ───────────────────────────────────────────────
model = xgb.XGBClassifier(
    n_estimators=100,
    max_depth=4,
    learning_rate=0.1,
    random_state=42,
    eval_metric='mlogloss',
    use_label_encoder=False,
)
model.fit(X_train, y_train)

# ─── Evaluate ────────────────────────────────────────────────────
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

print(f"\n{'='*50}")
print(f"  MODEL ACCURACY: {accuracy:.2%}")
print(f"{'='*50}\n")

print("Classification Report:")
print(classification_report(y_test, y_pred,
    target_names=['LOW', 'MEDIUM', 'HIGH']))

print("Confusion Matrix:")
cm = confusion_matrix(y_test, y_pred)
print(cm)

# ─── Cross-Validation ────────────────────────────────────────────
cv_scores = cross_val_score(model, X, y, cv=5, scoring='accuracy')
print(f"\n5-Fold Cross-Validation Accuracy: {cv_scores.mean():.2%} (±{cv_scores.std():.2%})")

# ─── Feature Importance ──────────────────────────────────────────
importance = model.feature_importances_
feature_names = X.columns.tolist()
importance_dict = dict(zip(feature_names, [round(float(v), 4) for v in importance]))
sorted_importance = sorted(importance_dict.items(), key=lambda x: x[1], reverse=True)

print(f"\nFeature Importance:")
for feat, imp in sorted_importance:
    bar = '#' * int(imp * 50)
    print(f"  {feat:30s} {imp:.4f} {bar}")

# ─── Save Model + Metrics ────────────────────────────────────────
joblib.dump(model, 'risk_model.pkl')
print(f"\n[OK] Model saved to risk_model.pkl")

# Save metrics as JSON (for API /model-info endpoint)
metrics = {
    'model_type': 'XGBoost Classifier',
    'n_estimators': 100,
    'max_depth': 4,
    'training_samples': len(X_train),
    'test_samples': len(X_test),
    'accuracy': round(accuracy, 4),
    'cv_accuracy_mean': round(cv_scores.mean(), 4),
    'cv_accuracy_std': round(cv_scores.std(), 4),
    'feature_importance': importance_dict,
    'class_distribution': {
        'LOW': int((y == 0).sum()),
        'MEDIUM': int((y == 1).sum()),
        'HIGH': int((y == 2).sum()),
    },
    'features': feature_names,
    'confusion_matrix': cm.tolist(),
}

with open('model_metrics.json', 'w') as f:
    json.dump(metrics, f, indent=2)
print(f"[OK] Metrics saved to model_metrics.json")

# ─── Generate Feature Importance Chart (text-based for portability) ──
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(10, 6))
    y_pos = np.arange(len(sorted_importance))
    bars = ax.barh(y_pos, [v for _, v in sorted_importance],
                   color=['#FF5252', '#F5A623', '#4B9FFF', '#9C6FFF', '#00C853', '#7A8BB0'])
    ax.set_yticks(y_pos)
    ax.set_yticklabels([k for k, _ in sorted_importance])
    ax.set_xlabel('Importance Score')
    ax.set_title('XGBoost Feature Importance — Zone Risk Model')
    ax.invert_yaxis()
    plt.tight_layout()
    plt.savefig('feature_importance.png', dpi=150)
    print("[OK] Feature importance chart saved to feature_importance.png")
except ImportError:
    print("[WARN] matplotlib not installed -- skipping chart (metrics JSON available)")
