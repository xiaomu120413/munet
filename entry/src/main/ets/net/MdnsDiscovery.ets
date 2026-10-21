import { mdns } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';

const SERVICE_TYPES: string[] = [
  '_http._tcp', '_https._tcp', '_ssh._tcp', '_smb._tcp', '_ipp._tcp',
  '_airplay._tcp', '_googlecast._tcp', '_device-info._tcp', '_workstation._tcp'
];

/**
 * Data source: best-effort mDNS hostname discovery. Discovered hostnames are
 * keyed by IPv4/IPv6 address and merged onto sweep results by the caller.
 */
export class MdnsSession {
  private services: mdns.DiscoveryService[] = [];
  private names: Map<string, string> = new Map<string, string>();

  start(context: common.Context): void {
    for (const type of SERVICE_TYPES) {
      try {
        const service: mdns.DiscoveryService = mdns.createDiscoveryService(context, type);
        service.on('serviceFound', (info: mdns.LocalServiceInfo) => {
          if (info.host !== undefined && info.host.address !== undefined &&
            info.host.address.length > 0 && info.serviceName.length > 0) {
            this.names.set(info.host.address, info.serviceName);
          }
        });
        service.startSearchingMDNS();
        this.services.push(service);
      } catch (err) {
        // Unsupported service type: ignore and keep the rest.
      }
    }
  }

  stop(): void {
    for (const service of this.services) {
      try {
        service.stopSearchingMDNS();
        service.off('serviceFound');
      } catch (err) {
      }
    }
    this.services = [];
  }

  hostnames(): Map<string, string> {
    return this.names;
  }
}
