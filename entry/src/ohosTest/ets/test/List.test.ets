import netToolsUnitTest from './NetToolsUnit.test';
import localNetViewModelTest from './LocalNetViewModel.test';
import pingLifecycleTest from './PingLifecycle.test';

export default function testsuite() {
  netToolsUnitTest();
  localNetViewModelTest();
  pingLifecycleTest();
}
