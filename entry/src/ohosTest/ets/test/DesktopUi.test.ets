import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { display } from '@kit.ArkUI';
import { socket } from '@kit.NetworkKit';
import { Driver, ON, Component, UiWindow, ResizeDirection, Rect, MouseButton } from '@ohos.UiTest';

// Explicit desktop-only opt in; preserve user records and restore window bounds.
export default function desktopUiTest() {
  const params: Record<string, string> = abilityDelegatorRegistry.getArguments().parameters;
  if ((params['-s desktopAcceptance'] ?? params['desktopAcceptance']) !== '1') { return; }
  describe('DesktopUi', () => {
    it('windowMatrixAndNativeMouseKeyboard', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const driver: Driver = Driver.create();
      const server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      let listening: boolean = false;
      const find = async (id: string): Promise<Component> => {
        const node: Component = await driver.waitForComponent(ON.id(id).inWindow('com.mu.nettools'), 4000);
        if (node === null) { throw new Error('Missing desktop control: ' + id); }
        return node;
      };
      const mouse = async (node: Component): Promise<void> => {
        const b: Rect = await node.getBounds();
        await driver.mouseClick({ x: Math.round((b.left + b.right) / 2), y: Math.round((b.top + b.bottom) / 2) }, MouseButton.MOUSE_BUTTON_LEFT);
      };
      const nav = async (page: number): Promise<void> => {
        const bar: Component = await find('desktop-navigation');
        let item: Component = await driver.findComponent(ON.id('nav-' + page).inWindow('com.mu.nettools'));
        if (await bar.isScrollable()) {
          const b: Rect = await bar.getBounds();
          // A short window may require vertical scrolling in the left navigation.
          for (let i: number = 0; i < 5; i++) {
            if (item !== null) {
              const bounds: Rect = await item.getBounds();
              if (bounds.bottom - bounds.top > 50 && bounds.top >= b.top && bounds.bottom <= b.bottom) { break; }
            }
            await driver.mouseScroll({ x: Math.round((b.left + b.right) / 2), y: Math.round((b.top + b.bottom) / 2) }, page > 1, 2);
            item = await driver.findComponent(ON.id('nav-' + page).inWindow('com.mu.nettools'));
          }
        }
        await delegator.print('navigation page=' + page + ' scrollable=' + await bar.isScrollable());
        expect(item !== null).assertTrue();
        await mouse(item);
        await driver.delayMs(250);
      };
      await delegator.startAbility({ bundleName: 'com.mu.nettools', moduleName: 'entry', abilityName: 'EntryAbility' });
      await find('app-shell');
      const app: UiWindow = await driver.findWindow({ bundleName: 'com.mu.nettools', focused: true });
      const original: Rect = await app.getBounds();
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const initial: Rect = await (await find('app-shell')).getBounds();
      const frameWidth: number = original.right - original.left - (initial.right - initial.left);
      const frameHeight: number = original.bottom - original.top - (initial.bottom - initial.top);
      const capture = async (name: string): Promise<void> => {
        const bounds: Rect = await app.getBounds();
        await delegator.print('capture=' + name + ' bounds=' + JSON.stringify(bounds));
        expect(await driver.screenCap(delegator.getAppContext().cacheDir + '/munet-' + name + '.png')).assertTrue();
      };
      const resize = async (width: number, height: number): Promise<void> => {
        await app.resize(Math.round(width * density + frameWidth), Math.round(height * density + frameHeight), ResizeDirection.RIGHT_DOWN);
        await driver.delayMs(550);
        const root: Rect = await (await find('app-shell')).getBounds();
        await delegator.print('desktop requested=' + width + 'x' + height + ' actual=' +
          (root.right - root.left) / density + 'x' + (root.bottom - root.top) / density + ' density=' + density);
      };
      try {
        await app.moveTo(30, 80);
        await nav(1);
        await (await find('ping-target')).inputText('127.0.0.1');
        // Escape dismisses the input method without navigating out of the tool.
        await driver.triggerKey(2070);
        for (const width of [320, 390, 600, 834, 1194, 1440]) {
          await resize(width, 620);
          for (const page of [0, 1, 2, 3, 4, 5]) {
            await nav(page);
            const root: Rect = await (await find('app-shell')).getBounds();
            const sidebar: Rect = await (await find('desktop-navigation')).getBounds();
            expect(Math.abs(sidebar.left - root.left) <= 2).assertTrue();
            expect(Math.abs(sidebar.top - root.top) <= 2).assertTrue();
            expect(sidebar.right < root.right - 100 * density).assertTrue();
            expect(Math.abs((sidebar.right - sidebar.left) / density - (width < 840 ? 72 : 192)) < 2).assertTrue();
            expect(await driver.findComponent(ON.id('bottom-navigation')) === null).assertTrue();
            if (page === 1) {
              const input: Component = await find('ping-target');
              expect(await input.getText()).assertEqual('127.0.0.1');
              const bounds: Rect = await input.getBounds();
              expect(bounds.left >= root.left && bounds.right <= root.right).assertTrue();
              const start: Component = await (await find('ping-content')).scrollSearch(ON.id('ping-start'));
              expect(start !== null).assertTrue();
              await (await find('ping-content')).scrollToTop();
            }
            await capture('pc-' + width + '-page-' + page);
          }
        }
        await resize(834, 360);
        await nav(1);
        const start: Component = await (await find('ping-content')).scrollSearch(ON.id('ping-start'));
        const button: Rect = await start.getBounds();
        const shortRoot: Rect = await (await find('app-shell')).getBounds();
        expect(button.top >= shortRoot.top && button.bottom <= shortRoot.bottom).assertTrue();
        await capture('pc-short-ping');
        await resize(1440, 750);
        await (await find('ping-content')).scrollToTop();
        server.on('connect', (connection: socket.TCPSocketConnection) => { connection.close().catch(() => {}); });
        await server.listen({ address: '127.0.0.1', port: 8080, family: 1 });
        listening = true;
        await mouse(await find('ping-continuous'));
        await mouse(await find('ping-start'));
        await driver.delayMs(1800);
        expect(await (await find('ping-target')).isEnabled()).assertFalse();
        await resize(600, 620);
        expect(await (await find('ping-start')).getText()).assertEqual('停止');
        expect(await (await find('ping-target')).getText()).assertEqual('127.0.0.1');
        await capture('pc-narrow-ping-running');
        await mouse(await find('ping-start'));
        await driver.waitForComponent(ON.id('ping-start').text('开始'), 6000);
        await resize(1440, 750);
        await nav(2);
        await (await find('port-target')).inputText('127.0.0.1');
        await driver.triggerKey(2070);
        await mouse(await find('port-start'));
        await driver.waitForComponent(ON.id('port-start').text('开始扫描'), 10000);
        await driver.assertComponentExist(ON.text('8080').inWindow('com.mu.nettools'));
        await capture('pc-port-results');
        await nav(3);
        await (await find('lan-cidr')).inputText('127.0.0.1/32');
        await driver.triggerKey(2070);
        await mouse(await find('lan-start'));
        await driver.waitForComponent(ON.id('lan-start').text('开始发现'), 10000);
        await driver.assertComponentExist(ON.text('127.0.0.1').inWindow('com.mu.nettools'));
        await capture('pc-lan-results');
        await nav(4);
        await mouse(await find('history-scans'));
        const exportButton: Component = await find('history-export');
        for (let i: number = 0; i < 30 && !await exportButton.isFocused(); i++) { await driver.triggerKey(2049); }
        expect(await exportButton.isFocused()).assertTrue();
        await driver.triggerKey(2054);
        await driver.assertComponentExist(ON.text('导出全部扫描记录 · JSON'));
        await capture('pc-keyboard-export-menu');
        await driver.triggerKey(2070);
        expect(await driver.findComponent(ON.text('导出全部扫描记录 · JSON')) === null).assertTrue();
        expect(await (await find('history-export')).isFocused()).assertTrue();
        await capture('pc-keyboard-focus-return');
        await mouse(await find('history-hosts'));
        await capture('pc-hosts');
      } finally {
        const stop: Component = await driver.findComponent(ON.id('ping-start').text('停止'));
        if (stop !== null) { await stop.click(); await driver.delayMs(1500); }
        if (listening) { await server.close(); }
        await app.resize(original.right - original.left, original.bottom - original.top, ResizeDirection.RIGHT_DOWN);
        await app.moveTo(original.left, original.top);
      }
    });
  });
}
