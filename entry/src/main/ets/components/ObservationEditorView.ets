import { BirdSpecies } from '../models/BirdModels';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';

@Component
export struct ObservationEditorView {
  @Link speciesId: string;
  @Link countText: string;
  @Link place: string;
  @Link behavior: string;
  @Link note: string;
  @Link fuzzy: boolean;
  @Link locationStatus: string;
  @Link latitude: number;
  @Link longitude: number;
  @BuilderParam onUseCurrentLocation: () => void;
  @Prop speciesImage: Resource;
  @Prop species: BirdSpecies;
  @Prop editing: boolean;
  @BuilderParam onBack: () => void;
  @BuilderParam onSpeciesPicker: () => void;
  @BuilderParam onSave: () => void;

  @Builder Label(t: string) {
    Text(t).fontSize(13).fontWeight(FontWeight.Medium).fontColor(MUTED).width('100%')
  }

  @Builder BehaviorChip(t: string) {
    Text(t).fontSize(13).fontColor(this.behavior === t ? GREEN : MUTED)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.behavior === t ? GREEN_SOFT : WHITE)
      .border({ width: 1, color: this.behavior === t ? GREEN : BORDER }).borderRadius(18)
      .onClick(() => this.behavior = t)
  }

  build() {
    Column() {
      Row() {
        Button('‹').width(44).height(44).fontSize(28).fontColor(INK).backgroundColor(WHITE).onClick(() => this.onBack())
        Text(this.editing ? '编辑观察' : '确认观察').fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).textAlign(TextAlign.Center).layoutWeight(1)
        Stack().width(44).height(44)
      }.height(58).padding({ left: 12, right: 12 }).backgroundColor(WHITE).border({ width: { bottom: 1 }, color: BORDER })
      Scroll() {
        Column({ space: 13 }) {
          Row({ space: 12 }) {
            Image(this.speciesImage).width(84).height(84).objectFit(ImageFit.Cover).borderRadius(6)
            Column({ space: 4 }) {
              Text(this.species.name).fontFamily('serif').fontSize(20).fontWeight(FontWeight.Medium).fontColor(INK)
              Text(this.species.scientificName).fontFamily('serif').fontSize(12).fontStyle(FontStyle.Italic).fontColor(MUTED)
              Button('更换鸟种').height(34).fontSize(13).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(17).onClick(() => this.onSpeciesPicker())
            }.alignItems(HorizontalAlign.Start)
          }.padding(12).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          this.Label('数量')
          TextInput({ text: this.countText, placeholder: '1' }).height(46).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((v: string) => this.countText = v)
          this.Label('地点')
          TextInput({ text: this.place, placeholder: '选择或输入地点' }).height(46).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((v: string) => this.place = v)
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(this.locationStatus).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.latitude !== 0 || this.longitude !== 0 ? GREEN : INK)
              Text(this.latitude !== 0 || this.longitude !== 0 ? '地图将显示该观察地点' : '没有坐标也可以保存，地图不会生成标记').fontSize(12).fontColor(MUTED)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button(this.latitude !== 0 || this.longitude !== 0 ? '更新位置' : '使用当前位置').height(38).fontSize(12).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onUseCurrentLocation())
          }.padding(12).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          this.Label('观察行为')
          Row({ space: 8 }) { this.BehaviorChip('觅食'); this.BehaviorChip('鸣叫'); this.BehaviorChip('飞行'); this.BehaviorChip('休息') }
          this.Label('观察笔记')
          TextArea({ text: this.note, placeholder: '记录羽色、行为、天气和当时的感受' }).height(120).fontSize(15).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((v: string) => this.note = v)
          Row() {
            Column({ space: 3 }) { Text('发布时模糊位置').fontSize(15).fontWeight(FontWeight.Medium).fontColor(INK); Text('精确位置仅自己可见').fontSize(12).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.fuzzy }).selectedColor(GREEN).onChange((v: boolean) => this.fuzzy = v)
          }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          Button(this.editing ? '保存修改' : '保存观察').width('100%').height(50).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onSave())
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
