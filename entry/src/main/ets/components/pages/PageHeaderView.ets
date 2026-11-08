const WHITE = '#FFFFFF';
const INK = '#1C241F';
const BORDER = '#DDE3DC';

@Component
export struct PageHeaderView {
  @Prop title: string;
  @BuilderParam onBack: () => void;

  build() {
    Row() {
      Stack() {
        Image($r('app.media.ic_back')).width(24).height(24).objectFit(ImageFit.Contain)
      }
      .width(44)
      .height(44)
      .borderRadius(8)
      .onClick(() => this.onBack())
      .accessibilityText('返回')

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(INK)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      Stack().width(44).height(44)
    }
    .width('100%')
    .height(58)
    .padding({ left: 12, right: 12 })
    .backgroundColor(WHITE)
    .border({ width: { bottom: 1 }, color: BORDER })
  }
}
