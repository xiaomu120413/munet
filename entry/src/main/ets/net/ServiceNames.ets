/**
 * Well-known TCP service names for scan results (curated common-port table).
 */
const SERVICE_NAMES: Map<number, string> = new Map<number, string>([
  [21, 'ftp'], [22, 'ssh'], [23, 'telnet'], [25, 'smtp'], [53, 'dns'],
  [80, 'http'], [110, 'pop3'], [111, 'rpcbind'], [135, 'msrpc'],
  [139, 'netbios-ssn'], [143, 'imap'], [443, 'https'], [445, 'smb'],
  [465, 'smtps'], [587, 'submission'], [993, 'imaps'], [995, 'pop3s'],
  [1433, 'mssql'], [1521, 'oracle'], [2049, 'nfs'], [2181, 'zookeeper'],
  [3000, 'dev-ui'], [3306, 'mysql'], [3389, 'rdp'], [5432, 'postgres'],
  [5900, 'vnc'], [6379, 'redis'], [7001, 'weblogic'], [8000, 'http-alt'],
  [8080, 'http-proxy'], [8081, 'http-alt'], [8443, 'https-alt'],
  [9000, 'php-fpm'], [9090, 'http-alt'], [9200, 'elasticsearch'],
  [11211, 'memcached'], [27017, 'mongodb']
]);

/** Well-known service name for a port, or '' when unknown. */
export function serviceName(port: number): string {
  const name: string | undefined = SERVICE_NAMES.get(port);
  return name === undefined ? '' : name;
}
