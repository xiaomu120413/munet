import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { display } from '@kit.ArkUI';
import { socket } from '@kit.NetworkKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { Driver, ON, Component, DisplayRotation, Point, Rect, MatchPattern, UiWindow, WindowMode } from '@ohos.UiTest';

// Opt in on a phone/tablet only. Real loopback traffic; preserve stored user data.
export default function touchUiTest() {
  const params: Record<string, string> = abilityDelegatorRegistry.getArguments().parameters;
  if ((params['-s touchAcceptance'] ?? params['touchAcceptance']) !== '1') { return; }
  describe('TouchUi', () => {
    it('finalReleasePagesRotationAndRealResults', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const driver: Driver = Driver.create();
      const original: DisplayRotation = await driver.getDisplayRotation();
      const tablet: boolean = deviceInfo.deviceType === 'tablet';
      const server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      let listening: boolean = false;
      let stage: string = 'start';
      const capturePrefix: string = params['-s capturePrefix'] ?? params['capturePrefix'] ?? '';
      const visualOnly: boolean = (params['-s touchVisualOnly'] ?? params['touchVisualOnly']) === '1';
      const find = async (id: string): Promise<Component> => {
        const node: Component = await driver.waitForComponent(ON.id(id).inWindow('com.mu.nettools'), 5000);
        if (node === null) { throw new Error('Missing touch control: ' + id + ' stage=' + stage); }
        return node;
      };
      const text = async (value: string): Promise<Component> => {
        const node: Component = await driver.waitForComponent(ON.text(value).inWindow('com.mu.nettools'), 5000);
        if (node === null) { throw new Error('Missing touch text: ' + value); }
        return node;
      };
      const capture = async (name: string): Promise<void> => {
        await driver.delayMs(600);
        const root: Rect = await (await find('app-shell')).getBounds();
        const density: number = display.getDefaultDisplaySync().densityPixels;
        await delegator.print('touch capture=' + name + ' root=' + JSON.stringify(root) + ' density=' + density);
        expect(await driver.screenCap(delegator.getAppContext().cacheDir + '/munet-touch-' + capturePrefix + name + '.png')).assertTrue();
      };
      const shape = async (landscape: boolean): Promise<void> => {
        for (const rotation of [DisplayRotation.ROTATION_0, DisplayRotation.ROTATION_90]) {
          await driver.setDisplayRotation(rotation);
          await driver.delayMs(1400);
          const size: Point = await driver.getDisplaySize();
          if ((size.x > size.y) === landscape) { return; }
        }
        throw new Error('Requested screen shape unavailable');
      };
      const nav = async (page: number): Promise<void> => {
        const side: Component = await driver.findComponent(ON.id('nav-' + page).inWindow('com.mu.nettools'));
        if (side !== null && page !== 6) { await side.click(); }
        else {
          await (await find('bottom-nav-' + (page === 0 ? 0 : page === 4 ? 2 : page === 5 ? 3 : 1))).click();
          if (page >= 1 && page <= 3) {
            await (await text(page === 1 ? 'Ping' : page === 2 ? '端口扫描' : '局域网')).click();
          }
        }
        await driver.delayMs(400);
      };
      const contentScroll = async (): Promise<Component> => {
        const nodes: Component[] = await driver.findComponents(ON.type('Scroll').inWindow('com.mu.nettools'));
        if (nodes.length === 0) { throw new Error('Missing content scroll'); }
        return nodes[nodes.length - 1];
      };
      const reach = async (scrollId: string, id: string): Promise<Component> => {
        const scroll: Component = scrollId === 'ping-content' ? await find(scrollId) :
          await contentScroll();
        const node: Component = await scroll.scrollSearch(ON.id(id).inWindow('com.mu.nettools'));
        if (node === null) { throw new Error('Unreachable touch control: ' + id); }
        return node;
      };
      const input = async (id: string, value: string): Promise<void> => {
        await (await find(id)).inputText(value);
        if (!tablet) { await driver.triggerKey(2070); }
      };
      const more = async (): Promise<void> => {
        const button: Component = await driver.findComponent(ON.id('history-more'));
        if (button !== null) { await button.click(); }
        else { await (await driver.findComponent(ON.text('更多').isBefore(ON.id('history-scans')))).click(); }
        await driver.delayMs(350);
      };
      const checkSheetTargets = async (): Promise<void> => {
        const density: number = display.getDefaultDisplaySync().densityPixels;
        for (const id of ['history-sheet-csv', 'history-sheet-json', 'history-sheet-clear', 'history-sheet-cancel']) {
          const button: Component = await driver.findComponent(ON.id(id));
          if (button !== null) {
            const bounds: Rect = await button.getBounds();
            expect((bounds.bottom - bounds.top) / density >= 55).assertTrue();
          }
        }
      };
      await delegator.startAbility({ bundleName: 'com.mu.nettools', moduleName: 'entry', abilityName: 'EntryAbility' });
      await find('app-shell');
      if (tablet) {
        const app: UiWindow = await driver.findWindow({ bundleName: 'com.mu.nettools' });
        if (app !== null && await app.getWindowMode() !== WindowMode.FULLSCREEN) {
          await app.maximize();
          await driver.delayMs(800);
        }
      }
      try {
        await driver.setDisplayRotationEnabled(false);
        for (const landscape of tablet ? [false, true] : [false]) {
          await shape(landscape);
          const root: Rect = await (await find('app-shell')).getBounds();
          const wide: boolean = (root.right - root.left) / display.getDefaultDisplaySync().densityPixels >= 840;
          expect(await driver.findComponent(ON.id('tablet-navigation')) !== null).assertEqual(wide);
          expect(await driver.findComponent(ON.id('bottom-navigation')) !== null).assertEqual(!wide);
          for (const page of [0, 1, 2, 3, 4, 5]) {
            await nav(page);
            if (page === 1) {
              const port: Rect = await (await find('ping-port')).getBounds();
              expect((port.right - port.left) / display.getDefaultDisplaySync().densityPixels >= 120).assertTrue();
            }
            if (page === 4) { await (await find('history-scans')).click(); }
            if (page === 5) {
              expect(await driver.findComponent(ON.text('诊断信息')) === null).assertTrue();
              expect(await driver.findComponent(ON.text('隐私说明')) === null).assertTrue();
              expect(await driver.findComponent(ON.text('应用版本')) === null).assertTrue();
              expect(await driver.findComponent(ON.text('核心版本')) === null).assertTrue();
              expect(await driver.findComponent(ON.text('应用标识')) === null).assertTrue();
              await text('可以做什么');
            }
            await capture((landscape ? 'landscape' : 'portrait') + '-page-' + page);
            if (page === 4) {
              await (await find('history-hosts')).click();
              await driver.delayMs(500);
              expect(await driver.findComponent(ON.id('history-filter')) === null).assertTrue();
              expect(await driver.findComponent(ON.id('history-export')) === null).assertTrue();
              await capture((landscape ? 'landscape' : 'portrait') + '-hosts');
            }
          }
          if (!wide) { await nav(6); await capture((landscape ? 'landscape' : 'portrait') + '-tools'); }
        }
        if (visualOnly) {
          await nav(4);
          await (await find('history-scans')).click();
          await driver.delayMs(500);
          if (await driver.findComponent(ON.id('history-export')) === null) {
            await more();
            await find('history-sheet-json');
            await checkSheetTargets();
            await capture('records-actions');
            await (await find('history-sheet-cancel')).click();
          }
          return;
        }
        await shape(false);
        server.on('connect', (connection: socket.TCPSocketConnection) => { connection.close().catch(() => {}); });
        await server.listen({ address: '127.0.0.1', port: 8080, family: 1 });
        listening = true;
        stage = 'ping-navigation';
        await nav(1);
        await capture('ping-before-input');
        stage = 'ping-input';
        await input('ping-target', '127.0.0.1');
        await capture('ping-after-input');
        stage = 'ping-continuous';
        await (await reach('ping-content', 'ping-continuous')).click();
        await (await reach('ping-content', 'ping-start')).click();
        await driver.delayMs(2200);
        if (tablet) { await shape(true); }
        stage = 'ping-after-rotation';
        expect(await (await find('ping-target')).getText()).assertEqual('127.0.0.1');
        expect(await (await reach('ping-content', 'ping-start')).getText()).assertEqual('停止');
        await capture(tablet ? 'rotation-running' : 'ping-running');
        await shape(false);
        await (await reach('ping-content', 'ping-start')).click();
        await driver.waitForComponent(ON.id('ping-start').text('开始'), 8000);
        await capture('ping-stopped');
        const summary: string = await (await find('ping-summary')).getText();
        expect(Number(summary.split(/\s+/)[3]) > 0).assertTrue();
        await (await find('ping-content')).scrollToBottom();
        await capture('ping-results');
        await nav(2);
        await input('port-target', '127.0.0.1');
        await (await reach('port-content', 'port-start')).click();
        await driver.waitForComponent(ON.id('port-start').text('开始扫描'), 15000);
        await (await contentScroll()).scrollToBottom();
        expect(await driver.waitForComponent(ON.text('8080', MatchPattern.STARTS_WITH).inWindow('com.mu.nettools'), 5000) !== null).assertTrue();
        await capture('port-results');
        await nav(3);
        await input('lan-cidr', '127.0.0.1/32');
        await (await reach('lan-content', 'lan-start')).click();
        await driver.waitForComponent(ON.id('lan-start').text('开始发现'), 15000);
        await (await contentScroll()).scrollToBottom();
        await text('127.0.0.1');
        await capture('lan-results');
        await nav(4);
        await (await find('history-hosts')).click();
        await text('127.0.0.1');
        await capture('hosts-results');
        await more();
        await (await text('清空全部记录与档案')).click();
        await text('清空全部记录与档案？');
        await capture('clear-confirm');
        await (await text('取消')).click();
        await driver.delayMs(600);
        await text('127.0.0.1');
        await (await find('history-scans')).click();
        await driver.delayMs(500);
        const exportButton: Component = await driver.findComponent(ON.id('history-export'));
        if (exportButton !== null) { await exportButton.click(); }
        else { await more(); }
        await text('导出全部扫描记录 · JSON');
        await checkSheetTargets();
        await capture('records-actions');
        await driver.pressBack();
      } catch (error) {
        await delegator.print('touch failed stage=' + stage + ' error=' + String(error));
        await driver.screenCap(delegator.getAppContext().cacheDir + '/munet-touch-failure.png');
        throw new Error(String(error));
      } finally {
        const stop: Component = await driver.findComponent(ON.id('ping-start').text('停止'));
        if (stop !== null) { await stop.click(); await driver.delayMs(1500); }
        if (listening) { await server.close(); }
        await driver.setDisplayRotation(original);
        await driver.setDisplayRotationEnabled((params['-s rotationEnabled'] ?? params['rotationEnabled']) !== '0');
      }
    });
  });
}
