import { IdentificationCandidate } from '../../models/BirdModels';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const AMBER = '#E5A832';
const SERIF = 'serif';

@Component
export struct IdentificationResultView {
  @Link speciesId: string;
  @Prop photoUri: string;
  @Prop badge: string;
  @Prop loading: boolean;
  @Prop candidates: IdentificationCandidate[];
  @Prop candidateImages: Resource[];
  @Prop selectedName: string;
  @Prop selectedScientificName: string;
  @Prop selectedScore: string;
  @Prop warning: string;
  @BuilderParam onBack: () => void;
  @BuilderParam onConfirm: () => void;
  @BuilderParam onManualSelect: () => void;
  @BuilderParam onRetry: () => void;

  @Builder CandidateCard(candidate: IdentificationCandidate, index: number) {
    Row({ space: 12 }) {
      Image(this.candidateImages[index] || $r('app.media.background'))
        .width(62)
        .height(62)
        .objectFit(ImageFit.Cover)
        .borderRadius(6)
      Column({ space: 4 }) {
        Row() {
          Text((index + 1).toString() + '. ' + candidate.name)
            .fontFamily(SERIF)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(INK)
            .layoutWeight(1)
          Text(Math.round(candidate.finalScore * 100).toString() + '%').fontSize(13).fontColor(GREEN)
        }
        Text(candidate.scientificName + (candidate.inCatalog ? ' · 离线图鉴' : ' · AI 识别，图鉴外'))
          .fontSize(10)
          .fontColor(candidate.inCatalog ? GREEN : AMBER)
          .maxLines(1)
        Text(candidate.reasons.slice(0, 3).join(' · ')).fontSize(11).fontColor(MUTED).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.speciesId === candidate.speciesId ? '✓' : '›').fontSize(20).fontColor(GREEN)
    }
    .padding(12)
    .backgroundColor(this.speciesId === candidate.speciesId ? GREEN_SOFT : WHITE)
    .border({ width: 1, color: this.speciesId === candidate.speciesId ? GREEN : BORDER })
    .borderRadius(8)
    .onClick(() => this.speciesId = candidate.speciesId)
  }

  build() {
    Column() {
      PageHeaderView({ title: '识别结果', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image(this.photoUri.length > 0 ? this.photoUri : $r('app.media.background'))
              .width('100%')
              .height(285)
              .objectFit(ImageFit.Contain)
              .backgroundColor('#EEF1ED')
              .borderRadius(8)
            Text(this.badge)
              .fontSize(11)
              .fontColor(WHITE)
              .padding(8)
              .margin(12)
              .backgroundColor('#771C241F')
              .borderRadius(16)
          }
          if (this.loading) {
            Column({ space: 10 }) {
              LoadingProgress().width(36).height(36).color(GREEN)
              Text('正在分析照片并结合地点与季节…').fontSize(13).fontColor(MUTED)
            }.padding(28).width('100%').backgroundColor(WHITE).borderRadius(8)
          } else if (this.candidates.length > 0) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('当前选择').fontSize(11).fontColor(GREEN)
                  Text(this.selectedName).fontFamily(SERIF).fontSize(28).fontWeight(FontWeight.Medium).fontColor(INK)
                  Text(this.selectedScientificName).fontFamily(SERIF).fontSize(13).fontStyle(FontStyle.Italic).fontColor(MUTED)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.selectedScore + ' 综合评分')
                  .fontSize(12)
                  .fontColor(GREEN)
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .backgroundColor(GREEN_SOFT)
                  .borderRadius(20)
              }
            }.padding(16).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
            Text('候选鸟种').fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            ForEach(this.candidates, (item: IdentificationCandidate, index: number) => {
              this.CandidateCard(item, index)
            }, (item: IdentificationCandidate) => item.speciesId)
          }
          Text(this.warning.length > 0 ? this.warning : '识别结果只提供候选，确认后才会创建观察记录。')
            .fontSize(13)
            .fontColor('#745A19')
            .lineHeight(20)
            .padding(12)
            .width('100%')
            .backgroundColor('#FFF5D8')
            .borderRadius(8)
          Button('确认是' + this.selectedName + '并记录')
            .enabled(!this.loading && this.candidates.length > 0)
            .width('100%')
            .height(50)
            .backgroundColor(GREEN)
            .borderRadius(8)
            .onClick(() => this.onConfirm())
          Button('从离线图鉴手动选择')
            .width('100%')
            .height(46)
            .fontColor(GREEN)
            .backgroundColor(GREEN_SOFT)
            .borderRadius(8)
            .onClick(() => this.onManualSelect())
          Button('重新识别')
            .width('100%')
            .height(46)
            .fontColor(INK)
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
            .onClick(() => this.onRetry())
        }.padding({ left: 16, right: 16, bottom: 24 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
