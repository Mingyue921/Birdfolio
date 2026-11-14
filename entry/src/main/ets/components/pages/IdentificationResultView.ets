import { IdentificationCandidate } from '../../models/BirdModels';
import { AppColors, AppFontSize, AppRadius, AppSpacing, APP_SERIF } from '../../theme/AppTheme';
import { AppButton } from '../common/AppButton';
import { AppStateView } from '../common/AppStateView';
import { PageHeaderView } from './PageHeaderView';
import { IdentificationPolicy } from '../../services/IdentificationPolicy';

@Component
export struct IdentificationResultView {
  @Link speciesId: string;
  @Prop photoUri: string;
  @Prop badge: string;
  @Prop loading: boolean;
  @Prop confirming: boolean = false;
  @Prop candidates: IdentificationCandidate[];
  @Prop candidateImages: Resource[];
  @Prop warning: string;
  @Prop failureType: string = '';
  @Prop failureTitle: string = '';
  @BuilderParam onBack: () => void;
  @BuilderParam onConfirm: () => void;
  @BuilderParam onManualSelect: () => void;
  @BuilderParam onRetry: () => void;

  private percent(score: number): string { return Math.round(score * 100).toString() + '%'; }
  private selected(): boolean { return this.speciesId.length > 0 && this.candidates.findIndex((item: IdentificationCandidate) => item.speciesId === this.speciesId) >= 0; }
  private lowConfidence(): boolean { return this.candidates.length > 0 && !IdentificationPolicy.shouldAutoSelect(this.candidates[0].finalScore); }

  @Builder Score(label: string, detail: string, score: number, emphasis: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(label).fontSize(AppFontSize.caption).fontWeight(FontWeight.Medium).fontColor(emphasis ? AppColors.primary : AppColors.text)
        Text(detail).fontSize(AppFontSize.label).fontColor(AppColors.textSecondary).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.percent(score)).fontSize(AppFontSize.body).fontWeight(FontWeight.Medium).fontColor(emphasis ? AppColors.primary : AppColors.text)
    }.width('100%')
  }

  @Builder CandidateCard(candidate: IdentificationCandidate, index: number) {
    Column({ space: AppSpacing.sm }) {
      Row({ space: AppSpacing.sm }) {
        Image(this.candidateImages[index] || $r('app.media.background')).width(70).height(70).objectFit(ImageFit.Cover).borderRadius(AppRadius.image)
        Column({ space: 4 }) {
          Text((index + 1).toString() + '. ' + candidate.name).fontFamily(APP_SERIF).fontSize(AppFontSize.sectionTitle).fontWeight(FontWeight.Medium).fontColor(AppColors.text).maxLines(2)
          Text(candidate.scientificName).fontFamily(APP_SERIF).fontSize(AppFontSize.caption).fontStyle(FontStyle.Italic).fontColor(AppColors.textSecondary).maxLines(1)
          Text(candidate.inCatalog ? '离线图鉴收录' : 'AI 候选 · 图鉴外').fontSize(AppFontSize.label).fontColor(candidate.inCatalog ? AppColors.success : AppColors.warning)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(this.speciesId === candidate.speciesId ? '✓' : '○').fontSize(20).fontColor(AppColors.primary)
      }
      this.Score('视觉匹配', '照片外观、颜色与轮廓', candidate.modelScore, false)
      this.Score('情境匹配', '地点、时间、季节与栖息地', candidate.contextScore, false)
      this.Score('综合匹配', '用于候选排序的最终结果', candidate.finalScore, true)
      Text('辨识依据：' + (candidate.reasons.length > 0 ? candidate.reasons.join(' · ') : '暂无详细依据')).fontSize(AppFontSize.caption).fontColor(AppColors.textSecondary).lineHeight(18).width('100%')
      if (index > 0) {
        Text('相似种提示：请对照体型、嘴型与翼纹后再确认。').fontSize(AppFontSize.caption).fontColor(AppColors.warning).width('100%')
      }
    }.padding(AppSpacing.md).backgroundColor(this.speciesId === candidate.speciesId ? AppColors.primarySoft : AppColors.surface).border({ width: 1, color: this.speciesId === candidate.speciesId ? AppColors.primary : AppColors.border }).borderRadius(AppRadius.card).onClick(() => this.speciesId = candidate.speciesId)
  }

  build() {
    Column() {
      PageHeaderView({ title: '识别结果', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: AppSpacing.md }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image(this.photoUri.length > 0 ? this.photoUri : $r('app.media.background')).width('100%').height(250).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(AppRadius.image)
            Text(this.badge).fontSize(AppFontSize.label).fontColor(AppColors.surface).padding(AppSpacing.xs).margin(AppSpacing.sm).backgroundColor(AppColors.overlay).borderRadius(AppRadius.tag)
          }
          if (this.loading) {
            AppStateView({ type: 'loading', title: '正在识别', message: '正在分析照片，并结合地点、时间与季节生成候选。', onAction: () => {} })
          } else if (this.candidates.length === 0) {
            AppStateView({ type: this.failureType === 'transport_error' ? 'network' : 'error', title: this.failureTitle.length > 0 ? this.failureTitle : '没有可用候选', message: this.warning.length > 0 ? this.warning : '没有识别到鸟类，请换一张清晰照片重试。', actionLabel: '重新识别', onAction: () => this.onRetry() })
          } else {
            Text(this.lowConfidence() ? '结果置信度较低，请手动选择' : 'Top ' + Math.min(3, this.candidates.length).toString() + ' 候选').fontFamily(APP_SERIF).fontSize(AppFontSize.sectionTitle).fontWeight(FontWeight.Medium).fontColor(AppColors.text).width('100%')
            if (this.lowConfidence()) {
              Text('照片信息不足，未自动选中第一名。请对照辨识依据后选择，或从图鉴手动查找。').fontSize(AppFontSize.body).fontColor(AppColors.warning).lineHeight(20).padding(AppSpacing.sm).width('100%').backgroundColor(AppColors.warningSoft).borderRadius(AppRadius.card)
            }
            ForEach(this.candidates.slice(0, 3), (item: IdentificationCandidate, index: number) => { this.CandidateCard(item, index) }, (item: IdentificationCandidate) => item.speciesId)
          }
          if (this.warning.length > 0 && this.candidates.length > 0) {
            Text(this.warning).fontSize(AppFontSize.body).fontColor(AppColors.warning).lineHeight(20).padding(AppSpacing.sm).width('100%').backgroundColor(AppColors.warningSoft).borderRadius(AppRadius.card)
          }
          Text('识别结果仅提供候选。你确认前不会创建观察记录。').fontSize(AppFontSize.caption).fontColor(AppColors.textSecondary).width('100%')
          AppButton({ label: '确认并生成观察', isEnabled: this.selected() && !this.loading, loading: this.confirming, onPress: () => this.onConfirm() })
          AppButton({ label: '从图鉴手动选择', variant: 'secondary', isEnabled: !this.confirming, onPress: () => this.onManualSelect() })
          AppButton({ label: '重新识别', variant: 'text', isEnabled: !this.confirming, onPress: () => this.onRetry() })
        }.padding({ left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.xl })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(AppColors.page)
  }
}
