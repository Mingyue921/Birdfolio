import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const SERIF = 'serif';

@Component
export struct ProductDetailView {
  @BuilderParam onBack: () => void;

  @Builder SettingRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(MUTED)
      Text(value).fontSize(13).fontColor(INK).layoutWeight(1).textAlign(TextAlign.End)
    }
    .padding(14)
    .backgroundColor(WHITE)
    .border({ width: 1, color: BORDER })
    .borderRadius(8)
  }

  build() {
    Column() {
      PageHeaderView({ title: '素材详情', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 15 }) {
          Image($r('app.media.shop_feature')).width('100%').height(300).objectFit(ImageFit.Cover).borderRadius(8)
          Text('湿地博物志 · 创作套装').fontFamily(SERIF).fontSize(25).fontColor(INK).width('100%')
          Text('本地免费素材').fontSize(18).fontColor(GREEN).width('100%')
          Text('包含自然观察模板、鸟类贴纸和多款字体。当前课程原型仅提供本地素材，不包含支付。')
            .fontSize(14)
            .fontColor(MUTED)
            .lineHeight(23)
          this.SettingRow('存储方式', '应用本地资源')
          this.SettingRow('适用版本', 'Birdfolio 1.0+')
          Button('素材已内置')
            .enabled(false)
            .width('100%')
            .height(48)
            .fontColor(MUTED)
            .backgroundColor(GREEN_SOFT)
            .borderRadius(8)
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
