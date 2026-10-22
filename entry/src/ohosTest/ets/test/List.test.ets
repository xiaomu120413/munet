import netToolsUnitTest from './NetToolsUnit.test';
import localNetViewModelTest from './LocalNetViewModel.test';
import pingLifecycleTest from './PingLifecycle.test';
import uiMigrationTest from './UiMigration.test';
import responsiveUiTest from './ResponsiveUi.test';
import windowUiTest from './WindowUi.test';
import desktopUiTest from './DesktopUi.test';

export default function testsuite() {
  netToolsUnitTest();
  localNetViewModelTest();
  pingLifecycleTest();
  uiMigrationTest();
  responsiveUiTest();
  windowUiTest();
  desktopUiTest();
}
