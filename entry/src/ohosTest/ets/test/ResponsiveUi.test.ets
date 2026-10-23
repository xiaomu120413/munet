import { beforeAll, afterAll, afterEach, describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { socket } from '@kit.NetworkKit';
import { Driver, ON, Component, DisplayRotation, Point } from '@ohos.UiTest';

// Explicit opt-in: aa test ... -s uiAcceptance 1 -s timeout 240000.
// Exercises real ArkUI and native TCP on loopback; never clears the user's database.
export default function responsiveUiTest() {
  const params: Record<string, string> = abilityDelegatorRegistry.getArguments().parameters;
  if (params['uiAcceptance'] !== '1' && params['-s uiAcceptance'] !== '1') { return; }
  describe('ResponsiveUi', () => {
    const driver: Driver = Driver.create();
    let originalRotation: DisplayRotation = DisplayRotation.ROTATION_0;
    // Pass rotationEnabled=0 when the device was locked before this opt-in run.
    const restoreRotationEnabled: boolean = (params['-s rotationEnabled'] ?? params['rotationEnabled']) !== '0';
    const server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
    let listening: boolean = false;
    const shape = async (landscape: boolean): Promise<void> => {
      // Tablet panels may have landscape as their natural rotation 0.
      for (const rotation of [DisplayRotation.ROTATION_0, DisplayRotation.ROTATION_90]) {
        await driver.setDisplayRotation(rotation);
        await driver.delayMs(1600);
        const size: Point = await driver.getDisplaySize();
        await abilityDelegatorRegistry.getAbilityDelegator().print('orientation landscape=' + landscape +
          ' actual=' + size.x + 'x' + size.y + ' rotation=' + await driver.getDisplayRotation());
        if ((size.x > size.y) === landscape) { return; }
      }
      throw new Error('Device did not reach requested screen shape');
    };
    const component = async (id: string): Promise<Component> => {
      const found: Component = await driver.waitForComponent(ON.id(id).inWindow('com.munet.app'), 5000);
      if (found === null) { throw new Error('Missing application control: ' + id); }
      return found;
    };
    const click = async (id: string): Promise<void> => { await (await component(id)).click(); };
    const capture = async (name: string): Promise<void> => {
      await driver.delayMs(500);
      const cacheDir: string = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir;
      expect(await driver.screenCap(cacheDir + '/munet-' + name + '.png')).assertTrue();
    };
    const navigate = async (index: number): Promise<void> => {
      const nav: Component = await driver.findComponent(ON.id('nav-' + index).inWindow('com.munet.app'));
      if (nav !== null) { await nav.click(); return; }
      await click('bottom-nav-' + (index === 4 ? 2 : index === 5 ? 3 : 1));
      if (index >= 1 && index <= 3) {
        await (await driver.waitForComponent(ON.text(index === 1 ? 'Ping' : index === 2 ? '端口扫描' : '局域网')
          .inWindow('com.munet.app'), 4000)).click();
      }
    };
    beforeAll(async () => {
      originalRotation = await driver.getDisplayRotation();
      await driver.setDisplayRotationEnabled(false);
      server.on('connect', (connection: socket.TCPSocketConnection) => {
        connection.close().catch(() => {});
      });
      await server.listen({ address: '127.0.0.1', port: 8080, family: 1 });
      listening = true;
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
        bundleName: 'com.munet.app', moduleName: 'entry', abilityName: 'EntryAbility'
      });
      await driver.delayMs(800);
      await component('app-shell');
      await shape(true);
    });
    afterAll(async () => {
      await driver.setDisplayRotation(originalRotation);
      await driver.setDisplayRotationEnabled(restoreRotationEnabled);
      if (listening) { await server.close(); }
    });
    afterEach(async () => {
      const start: Component = await driver.findComponent(ON.id('ping-start').inWindow('com.munet.app'));
      if (start !== null && await start.getText() === '停止') {
        await start.click();
        await driver.waitForComponent(ON.id('ping-start').text('开始'), 6000);
      }
      await driver.setDisplayRotation(originalRotation);
    });
    it('rotationKeepsRunningPingAndTarget', 0, async () => {
      await shape(true);
      await navigate(1);
      await (await component('ping-target')).inputText('127.0.0.1');
      await driver.pressBack();
      await click('ping-continuous');
      await click('ping-start');
      await driver.delayMs(2200);
      expect(await (await component('ping-target')).isEnabled()).assertFalse();
      const before: string = await (await component('ping-summary')).getText();
      await capture('tablet-landscape-ping-running');
      await shape(false);
      expect(await (await component('ping-target')).getText()).assertEqual('127.0.0.1');
      expect(await (await component('ping-start')).getText()).assertEqual('停止');
      const after: string = await (await component('ping-summary')).getText();
      expect(Number(after.split(/\s+/)[1]) >= Number(before.split(/\s+/)[1])).assertTrue();
      await capture('tablet-portrait-ping-running');
      await click('ping-start');
      await driver.waitForComponent(ON.id('ping-start').text('开始').inWindow('com.munet.app'), 6000);
      await shape(true);
      expect(await (await component('ping-target')).getText()).assertEqual('127.0.0.1');
    });
    it('nativeResultsPopulatePortAndLanTables', 0, async () => {
      await shape(true);
      await navigate(2);
      await (await component('port-target')).inputText('127.0.0.1');
      await driver.pressBack();
      await click('port-start');
      await driver.waitForComponent(ON.id('port-start').text('开始扫描').inWindow('com.munet.app'), 10000);
      await driver.assertComponentExist(ON.text('8080').inWindow('com.munet.app'));
      await capture('tablet-landscape-port-results');
      await navigate(3);
      await (await component('lan-cidr')).inputText('127.0.0.1/32');
      await driver.pressBack();
      await click('lan-start');
      await driver.waitForComponent(ON.id('lan-start').text('开始发现').inWindow('com.munet.app'), 10000);
      await driver.assertComponentExist(ON.text('127.0.0.1').inWindow('com.munet.app'));
      await capture('tablet-landscape-lan-results');
    });
    it('historyMenusAndArchiveKeepDataOnCancel', 0, async () => {
      await shape(true);
      await navigate(4);
      await driver.delayMs(600);
      await capture('tablet-landscape-records');
      await click('history-export');
      await driver.assertComponentExist(ON.text('导出全部扫描记录 · JSON'));
      await capture('tablet-export-menu');
      await driver.pressBack();
      await click('history-hosts');
      await driver.assertComponentExist(ON.text('127.0.0.1').inWindow('com.munet.app'));
      expect(await driver.findComponent(ON.id('history-export')) === null).assertTrue();
      expect(await driver.findComponent(ON.id('history-filter')) === null).assertTrue();
      await capture('tablet-landscape-hosts');
      await click('history-more');
      await (await driver.waitForComponent(ON.text('清空全部记录与档案'), 3000)).click();
      await driver.assertComponentExist(ON.text('清空全部记录与档案？'));
      await capture('tablet-clear-confirm');
      await (await driver.waitForComponent(ON.text('取消'), 3000)).click();
      await driver.assertComponentExist(ON.text('127.0.0.1').inWindow('com.munet.app'));
      await shape(false);
      expect(await driver.findComponent(ON.id('history-filter')) === null).assertTrue();
      await capture('tablet-portrait-hosts');
      await shape(true);
      await navigate(5);
      await capture('tablet-landscape-about');
    });
  });
}
