/** Normalises a Vietnamese phone number to the local 0XXXXXXXXX form. */
export function normalizePhone(value: string): string {
  const compact = value.replace(/[\s.-]/g, '');
  return compact.startsWith('+84') ? `0${compact.slice(3)}` : compact;
}

export function isValidPhone(value: string): boolean {
  return /^0\d{9}$/.test(normalizePhone(value));
}

export function isValidEmail(value: string): boolean {
  return /^[\w.+-]+@[\w-]+(\.[\w-]+)+$/.test(value.trim());
}
