import { getDb } from './db';

const generateRandomData = (deviceId: string, count: number) => {
  const data = [];
  const now = new Date();

  for (let i = 0; i < count; i++) {
    const time = new Date(now.getTime() - i * 15 * 60 * 1000); 
    const temperature = 45 + Math.random() * 10 - 5; 
    
    const voltage = 220 + Math.random() * 10 - 5;

    const motionDetected = Math.random() > 0.95;
    const vibrationDetected = Math.random() > 0.95;
    const gasDetected = Math.random() > 0.98; 

    let state = "ACTIVE";
    if (gasDetected || temperature > 53 || voltage > 228 || voltage < 212) {
      state = "DANGER";
    } else if (vibrationDetected) {
      state = "WARNING";
    }

    data.push({
      device_id: deviceId,
      temperature: parseFloat(temperature.toFixed(1)),
      voltage: parseFloat(voltage.toFixed(1)),
      motionDetected: motionDetected ? 1 : 0,
      vibrationDetected: vibrationDetected ? 1 : 0,
      gasDetected: gasDetected ? 1 : 0,
      state,
      timestamp: time.toISOString()
    });
  }
  return data;
};

const seed = async () => {
  const db = await getDb();
  const deviceId = "IND-MACHINE-01";

  console.log(`Seeding data for ${deviceId}...`);

  await db.run('DELETE FROM readings WHERE device_id = ?', [deviceId]);
  await db.run('DELETE FROM devices WHERE id = ?', [deviceId]);

  await db.run(`
    INSERT INTO devices (id, last_seen, current_state)
    VALUES (?, ?, ?)
  `, [deviceId, new Date().toISOString(), "ACTIVE"]);

  const readings = generateRandomData(deviceId, 100);

  for (const r of readings) {
    await db.run(`
      INSERT INTO readings (device_id, temperature, voltage, motionDetected, vibrationDetected, gasDetected, state, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [r.device_id, r.temperature, r.voltage, r.motionDetected, r.vibrationDetected, r.gasDetected, r.state, r.timestamp]);
  }

  console.log("Seeding complete!");
};

seed().catch(console.error);
