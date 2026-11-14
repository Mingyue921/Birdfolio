import { AppColors, AppFontSize, AppRadius, AppSize, AppSpacing } from '../../theme/AppTheme';

@Component
export struct AppButton {
  @Prop label: string;
  @Prop variant: string = 'primary';
  @Prop isEnabled: boolean = true;
  @Prop loading: boolean = false;
  @Prop icon: Resource | undefined = undefined;
  @BuilderParam onPress: () => void;

  private buttonBackground(): string {
    if (!this.isEnabled || this.loading) return AppColors.border;
    if (this.variant === 'secondary') return AppColors.primarySoft;
    if (this.variant === 'text') return AppColors.transparent;
    if (this.variant === 'danger') return AppColors.errorSoft;
    return AppColors.primary;
  }

  private foreground(): string {
    if (!this.isEnabled || this.loading) return AppColors.textSecondary;
    if (this.variant === 'primary') return AppColors.surface;
    if (this.variant === 'danger') return AppColors.error;
    return AppColors.primary;
  }

  build() {
    Button() {
      Row({ space: AppSpacing.xs }) {
        if (this.loading) {
          LoadingProgress().width(20).height(20).color(this.foreground())
        } else if (this.icon !== undefined) {
          Image(this.icon!).width(AppSize.icon).height(AppSize.icon).objectFit(ImageFit.Contain)
        }
        Text(this.loading ? '处理中…' : this.label)
          .fontSize(AppFontSize.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.foreground())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.justifyContent(FlexAlign.Center).width('100%')
    }
    .enabled(this.isEnabled && !this.loading)
    .width('100%')
    .height(this.variant === 'primary' ? AppSize.primaryButton : AppSize.secondaryButton)
    .backgroundColor(this.buttonBackground())
    .border({ width: this.variant === 'text' ? 0 : 1, color: this.variant === 'primary' ? AppColors.primary : AppColors.border })
    .borderRadius(AppRadius.button)
    .onClick(() => {
      if (this.isEnabled && !this.loading) this.onPress();
    })
  }
}
