import { Observation } from '../models/BirdModels';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';

@Component
export struct ObservationDetailView {
  @Prop record: Observation;
  @Prop birdName: string;
  @Prop scientificName: string;
  @Prop image: Resource;
  @BuilderParam onBack: () => void;
  @BuilderParam onEdit: () => void;
  @BuilderParam onDelete: () => void;
  @BuilderParam onCreateJournal: () => void;

  @Builder DetailField(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(MUTED).layoutWeight(1)
      Text(value).fontSize(14).fontColor(INK)
    }.padding(14).width('100%').backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  @Builder Privacy() {
    Row({ space: 10 }) {
      Text('⌖').fontSize(18).fontColor(GREEN)
      Column({ space: 2 }) {
        Text('位置隐私保护').fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK)
        Text(this.record.fuzzyLocation ? '公开展示时仅显示模糊位置' : '精确位置仅自己可见').fontSize(12).fontColor(MUTED)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('已开启').fontSize(12).fontColor(GREEN).padding({ left: 9, right: 9, top: 6, bottom: 6 }).backgroundColor(GREEN_SOFT).borderRadius(14)
    }.padding(13).width('100%').backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  build() {
    Column() {
      Row() {
        Button('‹').width(44).height(44).fontSize(28).fontColor(INK).backgroundColor(WHITE).onClick(() => this.onBack())
        Text('观察详情').fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).textAlign(TextAlign.Center).layoutWeight(1)
        Stack().width(44).height(44)
      }.height(58).padding({ left: 12, right: 12 }).backgroundColor(WHITE).border({ width: { bottom: 1 }, color: BORDER })
      Scroll() {
        Column({ space: 15 }) {
          Row({ space: 12 }) {
            Image(this.image).width(100).height(100).objectFit(ImageFit.Cover).borderRadius(8)
            Column({ space: 5 }) {
              Text(this.birdName).fontFamily('serif').fontSize(25).fontColor(INK)
              Text(this.scientificName).fontFamily('serif').fontSize(13).fontStyle(FontStyle.Italic).fontColor(MUTED)
              Text(this.record.count.toString() + ' 只 · ' + this.record.observedAt).fontSize(12).fontColor(GREEN)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          Row({ space: 10 }) {
            Button('编辑记录').layoutWeight(1).height(44).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onEdit())
            Button('删除记录').layoutWeight(1).height(44).fontColor('#D7644A').backgroundColor(WHITE).border({ width: 1, color: '#D7644A' }).borderRadius(8).onClick(() => this.onDelete())
          }
          Button('制作手账').width('100%').height(42).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onCreateJournal())
          this.DetailField('观察地点', this.record.placeName)
          this.DetailField('观察日期', this.record.observedAt)
          this.DetailField('位置保护', this.record.fuzzyLocation ? '已开启模糊保护' : '精确位置仅自己可见')
          Text('观察行为').fontFamily('serif').fontSize(18).fontColor(INK).width('100%')
          Row({ space: 8 }) {
            ForEach(this.record.behaviors && this.record.behaviors.length > 0 ? this.record.behaviors : ['觅食'], (item: string) => {
              Text(item).fontSize(12).fontColor(GREEN).padding({ left: 10, right: 10, top: 8, bottom: 8 }).backgroundColor(GREEN_SOFT).borderRadius(18)
            }, (item: string) => item)
          }
          Text('观察笔记').fontFamily('serif').fontSize(18).fontColor(INK).width('100%')
          Text(this.record.note || '暂无笔记').fontSize(15).fontColor(INK).lineHeight(24).padding(14).width('100%').backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          if (this.record.photos.length > 0) {
            Text('现场照片').fontFamily('serif').fontSize(18).fontColor(INK).width('100%')
            ForEach(this.record.photos, (uri: string) => {
              Image(uri).width('100%').height(210).objectFit(ImageFit.Cover).borderRadius(8)
            }, (uri: string) => uri)
          }
          this.Privacy()
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
