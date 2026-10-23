import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { display } from '@kit.ArkUI';
import { Driver, ON, Component, UiWindow, WindowMode, ResizeDirection, Rect, DisplayRotation } from '@ohos.UiTest';

// Explicitly opt in with -s windowAcceptance 1; uses the tablet's system window menu.
export default function windowUiTest() {
  const params: Record<string, string> = abilityDelegatorRegistry.getArguments().parameters;
  if (params['windowAcceptance'] !== '1' && params['-s windowAcceptance'] !== '1') { return; }
  describe('WindowUi', () => {
    it('resizingKeepsInputAndControlsReachable', 0, async () => {
      const delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
      const driver: Driver = Driver.create();
      const originalRotation: DisplayRotation = await driver.getDisplayRotation();
      await delegator.startAbility({ bundleName: 'com.mu.nettools', abilityName: 'EntryAbility', moduleName: 'entry' });
      await driver.delayMs(1200);
      await driver.waitForComponent(ON.id('app-shell').inWindow('com.mu.nettools'), 5000);
      let app: UiWindow = await driver.findWindow({ bundleName: 'com.mu.nettools' });
      if (app === null) { throw new Error('Application window unavailable after launch'); }
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const originalMode: WindowMode = await app.getWindowMode();
      if (await app.getWindowMode() === WindowMode.FULLSCREEN) {
        const full: Rect = await app.getBounds();
        await driver.click(Math.round((full.left + full.right) / 2), full.top + Math.round(27 * density));
        await (await driver.waitForComponent(ON.text('切换悬浮窗'), 4000)).click();
        await driver.delayMs(800);
        app = await driver.findWindow({ bundleName: 'com.mu.nettools' });
        if (app === null) { throw new Error('Floating application window unavailable'); }
      }
      expect(await app.getWindowMode()).assertEqual(WindowMode.FLOATING);
      const original: Rect = await app.getBounds();
      const cacheDir: string = delegator.getAppContext().cacheDir;
      const nav: Component = await driver.findComponent(ON.id('nav-1').inWindow('com.mu.nettools'));
      if (nav !== null) { await nav.click(); }
      else {
        await (await driver.findComponent(ON.id('bottom-nav-1').inWindow('com.mu.nettools'))).click();
        await (await driver.waitForComponent(ON.text('Ping').inWindow('com.mu.nettools'), 3000)).click();
      }
      await (await driver.waitForComponent(ON.id('ping-target'), 3000)).inputText('127.0.0.1');
      try {
        await driver.setDisplayRotationEnabled(false);
        for (const rotation of [DisplayRotation.ROTATION_0, DisplayRotation.ROTATION_90]) {
          await driver.setDisplayRotation(rotation);
          await driver.delayMs(1200);
          const size = await driver.getDisplaySize();
          if (size.x > size.y) { break; }
        }
        app = await driver.findWindow({ bundleName: 'com.mu.nettools' });
        if (app === null) { throw new Error('Application window unavailable after rotation'); }
        await app.moveTo(0, 100);
        for (const width of [320, 390, 600, 834, 1194, 1440]) {
          app = await driver.findWindow({ bundleName: 'com.mu.nettools' });
          if (app === null) { throw new Error('Application window unavailable before resize'); }
          await app.resize(Math.round(width * density), Math.round(620 * density), ResizeDirection.RIGHT_DOWN);
          await driver.delayMs(900);
          const scroll: Component = await driver.findComponent(ON.id('ping-content'));
          await scroll.scrollToTop();
          const root: Rect = await (await driver.findComponent(ON.id('app-shell'))).getBounds();
          const input: Component = await driver.findComponent(ON.id('ping-target'));
          expect(await input.getText()).assertEqual('127.0.0.1');
          const field: Rect = await input.getBounds();
          expect(field.left >= root.left && field.right <= root.right).assertTrue();
          const actual: number = (root.right - root.left) / density;
          const side: Component = await driver.findComponent(ON.id('tablet-navigation'));
          expect(side !== null).assertEqual(actual >= 840);
          await delegator.print('window requested=' + width + ' actual=' + actual +
            ' height=' + (root.bottom - root.top) / density);
          await delegator.print('window capture=' + width + ' root=' + JSON.stringify(root));
          await driver.screenCap(cacheDir + '/munet-window-' + width + '.png');
          const start: Component = await scroll.scrollSearch(ON.id('ping-start'));
          expect(start !== null).assertTrue();
          const button: Rect = await start.getBounds();
          expect(button.top >= root.top && button.bottom <= root.bottom).assertTrue();
          await scroll.scrollToTop();
        }
      } finally {
        const current: UiWindow = await driver.findWindow({ bundleName: 'com.mu.nettools' });
        if (current !== null) {
          if (originalMode === WindowMode.FULLSCREEN) { await current.maximize(); }
          else {
            await current.resize(original.right - original.left, original.bottom - original.top, ResizeDirection.RIGHT_DOWN);
            await current.moveTo(original.left, original.top);
          }
        }
        await driver.setDisplayRotation(originalRotation);
        await driver.setDisplayRotationEnabled((params['-s rotationEnabled'] ?? params['rotationEnabled']) !== '0');
      }
    });
  });
}
