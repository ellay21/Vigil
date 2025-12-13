import { getDb } from './db';

const DEVICES_COUNT = 15;
const READINGS_PER_DEVICE = 50; // Last 50 readings
const DEVICE_PREFIX = 'IND-MACHINE-';

const generateRandomReading = (deviceId: string, index: number, isFaulty: boolean) => {
  const timestamp = new Date(Date.now() - index * 15 * 60 * 1000).toISOString(); // Every 15 mins
  
  let voltage = 220 + (Math.random() * 10 - 5); // 215-225V
  let temp = 45 + (Math.random() * 10 - 5); // 40-50C
  let vibration = Math.random() > 0.8 ? 1 : 0;
  let gas = Math.random() * 50;
  let motion = Math.random() > 0.5 ? 1 : 0;
  let state = 'SAFE';

  if (isFaulty) {
    // Simulate specific faults based on device ID to make them distinct
    if (deviceId.includes('09')) {
      // Gas Leak
      gas = 200 + Math.random() * 100;
      state = 'DANGER';
    } else if (deviceId.includes('06')) {
      // Overheating
      temp = 85 + Math.random() * 15;
      state = 'WARNING';
    } else if (deviceId.includes('07')) {
      // Voltage Spike
      voltage = 250 + Math.random() * 20;
      state = 'WARNING';
    }
  }

  return {
    device_id: deviceId,
    temperature: parseFloat(temp.toFixed(2)),
    voltage: parseFloat(voltage.toFixed(2)),
    motionDetected: motion,
    vibrationDetected: vibration,
    gasDetected: gas > 200 ? 1 : 0,
    state,
    timestamp
  };
};

const seed = async () => {
  const db = await getDb();
  console.log('Seeding large scale data...');

  // Clear existing simulated devices (Keep 01 as it's the real one)
  await db.run("DELETE FROM devices WHERE id != 'IND-MACHINE-01'");
  await db.run("DELETE FROM readings WHERE device_id != 'IND-MACHINE-01'");

  for (let i = 2; i <= DEVICES_COUNT; i++) {
    const id = `${DEVICE_PREFIX}${i.toString().padStart(2, '0')}`;
    const isFaulty = [6, 7, 9, 12].includes(i); // Specific faulty machines
    
    // Create Device
    await db.run(`
      INSERT INTO devices (id, last_seen, current_state)
      VALUES (?, ?, ?)
    `, [id, new Date().toISOString(), isFaulty ? (i === 9 ? 'DANGER' : 'WARNING') : 'SAFE']);

    // Create Readings
    for (let j = 0; j < READINGS_PER_DEVICE; j++) {
      const r = generateRandomReading(id, j, isFaulty);
      await db.run(`
        INSERT INTO readings (device_id, temperature, voltage, motionDetected, vibrationDetected, gasDetected, state, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [r.device_id, r.temperature, r.voltage, r.motionDetected, r.vibrationDetected, r.gasDetected, r.state, r.timestamp]);
    }
    console.log(`Seeded ${id}`);
  }

  console.log('Large scale seeding complete!');
};

seed();
