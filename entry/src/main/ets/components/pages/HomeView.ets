import { Observation } from '../../models/BirdModels';
import { AppColors, AppFontSize, AppRadius, AppSize, AppSpacing, APP_SERIF } from '../../theme/AppTheme';
import { ObservationCard } from '../ObservationCard';
import { AppButton } from '../common/AppButton';
import { AppStateView } from '../common/AppStateView';

@Component
export struct HomeView {
  @Prop avatarUri: string;
  @Prop recentRecords: Observation[];
  @Prop recentBirdNames: string[];
  @Prop recentBirdImages: Resource[];
  @Prop loading: boolean = false;
  @Prop loadError: string = '';
  @Prop offline: boolean = false;
  @BuilderParam onOpenProfile: () => void;
  @BuilderParam onOpenMigration: () => void;
  @BuilderParam onIdentify: () => void;
  @BuilderParam onOpenAudio: () => void;
  @BuilderParam onNewObservation: () => void;
  @BuilderParam onOpenObservations: () => void;
  @BuilderParam onSelectObservation: (id: string) => void;
  @BuilderParam onRetry: () => void;

  @Builder SectionLink(title: string, detail: string, action: () => void) {
    Row() {
      Text(title).fontFamily(APP_SERIF).fontSize(AppFontSize.sectionTitle).fontWeight(FontWeight.Medium).fontColor(AppColors.text).layoutWeight(1)
      Text(detail).fontSize(AppFontSize.caption).fontColor(AppColors.primary)
    }.width('100%').height(32).onClick(() => action())
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.md }) {
        Row() {
          Column({ space: 2 }) {
            Text('Birdfolio').fontFamily(APP_SERIF).fontSize(AppFontSize.pageTitle).fontWeight(FontWeight.Medium).fontColor(AppColors.text)
            Text('记录每一次有翅膀的相遇').fontSize(AppFontSize.caption).fontColor(AppColors.textSecondary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Image(this.avatarUri.length > 0 ? this.avatarUri : $r('app.media.avatar_sparrow')).width(AppSize.touchTarget).height(AppSize.touchTarget).objectFit(ImageFit.Cover).borderRadius(22).onClick(() => this.onOpenProfile())
        }.width('100%')

        Column({ space: AppSpacing.md }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image($r('app.media.home_egret')).width('100%').height(184).objectFit(ImageFit.Cover).borderRadius(AppRadius.image)
            Column({ space: 3 }) {
              Text('AI 识鸟').fontFamily(APP_SERIF).fontSize(AppFontSize.metric).fontWeight(FontWeight.Medium).fontColor(AppColors.surface)
              Text('拍下或选择照片，获得可解释的候选结果').fontSize(AppFontSize.caption).fontColor(AppColors.surface)
            }.padding(AppSpacing.md).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(AppColors.overlay)
          }.borderRadius(AppRadius.card)
          AppButton({ label: '拍照识鸟', icon: $r('app.media.ic_camera'), onPress: () => this.onIdentify() })
          AppButton({ label: '从相册识别', variant: 'secondary', icon: $r('app.media.ic_gallery'), onPress: () => this.onIdentify() })
          AppButton({ label: '手动记录一次观察', variant: 'text', onPress: () => this.onNewObservation() })
        }.padding(AppSpacing.sm).backgroundColor(AppColors.surface).border({ width: 1, color: AppColors.border }).borderRadius(AppRadius.card)

        Row({ space: AppSpacing.sm }) {
          Image($r('app.media.ic_mic')).width(AppSize.icon).height(AppSize.icon)
          Column({ space: 2 }) {
            Text('听音识鸟').fontSize(AppFontSize.body).fontWeight(FontWeight.Medium).fontColor(AppColors.text)
            Text('规划中').fontSize(AppFontSize.label).fontColor(AppColors.textSecondary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('›').fontColor(AppColors.info)
        }.padding(AppSpacing.sm).backgroundColor(AppColors.infoSoft).borderRadius(AppRadius.card).onClick(() => this.onOpenAudio())

        this.SectionLink('最近观察', this.recentRecords.length > 0 ? '查看全部  ›' : '', () => this.onOpenObservations())
        if (this.loading) {
          AppStateView({ type: 'loading', title: '正在读取观察', message: '本地记录加载中，请稍候。', onAction: () => {} })
        } else if (this.loadError.length > 0) {
          AppStateView({ type: 'error', title: '读取记录失败', message: this.loadError, actionLabel: '重新读取', onAction: () => this.onRetry() })
        } else if (this.recentRecords.length === 0) {
          AppStateView({ type: 'empty', title: '还没有观察记录', message: '手动记录，或先用照片识别一只鸟。', actionLabel: '手动记录', onAction: () => this.onNewObservation() })
        } else {
          ForEach(this.recentRecords, (item: Observation, index: number) => {
            ObservationCard({ item: item, birdName: this.recentBirdNames[index] || '未知鸟种', image: this.recentBirdImages[index] || $r('app.media.background'), onSelect: () => this.onSelectObservation(item.id) })
          }, (item: Observation) => item.id)
        }
        if (this.offline) {
          Text('当前离线，本地观察仍可查看和编辑。').fontSize(AppFontSize.caption).fontColor(AppColors.warning).padding(AppSpacing.sm).width('100%').backgroundColor(AppColors.warningSoft).borderRadius(AppRadius.card)
        }
      }.padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: 28 }).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off).backgroundColor(AppColors.page)
  }
}
