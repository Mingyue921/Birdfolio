import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const RED = '#D7644A';
const AMBER = '#E5A832';

@Component
export struct PublishView {
  @Link mode: string;
  @Link title: string;
  @Link body: string;
  @Link behavior: string;
  @Link postVisibility: string;
  @Prop photoUri: string;
  @Prop speciesName: string;
  @Prop draftCount: number;
  @Prop hasActiveDraft: boolean;
  @Prop publishing: boolean;
  @BuilderParam onBack: () => void;
  @BuilderParam onRestoreDraft: () => void;
  @BuilderParam onPickPhoto: () => void;
  @BuilderParam onPickSpecies: () => void;
  @BuilderParam onSaveDraft: () => void;
  @BuilderParam onPublish: () => void;

  @Builder BehaviorChip(label: string) { Text(label).fontSize(13).fontColor(this.behavior === label ? GREEN : MUTED).padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(this.behavior === label ? GREEN_SOFT : WHITE).border({ width: 1, color: this.behavior === label ? GREEN : BORDER }).borderRadius(18).onClick(() => this.behavior = label) }
  @Builder SettingAction(label: string, value: string, action: () => void) { Row() { Text(label).fontSize(13).fontColor(MUTED); Text(value).fontSize(13).fontColor(INK).layoutWeight(1).textAlign(TextAlign.End) }.height(48).padding({ left: 14, right: 14 }).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => action()) }
  @Builder Privacy() { Row({ space: 10 }) { Text('!').fontSize(13).fontWeight(FontWeight.Bold).fontColor(RED); Text('珍稀鸟类及巢址坐标已开启模糊保护，仅展示区县级概览').fontSize(12).fontColor(MUTED).lineHeight(18).layoutWeight(1) }.padding(12).backgroundColor(WHITE).border({ width: { left: 3, top: 1, right: 1, bottom: 1 }, color: RED }).borderRadius(8) }

  build() {
    Column() {
      PageHeaderView({ title: '发布', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 15 }) {
          Row({ space: 22 }) {
            Text('照片动态').fontSize(15).fontWeight(this.mode === '照片动态' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.mode === '照片动态' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.mode === '照片动态' ? 2 : 0 }, color: GREEN }).onClick(() => this.mode = '照片动态')
            Text('手账作品').fontSize(15).fontWeight(this.mode === '手账作品' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.mode === '手账作品' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.mode === '手账作品' ? 2 : 0 }, color: GREEN }).onClick(() => this.mode = '手账作品')
          }
          if (this.draftCount > 0 && !this.hasActiveDraft) { Row() { Text('本机有 ' + this.draftCount.toString() + ' 篇未发送草稿').fontSize(12).fontColor(AMBER).layoutWeight(1); Text('恢复最近一篇 ›').fontSize(12).fontColor(GREEN).onClick(() => this.onRestoreDraft()) }.padding(12).backgroundColor('#FFF5D8').borderRadius(8) }
          Row({ space: 10 }) { Image(this.photoUri.length > 0 ? this.photoUri : (this.mode === '照片动态' ? $r('app.media.observation_egret') : $r('app.media.journal_waterbirds'))).width(104).height(104).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(8); Text('＋').fontSize(28).fontColor(MUTED).width(104).height(104).textAlign(TextAlign.Center).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onPickPhoto()) }
          TextInput({ text: this.title, placeholder: '给这次相遇写个标题' }).height(48).fontSize(17).fontFamily('serif').fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((value: string) => this.title = value)
          TextArea({ text: this.body, placeholder: '分享观察过程、鸟的行为和当时的感受……' }).height(150).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((value: string) => this.body = value)
          Text('观察行为').fontSize(13).fontWeight(FontWeight.Medium).fontColor(MUTED).width('100%')
          Row({ space: 8 }) { this.BehaviorChip('觅食'); this.BehaviorChip('涉水'); this.BehaviorChip('飞行'); this.BehaviorChip('休息') }
          this.SettingAction('鸟种', this.speciesName + '  ›', () => this.onPickSpecies())
          this.SettingAction('可见范围', this.postVisibility + '  ›', () => this.postVisibility = this.postVisibility === '所有人' ? '仅自己' : '所有人')
          this.Privacy()
        }.padding({ left: 16, right: 16, bottom: 24 })
      }.layoutWeight(1)
      Row({ space: 10 }) { Button('存草稿').layoutWeight(1).height(48).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onSaveDraft()); Button(this.publishing ? '发布中…' : '发布').enabled(!this.publishing).layoutWeight(2).height(48).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onPublish()) }.padding(12).backgroundColor(WHITE)
    }.backgroundColor(BG)
  }
}
