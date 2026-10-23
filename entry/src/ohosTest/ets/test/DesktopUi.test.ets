import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { display, window } from '@kit.ArkUI';
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
      let stage: string = 'launch';
      const prefix: string = params['-s capturePrefix'] ?? params['capturePrefix'] ?? '';
      const visualOnly: boolean = (params['-s desktopVisualOnly'] ?? params['desktopVisualOnly']) === '1';
      const find = async (id: string): Promise<Component> => {
        const node: Component = await driver.waitForComponent(ON.id(id).inWindow('com.muge.munet'), 4000);
        if (node === null) { throw new Error('Missing desktop control: ' + id); }
        return node;
      };
      const mouse = async (node: Component): Promise<void> => {
        const b: Rect = await node.getBounds();
        await driver.mouseClick({ x: Math.round((b.left + b.right) / 2), y: Math.round((b.top + b.bottom) / 2) }, MouseButton.MOUSE_BUTTON_LEFT);
      };
      const nav = async (page: number): Promise<void> => {
        const bar: Component = await find('desktop-navigation');
        let item: Component = await driver.findComponent(ON.id('nav-' + page).inWindow('com.muge.munet'));
        if (await bar.isScrollable()) {
          const b: Rect = await bar.getBounds();
          // A short window may require vertical scrolling in the left navigation.
          for (let i: number = 0; i < 5; i++) {
            if (item !== null) {
              const bounds: Rect = await item.getBounds();
              if (bounds.bottom - bounds.top > 50 && bounds.top >= b.top && bounds.bottom <= b.bottom) { break; }
            }
            await driver.mouseScroll({ x: Math.round((b.left + b.right) / 2), y: Math.round((b.top + b.bottom) / 2) }, page > 1, 2);
            item = await driver.findComponent(ON.id('nav-' + page).inWindow('com.muge.munet'));
          }
        }
        await delegator.print('navigation page=' + page + ' scrollable=' + await bar.isScrollable());
        expect(item !== null).assertTrue();
        await mouse(item);
        await driver.delayMs(250);
      };
      const focus = async (id: string): Promise<Component> => {
        const node: Component = await find(id);
        for (let i: number = 0; i < 45 && !await node.isFocused(); i++) { await driver.triggerKey(2049); }
        expect(await node.isFocused()).assertTrue();
        return node;
      };
      await delegator.startAbility({ bundleName: 'com.muge.munet', moduleName: 'entry', abilityName: 'EntryAbility' });
      await find('app-shell');
      await find('desktop-navigation');
      const mainWindow: window.Window = await window.getLastWindow((await delegator.getCurrentTopAbility()).context);
      expect(mainWindow.getWindowDecorVisible()).assertFalse();
      const app: UiWindow = await driver.findWindow({ bundleName: 'com.muge.munet' });
      if (app === null) { throw new Error('Desktop application window unavailable'); }
      const original: Rect = await app.getBounds();
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const initial: Rect = await (await find('app-shell')).getBounds();
      const frameWidth: number = original.right - original.left - (initial.right - initial.left);
      const frameHeight: number = original.bottom - original.top - (initial.bottom - initial.top);
      const capture = async (name: string): Promise<void> => {
        const bounds: Rect = await app.getBounds();
        await driver.delayMs(250);
        const root: Rect = await (await find('app-shell')).getBounds();
        await delegator.print('capture=' + prefix + name + ' bounds=' + JSON.stringify(bounds) + ' root=' + JSON.stringify(root));
        expect(await driver.screenCap(delegator.getAppContext().cacheDir + '/munet-' + prefix + name + '.png')).assertTrue();
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
        stage = 'window-matrix';
        for (const width of visualOnly ? [320, 1440] : [320, 390, 600, 834, 1194, 1440]) {
          await resize(width, 620);
          for (const page of [0, 1, 2, 3, 4, 5]) {
            await nav(page);
            const root: Rect = await (await find('app-shell')).getBounds();
            const sidebar: Rect = await (await find('desktop-navigation')).getBounds();
            expect(Math.abs(sidebar.left - root.left) <= 2).assertTrue();
            expect(Math.abs(sidebar.top - root.top) <= 2).assertTrue();
            expect(sidebar.right < root.right - 100 * density).assertTrue();
            const actual: number = (root.right - root.left) / density;
            expect(Math.abs(actual - width) < 2).assertTrue();
            expect(Math.abs((sidebar.right - sidebar.left) / density - (actual < 840 ? 72 : 192)) < 2).assertTrue();
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
            if (page === 5) {
              await driver.assertComponentExist(ON.text('可以做什么').inWindow('com.muge.munet'));
              for (const label of ['木络 · MuNet', '应用版本', '应用标识', '核心版本', '诊断信息', '隐私说明']) {
                expect(await driver.findComponent(ON.text(label).inWindow('com.muge.munet')) === null).assertTrue();
              }
            }
            await capture('pc-' + width + '-page-' + page);
            if (page === 4) {
              await mouse(await find('history-hosts'));
              expect(await driver.findComponent(ON.id('history-filter')) === null).assertTrue();
              expect(await driver.findComponent(ON.id('history-export')) === null).assertTrue();
              await capture('pc-' + width + '-hosts');
              await mouse(await find('history-scans'));
            }
          }
        }
        if (visualOnly) { return; }
        stage = 'short-window';
        await resize(834, 360);
        await nav(1);
        const start: Component = await (await find('ping-content')).scrollSearch(ON.id('ping-start'));
        const button: Rect = await start.getBounds();
        const shortRoot: Rect = await (await find('app-shell')).getBounds();
        expect(button.top >= shortRoot.top && button.bottom <= shortRoot.bottom).assertTrue();
        await capture('pc-short-ping');
        await nav(5);
        await driver.assertComponentExist(ON.text('可以做什么'));
        await capture('pc-short-about');
        await resize(1440, 750);
        await nav(1);
        await (await find('ping-content')).scrollToTop();
        server.on('connect', (connection: socket.TCPSocketConnection) => { connection.close().catch(() => {}); });
        await server.listen({ address: '127.0.0.1', port: 8080, family: 1 });
        listening = true;
        stage = 'keyboard-input';
        await mouse(await find('ping-target'));
        await driver.triggerCombineKeys(2072, 2017); // Ctrl+A
        await driver.triggerKey(2055); // Backspace
        expect(await (await find('ping-target')).getText()).assertEqual('');
        await (await find('ping-target')).inputText('127.0.0.1');
        await driver.triggerKey(2054); // Enter submits the field.
        await driver.delayMs(300);
        await driver.waitForComponent(ON.id('ping-start').text('开始'), 12000);
        const submitted: string = await (await find('ping-summary')).getText();
        expect(Number(submitted.split(/\s+/)[3]) > 0).assertTrue();
        await capture('pc-keyboard-enter-results');
        await focus('ping-continuous');
        await driver.triggerKey(2050); // Space toggles the native switch.
        await capture('pc-keyboard-space-toggle');
        stage = 'running-resize';
        await mouse(await find('ping-start'));
        await driver.delayMs(1800);
        expect(await (await find('ping-target')).isEnabled()).assertFalse();
        await resize(600, 620);
        await (await find('ping-content')).scrollSearch(ON.id('ping-start'));
        expect(await (await find('ping-start')).getText()).assertEqual('停止');
        expect(await (await find('ping-target')).getText()).assertEqual('127.0.0.1');
        await capture('pc-narrow-ping-running');
        await mouse(await find('ping-start'));
        await driver.waitForComponent(ON.id('ping-start').text('开始'), 6000);
        await resize(1440, 750);
        stage = 'real-port-and-lan';
        await nav(2);
        await (await find('port-target')).inputText('127.0.0.1');
        await driver.triggerKey(2070);
        await mouse(await find('port-start'));
        await driver.waitForComponent(ON.id('port-start').text('开始扫描'), 10000);
        await driver.assertComponentExist(ON.text('8080').inWindow('com.muge.munet'));
        await capture('pc-port-results');
        await nav(3);
        await (await find('lan-cidr')).inputText('127.0.0.1/32');
        await driver.triggerKey(2070);
        await mouse(await find('lan-start'));
        await driver.waitForComponent(ON.id('lan-start').text('开始发现'), 10000);
        await driver.assertComponentExist(ON.text('127.0.0.1').inWindow('com.muge.munet'));
        await capture('pc-lan-results');
        await nav(4);
        stage = 'keyboard-menu';
        await mouse(await find('history-scans'));
        const exportButton: Component = await find('history-export');
        await focus('history-export');
        await driver.triggerCombineKeys(2047, 2049); // Shift+Tab reverses focus.
        expect(await exportButton.isFocused()).assertFalse();
        await driver.triggerKey(2049);
        expect(await exportButton.isFocused()).assertTrue();
        await driver.triggerKey(2054);
        await driver.assertComponentExist(ON.text('导出全部扫描记录 · JSON'));
        await capture('pc-keyboard-export-menu');
        await driver.triggerKey(2070);
        await driver.delayMs(600); // Menu dismissal restores native focus asynchronously.
        expect(await driver.findComponent(ON.text('导出全部扫描记录 · JSON')) === null).assertTrue();
        expect(await (await find('history-export')).isFocused()).assertTrue();
        await capture('pc-keyboard-focus-return');
        stage = 'narrow-desktop-menu';
        await resize(390, 620);
        await mouse(await find('history-more'));
        await driver.assertComponentExist(ON.text('导出全部扫描记录 · JSON'));
        // A PC keeps anchored native menus even when its result layout is narrow.
        expect(await driver.findComponent(ON.id('history-sheet-json')) === null).assertTrue();
        await capture('pc-narrow-menu');
        await driver.triggerKey(2070);
        await driver.delayMs(400);
        await resize(1440, 750);
        await mouse(await find('history-hosts'));
        await capture('pc-hosts');
      } catch (error) {
        await delegator.print('desktop failed stage=' + stage + ' error=' + String(error));
        await capture('pc-failure');
        throw new Error(String(error));
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
