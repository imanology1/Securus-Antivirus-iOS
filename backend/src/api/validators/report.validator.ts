import { z } from 'zod';
import { ThreatType, Severity } from '../../models';
import { ValidationError } from '../../errors/AppError';

// PII detection patterns
const EMAIL_PATTERN = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/;
const PHONE_PATTERN = /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/;
const SSN_PATTERN = /\b\d{3}-\d{2}-\d{4}\b/;
const IP_V4_PATTERN = /\b(?:\d{1,3}\.){3}\d{1,3}\b/;

function containsPII(value: unknown): boolean {
  const str = typeof value === 'string' ? value : JSON.stringify(value);

  if (EMAIL_PATTERN.test(str)) return true;
  if (PHONE_PATTERN.test(str)) return true;
  if (SSN_PATTERN.test(str)) return true;
  if (IP_V4_PATTERN.test(str)) return true;

  return false;
}

function deepCheckPII(obj: unknown, path: string = ''): string[] {
  const violations: string[] = [];

  if (typeof obj === 'string') {
    if (containsPII(obj)) {
      violations.push(`PII detected at ${path || 'value'}`);
    }
  } else if (Array.isArray(obj)) {
    obj.forEach((item, index) => {
      violations.push(...deepCheckPII(item, `${path}[${index}]`));
    });
  } else if (obj !== null && typeof obj === 'object') {
    for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
      // Reject fields with PII-suggestive names
      const piiFieldNames = [
        'email', 'phone', 'name', 'address', 'ssn',
        'social_security', 'first_name', 'last_name',
        'phone_number', 'ip_address', 'user_name',
        'full_name', 'date_of_birth', 'dob',
      ];
      if (piiFieldNames.includes(key.toLowerCase())) {
        violations.push(`PII field name detected: ${path ? path + '.' : ''}${key}`);
      }
      violations.push(...deepCheckPII(value, `${path ? path + '.' : ''}${key}`));
    }
  }

  return violations;
}

export const threatReportSchema = z.object({
  threat_id: z
    .string()
    .min(1, 'threat_id is required')
    .max(255, 'threat_id must be 255 characters or fewer'),

  threat_type: z.nativeEnum(ThreatType, {
    errorMap: () => ({
      message: `threat_type must be one of: ${Object.values(ThreatType).join(', ')}`,
    }),
  }),

  severity: z.nativeEnum(Severity, {
    errorMap: () => ({
      message: `severity must be one of: ${Object.values(Severity).join(', ')}`,
    }),
  }),

  metadata: z
    .record(z.unknown())
    .default({}),

  app_token: z
    .string()
    .min(1, 'app_token is required')
    .max(512, 'app_token must be 512 characters or fewer'),

  sdk_version: z
    .string()
    .min(1, 'sdk_version is required')
    .max(50, 'sdk_version must be 50 characters or fewer'),

  os_version: z
    .string()
    .min(1, 'os_version is required')
    .max(50, 'os_version must be 50 characters or fewer'),
});

export type ThreatReportInput = z.infer<typeof threatReportSchema>;

export function validateThreatReport(data: unknown): ThreatReportInput {
  const parsed = threatReportSchema.parse(data);

  // Deep PII check across the entire payload
  const piiViolations = deepCheckPII(parsed);

  if (piiViolations.length > 0) {
    throw new ValidationError(
      'Payload contains personally identifiable information (PII), which is not allowed',
      piiViolations
    );
  }

  return parsed;
}
