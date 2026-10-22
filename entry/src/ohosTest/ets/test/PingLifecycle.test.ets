import { describe, expect, it } from '@ohos/hypium';
import { LocalNetRepository } from '../../../main/ets/repository/LocalNetRepository';
import { PingViewModel } from '../../../main/ets/viewmodel/PingViewModel';
import { ScanRepository } from '../../../main/ets/repository/ScanRepository';

class DeferredDns extends LocalNetRepository {
  calls: number = 0;
  finish: (address: string) => void = () => {};
  async resolveAddress(host: string): Promise<string> {
    this.calls++;
    return new Promise<string>((resolve: (address: string) => void) => { this.finish = resolve; });
  }
}

export default function pingLifecycleTest() {
  describe('PingLifecycle', () => {
    it('resolvingLocksStartAndStopPreventsLateResult', 0, async () => {
      const dns: DeferredDns = new DeferredDns();
      const vm: PingViewModel = new PingViewModel(new ScanRepository(), dns);
      vm.setTarget('example.test');
      const pending: Promise<void> = vm.start();
      expect(vm.isRunning).assertTrue();
      await vm.start();
      expect(dns.calls).assertEqual(1);
      vm.stop();
      dns.finish('127.0.0.1');
      await pending;
      expect(vm.isRunning).assertFalse();
      expect(vm.resolvedAddress).assertEqual('');
      expect(vm.records.length).assertEqual(0);
    });
  });
}
