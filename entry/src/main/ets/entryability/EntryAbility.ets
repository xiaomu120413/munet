import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HistoryRepository } from '../repository/HistoryRepository';
import { runDebugSmoke } from './DebugSmokeRunner';

const DOMAIN: number = 0x0000;
const TAG: string = 'NetTools';

/**
 * App entry: opens the history database, runs debug-only headless hooks and
 * loads the shell page. Business logic lives in ViewModels/Repositories.
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
    this.initHistory().then(() => {
      runDebugSmoke(want, this.context);
    });
  }

  /** Opens the local history database once, at app start. */
  private initHistory(): Promise<void> {
    const repo: HistoryRepository = new HistoryRepository();
    return repo.initialize(this.context).then(() => {
      hilog.info(DOMAIN, TAG, 'history store initialized');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'history store init failed: %{public}s', err.message);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Index page loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground');
  }
}
