import muNetUnitTest from './MuNetUnit.test';
import localNetViewModelTest from './LocalNetViewModel.test';
import pingLifecycleTest from './PingLifecycle.test';
import uiMigrationTest from './UiMigration.test';
import responsiveUiTest from './ResponsiveUi.test';
import windowUiTest from './WindowUi.test';
import desktopUiTest from './DesktopUi.test';
import touchUiTest from './TouchUi.test';

export default function testsuite() {
  muNetUnitTest();
  localNetViewModelTest();
  pingLifecycleTest();
  uiMigrationTest();
  responsiveUiTest();
  windowUiTest();
  desktopUiTest();
  touchUiTest();
}
