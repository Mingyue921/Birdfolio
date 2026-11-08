import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const SERIF = 'serif';

@Component
export struct NotificationsPlanningView {
  @BuilderParam onBack: () => void;

  build() {
    Column() {
      PageHeaderView({ title: '通知', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 12 }) {
          Text('通知中心 · 规划中').fontFamily(SERIF).fontSize(22).fontColor(INK).width('100%')
          Text('迁徙提醒、观察回顾和社区互动通知将在对应数据接入后开放。当前没有可验证的通知。')
            .fontSize(14)
            .fontColor(MUTED)
            .lineHeight(22)
            .padding(18)
            .width('100%')
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
