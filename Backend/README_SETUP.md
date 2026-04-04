# GigShield Backend — Setup Guide

## Your friend runs ONLY these 3 commands — nothing else needed

### Step 1 — Clone the repo
git clone https://github.com/ssshreya24/gigshield-zepto-Blinkit
cd gigshield-backend

### Step 2 — Add API key
cp .env.example .env
# Open .env and paste your OpenWeatherMap API key

### Step 3 — Run everything
docker-compose up --build

Done. Backend runs on http://localhost:3000
Database runs on localhost:5432

---

## Test the setup (open new terminal)

# Health check
curl http://localhost:3000/health

# Get dynamic premium
curl "http://localhost:3000/premium?zone=Koramangala&plan_type=standard&tenure_weeks=1&weather_risk=70"

# Register a worker
curl -X POST http://localhost:3000/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ravi","phone":"9111111111","zone":"Koramangala","platform":"Zepto","avg_daily_income":800,"plan_type":"standard"}'

# Fire a demo trigger (for video recording)
curl -X POST http://localhost:3000/demo/trigger \
  -H "Content-Type: application/json" \
  -d '{"zone":"Koramangala","type":"heavy_rain","severity":"T2","value":60}'

# Check auto-created claims
curl http://localhost:3000/claims/1

# Admin dashboard data
curl http://localhost:3000/admin/stats
curl http://localhost:3000/admin/claims

---

## Stop everything
docker-compose down

## Stop and delete all data (fresh start)
docker-compose down -v

