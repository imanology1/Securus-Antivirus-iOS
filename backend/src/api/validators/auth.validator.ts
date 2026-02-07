import { z } from 'zod';

export const registerSchema = z.object({
  email: z
    .string()
    .email('Must be a valid email address')
    .max(255, 'Email must be 255 characters or fewer')
    .transform((val) => val.toLowerCase().trim()),

  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password must be 128 characters or fewer')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one lowercase letter, one uppercase letter, and one digit'
    ),

  company_name: z
    .string()
    .min(1, 'Company name is required')
    .max(255, 'Company name must be 255 characters or fewer')
    .trim(),
});

export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z
    .string()
    .email('Must be a valid email address')
    .transform((val) => val.toLowerCase().trim()),

  password: z
    .string()
    .min(1, 'Password is required'),
});

export type LoginInput = z.infer<typeof loginSchema>;
