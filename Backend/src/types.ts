import { z } from 'zod';

export const DeviceDataSchema = z.object({
  device_id: z.string().min(1).optional(), // Optional: Server will assign if missing
  temperature: z.number(),
  voltage: z.number(),
  motionDetected: z.boolean(),
  vibrationDetected: z.boolean(),
  gasDetected: z.boolean(),
  state: z.string(), // Could be an enum if states are known, but string is safer for now
  timestamp: z.string().datetime().optional() // Optional: Server will assign if missing
});

export const UserSchema = z.object({
  phoneNumber: z.string().min(10),
  password: z.string().min(6)
});

export type DeviceData = z.infer<typeof DeviceDataSchema>;
export type User = z.infer<typeof UserSchema>;
