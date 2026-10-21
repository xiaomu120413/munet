/**
 * Port presets used by the port-scan page and LAN sweeps.
 */
export const COMMON_PORTS: number[] = [
  21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 465, 587,
  993, 995, 1433, 1521, 2049, 2181, 3000, 3306, 3389, 5432, 5900,
  6379, 7001, 8000, 8080, 8081, 8443, 9000, 9090, 9200, 11211, 27017
];

export const WEB_PORTS: number[] = [80, 443, 3000, 5000, 8000, 8080, 8443, 9000];

export const SWEEP_PORTS: number[] = [80, 443, 22, 445, 3389, 8080];

