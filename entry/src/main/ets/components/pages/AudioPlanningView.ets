import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const INK = '#1C241F';
const MUTED = '#5E6861';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const SERIF = 'serif';

@Component
export struct AudioPlanningView {
  @BuilderParam onBack: () => void;
  @BuilderParam onReturnHome: () => void;

  build() {
    Column() {
      PageHeaderView({ title: '听音识鸟', onBack: () => this.onBack() })
      Column({ space: 22 }) {
        Image($r('app.media.ic_mic')).width(54).height(54).objectFit(ImageFit.Contain)
        Text('声音识鸟正在规划中')
          .fontFamily(SERIF)
          .fontSize(23)
          .fontWeight(FontWeight.Medium)
          .fontColor(INK)
        Text('当前版本不会录音或生成虚假的分析结果。你仍可在观察记录中填写声音备注。')
          .fontSize(14)
          .fontColor(MUTED)
          .lineHeight(22)
          .textAlign(TextAlign.Center)
          .padding({ left: 20, right: 20 })
        Button('返回首页')
          .height(46)
          .fontColor(GREEN)
          .backgroundColor(GREEN_SOFT)
          .borderRadius(8)
          .onClick(() => this.onReturnHome())
      }
      .justifyContent(FlexAlign.Center)
      .padding(20)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
