import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import jwt from 'jsonwebtoken';
import { getDb, getDeviceHistory, getAllDevicesStatus, createUser, getUser, getDeviceAnalytics } from './db';
import { DeviceDataSchema, UserSchema } from './types';
import { getRiskAssessment, getExplanation, getMaintenanceInsight, getSystemSummary, getVoiceAlert, getChatResponse } from './gemini';

const app = express();
const PORT = Number(process.env.PORT) || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Auth Middleware
const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.status(401).json({ error: 'Access denied. No token provided.' });
    return;
  }

  jwt.verify(token, JWT_SECRET, (err: any, user: any) => {
    if (err) {
      res.status(403).json({ error: 'Invalid token.' });
      return;
    }
    (req as any).user = user;
    next();
  });
};

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok' });
});

// --- Auth Endpoints ---

app.post('/api/register', async (req: Request, res: Response) => {
  const validation = UserSchema.safeParse(req.body);
  if (!validation.success) {
    res.status(400).json({ error: 'Invalid input', details: validation.error.errors });
    return;
  }
  const { phoneNumber, password } = validation.data;
  const success = await createUser(phoneNumber, password);
  if (success) {
    res.status(201).json({ message: 'User registered successfully' });
  } else {
    res.status(400).json({ error: 'User already exists or invalid data' });
  }
});

app.post('/api/login', async (req: Request, res: Response) => {
  const validation = UserSchema.safeParse(req.body);
  if (!validation.success) {
    res.status(400).json({ error: 'Invalid input', details: validation.error.errors });
    return;
  }
  const { phoneNumber, password } = validation.data;
  const user = await getUser(phoneNumber);
  if (user && user.password === password) {
    const token = jwt.sign({ phoneNumber: user.phoneNumber }, JWT_SECRET, { expiresIn: '1h' });
    res.status(200).json({ message: 'Login successful', token, user: { phoneNumber: user.phoneNumber } });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

// --- Device Data Endpoints ---

// Device data ingestion endpoint
app.post('/api/device/data', async (req: Request, res: Response) => {
  try {
    // Validate payload
    const validationResult = DeviceDataSchema.safeParse(req.body);

    if (!validationResult.success) {
      res.status(400).json({ error: 'Invalid payload', details: validationResult.error.errors });
      return;
    }

    const data = validationResult.data;
    const db = await getDb();
    
    // Use provided timestamp or current server time
    const timestamp = data.timestamp || new Date().toISOString();

    // Use provided device_id or generate a default one (e.g., "UNKNOWN-DEVICE")
    // In a real scenario, you might generate a UUID, but for a prototype, a default is fine
    // or you could generate one based on IP, but that's unreliable for GSM.
    // Let's use a default if missing, but warn about it.
    const deviceId = data.device_id || "UNKNOWN-DEVICE";

    // Upsert device metadata
    await db.run(`
      INSERT INTO devices (id, last_seen, current_state)
      VALUES (?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        last_seen = excluded.last_seen,
        current_state = excluded.current_state
    `, [deviceId, timestamp, data.state]);

    // Store reading
    await db.run(`
      INSERT INTO readings (device_id, temperature, voltage, motionDetected, vibrationDetected, gasDetected, state, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [deviceId, data.temperature, data.voltage, data.motionDetected ? 1 : 0, data.vibrationDetected ? 1 : 0, data.gasDetected ? 1 : 0, data.state, timestamp]);

    console.log(`Received data from ${deviceId}: ${data.state}`);
    res.status(200).json({ message: 'Data received successfully', device_id: deviceId });

  } catch (error) {
    console.error('Error processing request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Fetch latest status per device
app.get('/api/device/:id/status', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const db = await getDb();
    const device = await db.get('SELECT * FROM devices WHERE id = ?', [id]);
    
    if (!device) {
      res.status(404).json({ error: 'Device not found' });
      return;
    }

    const latestReading = await db.get('SELECT * FROM readings WHERE device_id = ? ORDER BY timestamp DESC LIMIT 1', [id]);
    
    res.status(200).json({ device, latest_reading: latestReading });
  } catch (error) {
    console.error('Error fetching device status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get Device Analytics (Efficiency & Health)
app.get('/api/device/:id/analytics', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const analytics = await getDeviceAnalytics(id);
    res.status(200).json(analytics);
  } catch (error) {
    console.error('Error fetching analytics:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// AI Chatbot Endpoint
app.post('/api/chat', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { deviceId, query } = req.body;
    if (!deviceId || !query) {
      res.status(400).json({ error: 'Missing deviceId or query' });
      return;
    }

    // Fetch recent history to give context to the AI
    const history = await getDeviceHistory(deviceId, 10);
    const answer = await getChatResponse(deviceId, history, query);
    
    res.status(200).json({ answer });
  } catch (error) {
    console.error('Error in chat endpoint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Fetch historical data for charts
app.get('/api/device/:id/history', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit as string) || 20;
    const history = await getDeviceHistory(id, limit);
    res.status(200).json(history);
  } catch (error) {
    console.error('Error fetching history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// --- AI Features ---

// 1. AI Risk Level Prediction
app.get('/api/device/:id/risk', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const lang = req.query.lang as string || 'en';
    const history = await getDeviceHistory(id, 15); // Fetch last 15 readings
    
    if (history.length === 0) {
      res.status(404).json({ error: 'No data available for this device' });
      return;
    }

    const riskAnalysis = await getRiskAssessment(history, lang);
    res.status(200).json({ device_id: id, ...riskAnalysis });
  } catch (error) {
    console.error('Error generating risk assessment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 2. AI-Generated Explanation
app.get('/api/device/:id/explanation', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const lang = req.query.lang as string || 'en';
    const history = await getDeviceHistory(id, 10);
    
    if (history.length === 0) {
      res.status(404).json({ error: 'No data available for this device' });
      return;
    }

    const explanation = await getExplanation(id, history, lang);
    res.status(200).json(explanation);
  } catch (error) {
    console.error('Error generating explanation:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 2.5 AI Voice Alert
app.get('/api/device/:id/voice', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const lang = req.query.lang as string || 'en';
    const history = await getDeviceHistory(id, 10);
    
    if (history.length === 0) {
      res.status(404).json({ error: 'No data available for this device' });
      return;
    }

    const voiceAlert = await getVoiceAlert(id, history, lang);
    res.status(200).json(voiceAlert);
  } catch (error) {
    console.error('Error generating voice alert:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 3. Predictive Maintenance Insight
app.get('/api/device/:id/maintenance', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const lang = req.query.lang as string || 'en';
    const history = await getDeviceHistory(id, 50); // Analyze larger history
    
    if (history.length === 0) {
      res.status(404).json({ error: 'No data available for this device' });
      return;
    }

    const maintenance = await getMaintenanceInsight(id, history, lang);
    res.status(200).json(maintenance);
  } catch (error) {
    console.error('Error generating maintenance insight:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// List all devices
app.get('/api/devices', authenticateToken, async (req: Request, res: Response) => {
  try {
    const devices = await getAllDevicesStatus();
    res.status(200).json(devices);
  } catch (error) {
    console.error('Error fetching devices:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 4. AI System Summary
app.get('/api/summary', authenticateToken, async (req: Request, res: Response) => {
  try {
    const lang = req.query.lang as string || 'en';
    const devices = await getAllDevicesStatus();
    const summary = await getSystemSummary(devices, lang);
    res.status(200).json(summary);
  } catch (error) {
    console.error('Error generating system summary:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// Start server
const startServer = async () => {
  try {
    await getDb(); // Initialize DB
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on port ${PORT} (accessible via 0.0.0.0)`);
      // Initial sync
      fetchThingSpeakData();
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

// --- ThingSpeak Integration ---
const THINGSPEAK_CHANNEL_ID = '3212266';
const THINGSPEAK_READ_KEY = 'J0XVP2JVP2WUD5IG';
const THINGSPEAK_URL = `https://api.thingspeak.com/channels/${THINGSPEAK_CHANNEL_ID}/feeds.json?api_key=${THINGSPEAK_READ_KEY}&results=1`;

const fetchThingSpeakData = async () => {
  try {
    // @ts-ignore - fetch is available in Node 18+
    const response = await fetch(THINGSPEAK_URL);
    const data = await response.json();
    
    if (data.feeds && data.feeds.length > 0) {
      const feed = data.feeds[0];
      const db = await getDb();
      
      // Map fields
      // field1: Gas, field2: Temp, field3: Vibration, field4: Voltage, field5: Motion, field6: Alert
      const gasVal = parseFloat(feed.field1 || '0');
      const temp = parseFloat(feed.field2 || '0');
      const vibration = parseInt(feed.field3 || '0');
      const voltage = parseFloat(feed.field4 || '0');
      const motion = parseInt(feed.field5 || '0');
      const alertVal = parseInt(feed.field6 || '0');
      
      const deviceId = 'IND-MACHINE-01'; // Default device ID
      const timestamp = new Date(feed.created_at).toISOString();
      
      // Determine State
      let state = 'SAFE';
      if (alertVal === 1) state = 'WARNING';
      if (alertVal > 1) state = 'DANGER';
      
      // Check if this entry already exists to avoid duplicates
      const existing = await db.get('SELECT * FROM readings WHERE device_id = ? AND timestamp = ?', [deviceId, timestamp]);
      
      if (!existing) {
        // Upsert device
        await db.run(`
          INSERT INTO devices (id, last_seen, current_state)
          VALUES (?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            last_seen = excluded.last_seen,
            current_state = excluded.current_state
        `, [deviceId, timestamp, state]);

        // Insert reading
        await db.run(`
          INSERT INTO readings (device_id, temperature, voltage, motionDetected, vibrationDetected, gasDetected, state, timestamp)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [deviceId, temp, voltage, motion, vibration, gasVal > 200 ? 1 : 0, state, timestamp]);
        
        console.log(`[ThingSpeak] Synced data for ${deviceId} at ${timestamp}`);
      }
    }
  } catch (error) {
    console.error('[ThingSpeak] Sync Error:', error);
  }
};

// Start Polling (every 10 seconds)
setInterval(fetchThingSpeakData, 10000);
