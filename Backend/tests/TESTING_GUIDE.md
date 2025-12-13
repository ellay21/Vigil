# GSM AI Features - Manual Testing Guide

Use this guide to manually test the AI endpoints. Copy the `curl` commands into your terminal (Git Bash, PowerShell, or Command Prompt).

## Prerequisites

1.  **Server Running:** Ensure your server is running (`npm run dev`).
2.  **API Key:** Ensure your `.env` file has a valid `GEMINI_API_KEY`.

---

## 1. Seed Data (Required First Step)

The AI needs historical data to analyze. Run these commands to populate the database with "dangerous" readings.

**Command:**
```bash
curl -X POST -H "Content-Type: application/json" -d "{\"device_id\": \"AI-TEST-001\", \"temperature\": 85, \"smoke\": 1, \"light\": 200, \"state\": \"DANGER\", \"timestamp\": \"2025-12-22T10:00:00Z\"}" http://localhost:3000/api/device/data

curl -X POST -H "Content-Type: application/json" -d "{\"device_id\": \"AI-TEST-001\", \"temperature\": 88, \"smoke\": 1, \"light\": 180, \"state\": \"DANGER\", \"timestamp\": \"2025-12-22T10:05:00Z\"}" http://localhost:3000/api/device/data

curl -X POST -H "Content-Type: application/json" -d "{\"device_id\": \"AI-TEST-001\", \"temperature\": 95, \"smoke\": 1, \"light\": 150, \"state\": \"CRITICAL\", \"timestamp\": \"2025-12-22T10:10:00Z\"}" http://localhost:3000/api/device/data
```

**Expected Response:** `{"message":"Data received successfully"}` for each.

---

## 2. Test AI Risk Assessment

**Endpoint:** `GET /api/device/:id/risk`

**Command:**
```bash
curl http://localhost:3000/api/device/AI-TEST-001/risk
```

**Expected Success Response:**
```json
{
  "device_id": "AI-TEST-001",
  "risk_level": "HIGH",
  "confidence": 0.9,
  "reason": "..."
}
```

**If it fails:** You might see `"risk_level": "UNKNOWN"` and a reason starting with `"AI analysis failed: ..."`. **Copy that error message.**

---

## 3. Test AI Explanation

**Endpoint:** `GET /api/device/:id/explanation`

**Command:**
```bash
curl http://localhost:3000/api/device/AI-TEST-001/explanation
```

**Expected Success Response:**
```json
{
  "explanation": "The device is overheating and smoke is detected..."
}
```

---

## 4. Test Voice Alert (TTS)

**Endpoint:** `GET /api/device/:id/voice`

**Command:**
```bash
curl http://localhost:3000/api/device/AI-TEST-001/voice
```

**Expected Success Response:**
```json
{
  "text": "The device is overheating...",
  "audio_url": "https://translate.google.com/translate_tts?..."
}
```

---

## 5. Test System Summary

**Endpoint:** `GET /api/summary`

**Command:**
```bash
curl http://localhost:3000/api/summary
```

**Expected Success Response:**
```json
{
  "overall_status": "ATTENTION REQUIRED",
  "devices_at_risk": 1,
  "summary": "..."
}
```

---

## Debugging Checklist

If you get errors, check these:

1.  **API Key:** Is `GEMINI_API_KEY` set in `.env`? Did you restart the server *after* setting it?
2.  **Model Name:** The code uses `gemini-1.5-flash`. Does your API key support this model? (Some keys only support `gemini-pro`).
3.  **Region:** Are you in a region where Gemini API is supported?
4.  **Console Logs:** Check the terminal where `npm run dev` is running. It will print detailed error messages from Google.
