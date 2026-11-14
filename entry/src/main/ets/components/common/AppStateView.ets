import { AppColors, AppFontSize, AppRadius, AppSpacing } from '../../theme/AppTheme';
import { AppButton } from './AppButton';

@Component
export struct AppStateView {
  @Prop type: string = 'empty';
  @Prop title: string;
  @Prop message: string;
  @Prop actionLabel: string = '';
  @BuilderParam onAction: () => void;

  private symbol(): string {
    if (this.type === 'loading') return '…';
    if (this.type === 'error' || this.type === 'network') return '!';
    if (this.type === 'offline') return '↯';
    return '○';
  }

  private accent(): string {
    return this.type === 'error' || this.type === 'network' ? AppColors.error : AppColors.primary;
  }

  build() {
    Column({ space: AppSpacing.sm }) {
      if (this.type === 'loading') {
        LoadingProgress().width(34).height(34).color(AppColors.primary)
      } else {
        Text(this.symbol()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.accent())
      }
      Text(this.title).fontSize(AppFontSize.sectionTitle).fontWeight(FontWeight.Medium).fontColor(AppColors.text).textAlign(TextAlign.Center)
      Text(this.message).fontSize(AppFontSize.body).fontColor(AppColors.textSecondary).lineHeight(21).textAlign(TextAlign.Center).width('100%')
      if (this.actionLabel.length > 0 && this.type !== 'loading') {
        AppButton({ label: this.actionLabel, variant: 'secondary', onPress: () => this.onAction() })
      }
    }
    .padding(AppSpacing.lg)
    .width('100%')
    .backgroundColor(AppColors.surface)
    .border({ width: 1, color: AppColors.border })
    .borderRadius(AppRadius.card)
  }
}
