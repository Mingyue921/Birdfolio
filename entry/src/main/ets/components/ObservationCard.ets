import { Observation } from '../models/BirdModels';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';

@Component
export struct ObservationCard {
  @Prop item: Observation;
  @Prop birdName: string;
  @Prop image: Resource;
  @BuilderParam onSelect: () => void;

  build() {
    Row({ space: 12 }) {
      Image(this.image).width(74).height(74).objectFit(ImageFit.Cover).borderRadius(6)
      Column({ space: 3 }) {
        Row() {
          Text(this.birdName).fontFamily('serif').fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
          Text(this.item.count.toString() + '只').fontSize(12).fontColor(GREEN)
        }
        Text(this.item.placeName + ' · ' + this.item.observedAt).fontSize(12).fontColor(MUTED).maxLines(1)
        Text(this.item.fuzzyLocation ? '⌖ 位置已模糊' : '⌖ 仅自己可见').fontSize(11).fontColor(MUTED)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(22).fontColor(MUTED)
    }.padding(12).width('100%').backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
      .onClick(() => this.onSelect())
  }
}
