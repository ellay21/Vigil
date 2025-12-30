import { GoogleGenerativeAI } from "@google/generative-ai";
import dotenv from "dotenv";

dotenv.config();

// --- API Key Rotation Logic ---
const rawKeys = process.env.GEMINI_API_KEY || "";
const apiKeys = rawKeys.split(',').map(k => k.trim()).filter(k => k.length > 0);
let currentKeyIndex = 0;

if (apiKeys.length === 0) {
  console.warn("No GEMINI_API_KEY found in environment variables.");
} else {
  console.log(`Loaded ${apiKeys.length} Gemini API keys.`);
}

function getModel() {
  if (apiKeys.length === 0) return null;
  const key = apiKeys[currentKeyIndex];
  const genAI = new GoogleGenerativeAI(key);
  return genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });
}

function rotateKey() {
  if (apiKeys.length <= 1) return false; // No other keys to rotate to
  currentKeyIndex = (currentKeyIndex + 1) % apiKeys.length;
  console.log(`Switching to Gemini API Key #${currentKeyIndex + 1}`);
  return true;
}

async function generateContentWithRetry(prompt: string): Promise<string> {
  let attempts = 0;
  const maxAttempts = apiKeys.length > 0 ? apiKeys.length : 1;

  while (attempts < maxAttempts) {
    const model = getModel();
    if (!model) throw new Error("AI service not configured.");

    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error: any) {
      console.error(`Gemini API Error (Key #${currentKeyIndex + 1}):`, error.message);
      
      const isQuotaError = error.message.includes("429") || 
                           error.message.includes("quota") || 
                           error.message.includes("limit") ||
                           error.status === 429;

      if (isQuotaError) {
        console.warn("Quota limit reached. Rotating API key...");
        if (rotateKey()) {
          attempts++;
          continue;
        } else {
          throw new Error("All API keys exhausted or quota reached.");
        }
      }
      
      throw error;
    }
  }
  throw new Error("Failed to generate content after rotating through all keys.");
}

// --- Prompt Templates ---

const PROMPT_RISK = `
Analyze the following recent sensor readings from an industrial device.
The readings include:
- Voltage (volts)
- PIR Motion (boolean)
- Vibration (boolean)
- Gas Detected (boolean)
- Temperature (Celsius)

Readings: {{READINGS}}
Determine the risk level (LOW, MEDIUM, HIGH), a confidence score (0.0 to 1.0), and a brief reason.
Return ONLY a JSON object with keys: "risk_level", "confidence", "reason".
`;

const PROMPT_EXPLANATION = `
Based on the following recent sensor readings for device {{DEVICE_ID}}, provide a short, non-technical, human-readable explanation of the device's current condition.
The readings include Voltage, PIR Motion, Vibration, Gas, and Temperature.
Readings: {{READINGS}}
Return ONLY a JSON object with key: "explanation".
`;

const PROMPT_MAINTENANCE = `
Analyze the following history of warnings and danger states for device {{DEVICE_ID}}.
History: {{HISTORY}}
Determine if maintenance is required and suggest an action.
Return ONLY a JSON object with keys: "maintenance_required" (boolean), "suggested_action" (string).
`;

const PROMPT_SUMMARY = `
Here is the latest status of all devices in the system:
{{SYSTEM_DATA}}
Generate a concise system-wide safety overview.
Return ONLY a JSON object with keys: "overall_status" (string, e.g., "SAFE", "ATTENTION REQUIRED"), "devices_at_risk" (number), "summary" (string).
`;

// --- Helper to clean JSON response ---
function cleanJSON(text: string): string {
  return text.replace(/```json/g, "").replace(/```/g, "").trim();
}

// --- Helper for TTS URL ---
function getAudioUrl(text: string, lang: string = 'en'): string {
  const encoded = encodeURIComponent(text);
  return `https://translate.google.com/translate_tts?ie=UTF-8&q=${encoded}&tl=${lang}&client=tw-ob`;
}

// --- AI Service Functions ---

export const getRiskAssessment = async (readings: any[], lang: string = 'en') => {
  if (apiKeys.length === 0) return { risk_level: "UNKNOWN", confidence: 0, reason: "AI service not configured" };
  
  try {
    let prompt = PROMPT_RISK.replace("{{READINGS}}", JSON.stringify(readings));
    if (lang === 'am') {
      prompt += " Provide the 'reason' in Amharic language.";
    }
    const text = await generateContentWithRetry(prompt);
    return JSON.parse(cleanJSON(text));
  } catch (error) {
    console.error("Gemini API Error (Risk):", error);
    // Fallback
    return { risk_level: "UNKNOWN", confidence: 0, reason: "AI analysis failed." };
  }
};

export const getExplanation = async (deviceId: string, readings: any[], lang: string = 'en') => {
  if (apiKeys.length === 0) return { explanation: "AI service not configured. Please check device readings manually." };

  try {
    let prompt = PROMPT_EXPLANATION
      .replace("{{DEVICE_ID}}", deviceId)
      .replace("{{READINGS}}", JSON.stringify(readings));
    if (lang === 'am') {
      prompt += " Provide the 'explanation' in Amharic language.";
    }
    const text = await generateContentWithRetry(prompt);
    return JSON.parse(cleanJSON(text));
  } catch (error) {
    console.error("Gemini API Error (Explanation):", error);
    return { explanation: "Unable to generate explanation." };
  }
};

export const getMaintenanceInsight = async (deviceId: string, history: any[], lang: string = 'en') => {
  if (apiKeys.length === 0) return { maintenance_required: false, suggested_action: "Check manual logs." };

  try {
    let prompt = PROMPT_MAINTENANCE
      .replace("{{DEVICE_ID}}", deviceId)
      .replace("{{HISTORY}}", JSON.stringify(history));
    if (lang === 'am') {
      prompt += " Provide the 'suggested_action' in Amharic language.";
    }
    const text = await generateContentWithRetry(prompt);
    return JSON.parse(cleanJSON(text));
  } catch (error) {
    console.error("Gemini API Error (Maintenance):", error);
    return { maintenance_required: false, suggested_action: "Manual inspection recommended." };
  }
};

export const getSystemSummary = async (systemData: any[], lang: string = 'en') => {
  if (apiKeys.length === 0) return { overall_status: "UNKNOWN", devices_at_risk: 0, summary: "AI service not configured." };

  try {
    let prompt = PROMPT_SUMMARY.replace("{{SYSTEM_DATA}}", JSON.stringify(systemData));
    if (lang === 'am') {
      prompt += " Provide the 'summary' and 'overall_status' in Amharic language.";
    }
    const text = await generateContentWithRetry(prompt);
    return JSON.parse(cleanJSON(text));
  } catch (error) {
    console.error("Gemini API Error (Summary):", error);
    return { overall_status: "UNKNOWN", devices_at_risk: 0, summary: "Unable to generate summary." };
  }
};

const PROMPT_CHAT = `
You are an intelligent industrial IoT assistant for device {{DEVICE_ID}}.
Here is the recent sensor history for the device:
{{HISTORY}}

The user asks: "{{QUERY}}"

Answer the user's question based on the data provided. 
If the user asks about the status, summarize the recent readings.
If the user asks for advice, provide technical recommendations based on the sensor values (Voltage, Temp, Gas, Vibration).
Keep the answer concise (under 50 words) and helpful.
`;

export const getChatResponse = async (deviceId: string, history: any[], query: string) => {
  if (apiKeys.length === 0) return "AI service not configured.";

  try {
    const prompt = PROMPT_CHAT
      .replace("{{DEVICE_ID}}", deviceId)
      .replace("{{HISTORY}}", JSON.stringify(history))
      .replace("{{QUERY}}", query);

    const text = await generateContentWithRetry(prompt);
    return text;
  } catch (error) {
    console.error("Gemini API Error (Chat):", error);
    return "I'm having trouble analyzing the data right now.";
  }
};

export const getVoiceAlert = async (deviceId: string, readings: any[], lang: string = 'en') => {
  // 1. Get the text explanation
  const explanationData = await getExplanation(deviceId, readings, lang);
  const text = explanationData.explanation;

  // 2. Convert to Audio URL
  const safeText = text.substring(0, 200); 
  
  const audioUrl = getAudioUrl(safeText, lang);

  return {
    text: safeText,
    audio_url: audioUrl
  };
};
