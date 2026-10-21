import { IfaceInfo, NicInfo, WifiInfo } from '../model/NetworkInfo';
import { ClipboardRepository } from '../repository/ClipboardRepository';
import { LocalNetRepository } from '../repository/LocalNetRepository';

/**
 * ViewModel for the local-network view.
 *
 * Owns all page state, async orchestration (load), error handling and
 * display formatting. The view only reads these fields and forwards events.
 */
@Observed
export class LocalNetViewModel {
  isLoading: boolean = true;
  nics: NicInfo[] = [];
  wifi: WifiInfo | null = null;
  ifaces: IfaceInfo[] = [];
  error: string = '';

  isConnected: boolean = false;
  statusTitle: string = '';
  statusDetail: string = '';
  statusNote: string = '';

  private readonly repo: LocalNetRepository;
  private readonly clipboardRepo: ClipboardRepository;

  constructor(repo: LocalNetRepository = new LocalNetRepository(),
    clipboardRepo: ClipboardRepository = new ClipboardRepository()) {
    this.repo = repo;
    this.clipboardRepo = clipboardRepo;
  }

  async load(): Promise<void> {
    this.isLoading = true;
    this.error = '';
    try {
      const nics: NicInfo[] = await this.repo.fetchNics();
      this.nics = nics;
      this.ifaces = this.repo.readInterfaces();

      const defaultNic: NicInfo | undefined =
        nics.find((nic: NicInfo): boolean => nic.isDefault);
      if (defaultNic === undefined) {
        this.isConnected = false;
        this.statusTitle = '当前无网络连接';
        this.statusDetail = '';
        this.statusNote = '';
        this.wifi = null;
      } else {
        const bearer: string =
          defaultNic.bearerTypes.length > 0 ? defaultNic.bearerTypes.join(' · ') : '未知网络';
        this.isConnected = true;
        this.statusTitle = bearer + ' · ' + defaultNic.interfaceName;
        this.statusDetail = this.primaryAddress(defaultNic);
        this.statusNote = defaultNic.gateway.length > 0 ? '网关 ' + defaultNic.gateway : '';
        this.wifi = defaultNic.bearerTypes.includes('Wi-Fi')
          ? await this.repo.fetchWifiInfo()
          : null;
      }
    } catch (err) {
      this.error = '读取网络信息失败，请稍后重试';
    }
    this.isLoading = false;
  }

  dismissError(): void {
    this.error = '';
  }

  async copy(address: string): Promise<boolean> {
    return this.clipboardRepo.copy(address);
  }

  primaryAddress(nic: NicInfo): string {
    for (const addr of nic.linkAddresses) {
      if (addr.family === 'v4') {
        return addr.address;
      }
    }
    return nic.linkAddresses.length > 0 ? nic.linkAddresses[0].address : '';
  }

  bandLabel(band: number): string {
    if (band === 1) {
      return '2.4 GHz';
    }
    if (band === 2) {
      return '5 GHz';
    }
    return band > 0 ? '频段 ' + band : '—';
  }
}
