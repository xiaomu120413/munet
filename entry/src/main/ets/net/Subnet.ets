/**
 * Pure IPv4 subnet helpers (data source layer; no UI dependencies).
 */

/** Network address of `address/prefixLength`, e.g. 192.168.1.23/24 -> 192.168.1.0/24. */
export function deriveCidr(address: string, prefixLength: number): string {
  const parts: string[] = address.split('.');
  if (parts.length !== 4 || prefixLength < 0 || prefixLength > 32) {
    return '';
  }
  let value: number = 0;
  for (const part of parts) {
    const octet: number = Number(part);
    if (Number.isNaN(octet) || octet < 0 || octet > 255) {
      return '';
    }
    value = value * 256 + octet;
  }
  const block: number = Math.pow(2, 32 - prefixLength);
  const network: number = Math.floor(value / block) * block;
  const a: number = Math.floor(network / 16777216) % 256;
  const b: number = Math.floor(network / 65536) % 256;
  const c: number = Math.floor(network / 256) % 256;
  const d: number = network % 256;
  return a + '.' + b + '.' + c + '.' + d + '/' + prefixLength;
}

/** Usable host count for a CIDR string; 0 when invalid or above 65536. */
export function hostCountForCidr(cidr: string): number {
  const slash: number = cidr.indexOf('/');
  if (slash <= 0) {
    return 0;
  }
  const prefix: number = Number(cidr.substring(slash + 1));
  if (Number.isNaN(prefix) || prefix < 1 || prefix > 32) {
    return 0;
  }
  if (prefix === 32) {
    return 1;
  }
  if (prefix === 31) {
    return 2;
  }
  const count: number = Math.pow(2, 32 - prefix) - 2;
  return count > 65536 ? 0 : count;
}
