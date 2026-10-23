import { describe, expect, it } from '@ohos/hypium';
import { IfaceInfo, NicInfo, WifiInfo } from '../../../main/ets/model/NetworkInfo';
import { LocalNetRepository } from '../../../main/ets/repository/LocalNetRepository';
import { LocalNetViewModel } from '../../../main/ets/viewmodel/LocalNetViewModel';

class FakeLocalNetRepository extends LocalNetRepository {
  calls: number = 0;
  address: string = '192.168.1.2';
  failNetwork: boolean = false;
  failWifi: boolean = false;
  async fetchNics(): Promise<NicInfo[]> {
    this.calls++;
    if (this.failNetwork) { throw new Error('network unavailable'); }
    return [{ netId: 1, interfaceName: 'wlan0', bearerTypes: ['Wi-Fi'], isDefault: true,
      linkAddresses: [{ address: this.address, prefixLength: 24, family: 'v4' }],
      gateway: '192.168.1.1', dns: ['192.168.1.1'], domains: '', mtu: 1500,
      ipv4Valid: true, ipv6Valid: false }];
  }
  readInterfaces(): IfaceInfo[] {
    return [{ name: 'wlan0', address: this.address, family: 'v4', prefixLength: 24,
      loopback: false, up: true }];
  }
  async fetchWifiInfo(): Promise<WifiInfo | null> {
    if (this.failWifi) { throw new Error('wifi unavailable'); }
    return { ssid: 'Test', rssi: -40, band: 2, frequency: 5765, linkSpeed: 286 };
  }
}

class DeferredWifiRepository extends FakeLocalNetRepository {
  defer: boolean = false;
  waiting: boolean = false;
  finish: (wifi: WifiInfo | null) => void = () => {};
  async fetchWifiInfo(): Promise<WifiInfo | null> {
    if (!this.defer) { return super.fetchWifiInfo(); }
    this.waiting = true;
    return new Promise<WifiInfo | null>((resolve: (wifi: WifiInfo | null) => void) => { this.finish = resolve; });
  }
}

export default function localNetViewModelTest() {
  describe('LocalNetViewModelRefresh', () => {
    it('refreshKeepsCoherentSnapshotUntilWifiCompletes', 0, async () => {
      const repo: DeferredWifiRepository = new DeferredWifiRepository();
      const vm: LocalNetViewModel = new LocalNetViewModel(repo);
      await vm.load();
      repo.address = '192.168.1.3';
      repo.defer = true;
      const refresh: Promise<void> = vm.load();
      await Promise.resolve();
      expect(repo.waiting).assertTrue();
      expect(vm.isLoading).assertTrue();
      expect((vm.wifi as WifiInfo).ssid).assertEqual('Test');
      expect(vm.statusDetail).assertEqual('192.168.1.2');
      expect(vm.nics[0].linkAddresses[0].address).assertEqual('192.168.1.2');
      expect(vm.ifaces[0].address).assertEqual('192.168.1.2');
      repo.finish({ ssid: 'Updated', rssi: -42, band: 2, frequency: 5765, linkSpeed: 286 });
      await refresh;
      expect((vm.wifi as WifiInfo).ssid).assertEqual('Updated');
      expect(vm.statusDetail).assertEqual('192.168.1.3');
      expect(vm.ifaces[0].address).assertEqual('192.168.1.3');
      expect(vm.isLoading).assertFalse();
    });
    it('wifiFailurePreservesUsableNetworkData', 0, async () => {
      const repo: FakeLocalNetRepository = new FakeLocalNetRepository();
      repo.failWifi = true;
      const vm: LocalNetViewModel = new LocalNetViewModel(repo);
      await vm.load();
      expect(vm.nics.length).assertEqual(1);
      expect(vm.ifaces.length).assertEqual(1);
      expect(vm.statusDetail).assertEqual('192.168.1.2');
      expect(vm.wifi === null).assertTrue();
      expect(vm.error.length > 0).assertTrue();
      expect(vm.isLoading).assertFalse();
      expect(vm.hasLoaded).assertTrue();
    });
    it('failedRefreshKeepsPreviousDataAndCanRetry', 0, async () => {
      const repo: FakeLocalNetRepository = new FakeLocalNetRepository();
      const vm: LocalNetViewModel = new LocalNetViewModel(repo);
      await vm.load();
      repo.failNetwork = true;
      await vm.load();
      expect(vm.nics.length).assertEqual(1);
      expect(vm.statusDetail).assertEqual('192.168.1.2');
      expect(vm.isLoading).assertFalse();
      repo.failNetwork = false;
      await vm.load();
      expect(vm.error).assertEqual('');
      expect(repo.calls).assertEqual(3);
    });
    it('duplicateRefreshDoesNotRaceRequests', 0, async () => {
      const repo: FakeLocalNetRepository = new FakeLocalNetRepository();
      const vm: LocalNetViewModel = new LocalNetViewModel(repo);
      await Promise.all([vm.load(), vm.load()]);
      expect(repo.calls).assertEqual(1);
      expect(vm.isLoading).assertFalse();
    });
  });
}
