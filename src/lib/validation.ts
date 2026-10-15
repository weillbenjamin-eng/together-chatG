import { z } from 'zod';
export const name = z.string().trim().min(1, 'Enter a name.').max(80);
export const contact = z.union([z.literal(''), z.email(), z.string().regex(/^\+[1-9]\d{7,14}$/, 'Use an email or an international phone number, e.g. +33123456789.')]);
export const friendInput = z.object({display_name:name,contact:contact.default('')});
export const tokenInput = z.string().regex(/^[a-f0-9]{64}$/);
export function safeNext(value: unknown) { return typeof value === 'string' && /^\/(?![/\\])/.test(value) && !/[\x00-\x1f\x7f]/.test(value) ? value : '/dashboard'; }
