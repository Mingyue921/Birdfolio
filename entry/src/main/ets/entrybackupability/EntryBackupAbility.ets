import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { SafeLogger } from '../services/SafeLogger';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    SafeLogger.info('BirdfolioBackup', 'backup_disabled');
    await Promise.resolve();
  }

  async onRestore(_bundleVersion: BundleVersion) {
    SafeLogger.info('BirdfolioBackup', 'restore_disabled');
    await Promise.resolve();
  }
}
