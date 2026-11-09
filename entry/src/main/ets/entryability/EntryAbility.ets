import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { SafeLogger } from '../services/SafeLogger';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_err) {
      SafeLogger.error('BirdfolioAbility', 'color_mode_failed');
    }
    SafeLogger.info('BirdfolioAbility', 'ability_created');
  }

  onDestroy(): void {
    SafeLogger.info('BirdfolioAbility', 'ability_destroyed');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    SafeLogger.info('BirdfolioAbility', 'window_stage_created');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        SafeLogger.error('BirdfolioAbility', 'content_load_failed');
        return;
      }
      SafeLogger.info('BirdfolioAbility', 'content_loaded');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    SafeLogger.info('BirdfolioAbility', 'window_stage_destroyed');
  }

  onForeground(): void {
    // Ability has brought to foreground
    SafeLogger.info('BirdfolioAbility', 'ability_foreground');
  }

  onBackground(): void {
    // Ability has back to background
    SafeLogger.info('BirdfolioAbility', 'ability_background');
  }
}
