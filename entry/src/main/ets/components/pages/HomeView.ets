import { Observation } from '../../models/BirdModels';
import { ObservationCard } from '../ObservationCard';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const BLUE = '#4F8396';
const BLUE_SOFT = '#E5F0F3';
const SERIF = 'serif';

@Component
export struct HomeView {
  @Prop avatarUri: string;
  @Prop recentRecords: Observation[];
  @Prop recentBirdNames: string[];
  @Prop recentBirdImages: Resource[];
  @BuilderParam onOpenProfile: () => void;
  @BuilderParam onOpenMigration: () => void;
  @BuilderParam onIdentify: () => void;
  @BuilderParam onOpenAudio: () => void;
  @BuilderParam onNewObservation: () => void;
  @BuilderParam onOpenObservations: () => void;
  @BuilderParam onSelectObservation: (id: string) => void;

  @Builder Action(icon: Resource, title: string, action: () => void) {
    Row({ space: 9 }) {
      Image(icon).width(21).height(21).objectFit(ImageFit.Contain)
      Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(48)
    .backgroundColor(WHITE)
    .border({ width: 1, color: BORDER })
    .borderRadius(8)
    .onClick(() => action())
  }

  @Builder SectionLink(title: string, detail: string, action: () => void) {
    Row() {
      Text(title).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
      Text(detail).fontSize(13).fontColor(GREEN)
    }.width('100%').height(32).onClick(() => action())
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Image(this.avatarUri.length > 0 ? this.avatarUri : $r('app.media.avatar_sparrow'))
            .width(42)
            .height(42)
            .objectFit(ImageFit.Cover)
            .borderRadius(21)
            .onClick(() => this.onOpenProfile())
          Blank()
        }.width('100%')

        Row({ space: 12 }) {
          Text('候').fontSize(12).fontWeight(FontWeight.Bold).fontColor(BLUE).width(34).height(34).textAlign(TextAlign.Center).backgroundColor(WHITE).borderRadius(17)
          Column({ space: 2 }) {
            Text('迁徙提醒 · 规划中').fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK)
            Text('实时迁徙数据接入后开放').fontSize(12).fontColor(MUTED)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('›').fontColor(BLUE)
        }.padding(12).width('100%').backgroundColor(BLUE_SOFT).borderRadius(8).onClick(() => this.onOpenMigration())

        Column({ space: 0 }) {
          Image($r('app.media.home_egret')).width('100%').height(205).objectFit(ImageFit.Cover).borderRadius({ topLeft: 8, topRight: 8 })
          Column({ space: 5 }) {
            Text('今天，去遇见一只鸟').fontFamily(SERIF).fontSize(24).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text('记录你看到、听到的自然，也记录相遇时的自己。').fontSize(13).fontColor(MUTED).lineHeight(19).width('100%')
          }.padding(16).alignItems(HorizontalAlign.Start)
        }.backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)

        Row({ space: 9 }) {
          Image($r('app.media.ic_camera')).width(22).height(22)
          Text('拍照识鸟').fontSize(16).fontWeight(FontWeight.Medium).fontColor(WHITE)
        }.justifyContent(FlexAlign.Center).width('100%').height(50).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onIdentify())

        Row({ space: 10 }) {
          this.Action($r('app.media.ic_gallery'), '从相册识别', () => this.onIdentify())
          this.Action($r('app.media.ic_mic'), '听音识鸟', () => this.onOpenAudio())
        }
        Text('＋  没有照片？手动记录一次观察').fontSize(13).fontColor(GREEN).height(38).onClick(() => this.onNewObservation())
        this.SectionLink('最近观察', '查看全部  ›', () => this.onOpenObservations())
        ForEach(this.recentRecords, (item: Observation, index: number) => {
          ObservationCard({
            item: item,
            birdName: this.recentBirdNames[index] || '未知鸟种',
            image: this.recentBirdImages[index] || $r('app.media.background'),
            onSelect: () => this.onSelectObservation(item.id)
          })
        }, (item: Observation) => item.id)
      }.padding({ left: 16, right: 16, top: 16, bottom: 28 }).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
