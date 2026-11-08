import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BLUE = '#4F8396';
const BLUE_SOFT = '#E5F0F3';
const SERIF = 'serif';

@Component
export struct MigrationPlanningView {
  @BuilderParam onBack: () => void;

  build() {
    Column() {
      PageHeaderView({ title: '迁徙提醒', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 16 }) {
          Image($r('app.media.journal_rubythroat'))
            .width('100%')
            .height(220)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
          Text('迁徙提醒 · 规划中')
            .fontFamily(SERIF)
            .fontSize(25)
            .fontWeight(FontWeight.Medium)
            .fontColor(INK)
            .width('100%')
          Text('实时迁徙数据和个性化提醒尚未接入。当前页面仅作为产品规划入口。')
            .fontSize(14)
            .fontColor(MUTED)
            .lineHeight(23)
          Column({ space: 5 }) {
            Text('后续计划').fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK)
            Text('接入可靠的地区、季节和物种观测数据后开放提醒').fontSize(13).fontColor(BLUE)
          }
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .width('100%')
          .backgroundColor(BLUE_SOFT)
          .borderRadius(8)
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
