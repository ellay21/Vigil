import sqlite3 from 'sqlite3';
import { open, Database } from 'sqlite';

// Initialize database connection
let db: Database | null = null;

export const getDb = async () => {
  if (db) {
    return db;
  }

  db = await open({
    filename: './database.sqlite',
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      last_seen TEXT,
      current_state TEXT
    );

    CREATE TABLE IF NOT EXISTS readings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT,
      temperature REAL,
      voltage REAL,
      motionDetected INTEGER,
      vibrationDetected INTEGER,
      gasDetected INTEGER,
      state TEXT,
      timestamp TEXT,
      FOREIGN KEY(device_id) REFERENCES devices(id)
    );

    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phoneNumber TEXT UNIQUE,
      password TEXT
    );
  `);

  console.log('Database initialized');
  return db;
};

export const getDeviceHistory = async (deviceId: string, limit: number = 20) => {
  const db = await getDb();
  return db.all(
    'SELECT * FROM readings WHERE device_id = ? ORDER BY timestamp DESC LIMIT ?',
    [deviceId, limit]
  );
};

export const getAllDevicesStatus = async () => {
  const db = await getDb();
  return db.all('SELECT * FROM devices');
};

export const createUser = async (phoneNumber: string, password: string) => {
  const db = await getDb();
  try {
    await db.run('INSERT INTO users (phoneNumber, password) VALUES (?, ?)', [phoneNumber, password]);
    return true;
  } catch (e) {
    console.error('Error creating user:', e);
    return false;
  }
};

export const getUser = async (phoneNumber: string) => {
  const db = await getDb();
  return db.get('SELECT * FROM users WHERE phoneNumber = ?', [phoneNumber]);
};

export const getDeviceAnalytics = async (deviceId: string) => {
  const db = await getDb();
  
  // Get last 24 hours of data
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  
  const stats = await db.get(`
    SELECT 
      COUNT(*) as total_readings,
      SUM(CASE WHEN vibrationDetected = 1 THEN 1 ELSE 0 END) as active_readings,
      SUM(CASE WHEN state = 'WARNING' THEN 1 ELSE 0 END) as warning_count,
      SUM(CASE WHEN state = 'DANGER' THEN 1 ELSE 0 END) as danger_count
    FROM readings 
    WHERE device_id = ? AND timestamp > ?
  `, [deviceId, oneDayAgo]);

  // Calculate Efficiency (Uptime)
  const total = stats.total_readings || 1; 
  const active = stats.active_readings || 0;
  const efficiency = Math.round((active / total) * 100);

  // Calculate Health Score
  // Start at 100. Deduct for warnings and dangers.
  const warnings = stats.warning_count || 0;
  const dangers = stats.danger_count || 0;
  let health = 100 - (warnings * 2) - (dangers * 5);
  if (health < 0) health = 0;

  return {
    efficiency,
    health_score: health,
    total_readings: total,
    warnings,
    dangers
  };
};
