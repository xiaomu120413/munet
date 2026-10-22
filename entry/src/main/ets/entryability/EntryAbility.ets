import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { Logger } from '../services/Logger';
import { window } from '@kit.ArkUI';
import { HistoryRepository } from '../repository/HistoryRepository';
import { runDebugSmoke } from './DebugSmokeRunner';

/**
 * App entry: opens the history database, runs debug-only headless hooks and
 * loads the shell page. Business logic lives in ViewModels/Repositories.
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('EntryAbility onCreate');
    this.initHistory().then(() => {
      runDebugSmoke(want, this.context);
    });
  }

  /** Opens the local history database once, at app start. */
  private initHistory(): Promise<void> {
    const repo: HistoryRepository = new HistoryRepository();
    return repo.initialize(this.context).then(() => {
      Logger.info('history store initialized');
    }).catch((err: Error) => {
      Logger.error('history store init failed: %{public}s', err.message);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error('Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      Logger.info('Index page loaded');
      try {
        windowStage.getMainWindowSync().setWindowDecorVisible(false);
      } catch (error) {
        Logger.warn('Failed to hide window title bar: %{public}s', JSON.stringify(error));
      }
    });
  }

  onWindowStageDestroy(): void {
    Logger.info('EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    Logger.info('EntryAbility onForeground');
  }

  onBackground(): void {
    Logger.info('EntryAbility onBackground');
  }
}
