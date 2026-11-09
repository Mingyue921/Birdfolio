import { BirdSpecies } from '../../models/BirdModels';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const RED = '#D7644A';

@Component
export struct BirdDetailView {
  @Prop species: BirdSpecies;
  @Prop image: string | Resource;
  @Link detailMode: string;
  @BuilderParam onBack: () => void;
  @BuilderParam onNewObservation: (speciesId: string) => void;

  @Builder DetailTab(label: string) {
    Text(label).fontSize(15).fontWeight(this.detailMode === label ? FontWeight.Bold : FontWeight.Regular).fontColor(this.detailMode === label ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.detailMode === label ? 2 : 0 }, color: GREEN }).onClick(() => this.detailMode = label)
  }

  @Builder Numbered(no: string, title: string, body: string) {
    Row({ space: 12 }) {
      Text(no).fontFamily('serif').fontSize(13).fontColor(GREEN).width(28)
      Column({ space: 3 }) { Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(INK); Text(body).fontSize(13).fontColor(MUTED).lineHeight(19) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%')
  }

  @Builder Feature(label: string) { Text(label).fontSize(12).fontColor(GREEN).padding({ left: 10, right: 10, top: 8, bottom: 8 }).backgroundColor(GREEN_SOFT).borderRadius(18) }
  @Builder Candidate(name: string, summary: string) { Row({ space: 10 }) { Image(name === '大白鹭' ? $r('app.media.great_egret') : $r('app.media.chinese_egret')).width(52).height(52).objectFit(ImageFit.Cover).borderRadius(6); Text(name).fontFamily('serif').fontSize(15).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1); Text(summary).fontSize(12).fontColor(MUTED) }.padding(10).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8) }
  @Builder SettingRow(label: string, value: string) { Row() { Text(label).fontSize(13).fontColor(MUTED); Text(value).fontSize(13).fontColor(INK).layoutWeight(1).textAlign(TextAlign.End) }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8) }
  @Builder AudioPlayer() { Row({ space: 12 }) { Text('音').fontColor(WHITE).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(MUTED).borderRadius(18); Column({ space: 4 }) { Text('音频样本未内置').fontSize(13).fontColor(INK); Text('声音识别与播放功能规划中').fontSize(12).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1) }.padding(12).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8) }
  @Builder Privacy() { Row({ space: 10 }) { Text('!').fontSize(13).fontWeight(FontWeight.Bold).fontColor(RED); Text('珍稀鸟类及巢址坐标已开启模糊保护，仅展示区县级概览').fontSize(12).fontColor(MUTED).lineHeight(18).layoutWeight(1) }.padding(12).backgroundColor(WHITE).border({ width: { left: 3, top: 1, right: 1, bottom: 1 }, color: RED }).borderRadius(8) }

  build() {
    Column() {
      Row() {
        Stack() { Image($r('app.media.ic_back')).width(24).height(24).objectFit(ImageFit.Contain) }.width(44).height(44).borderRadius(8).onClick(() => this.onBack()).accessibilityText('返回')
        Text('鸟种档案').fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
        Stack().width(44).height(44)
      }.height(56).padding({ left: 12, right: 12 }).backgroundColor(WHITE)
      Scroll() {
        Column({ space: 0 }) {
          Image(this.image).alt($r('app.media.background')).width('100%').height(300).objectFit(ImageFit.Cover)
          Column({ space: 15 }) {
            Row() { Column({ space: 3 }) { Text(this.species.name).fontFamily('serif').fontSize(29).fontWeight(FontWeight.Medium).fontColor(INK); Text(this.species.scientificName).fontFamily('serif').fontSize(14).fontStyle(FontStyle.Italic).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(this.species.category).fontSize(12).fontColor(GREEN).padding(8).backgroundColor(GREEN_SOFT).borderRadius(16) }
            if (this.species.id === 'egret') {
              Text('中型涉禽 · 常见留鸟 · 国家“三有”保护动物').fontSize(12).fontColor(MUTED).width('100%')
              Row({ space: 20 }) { this.DetailTab('辨识'); this.DetailTab('声音'); this.DetailTab('习性'); this.DetailTab('分布') }
              if (this.detailMode === '辨识') { Text('关键辨识特征').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%'); this.Numbered('01', '黑色细长嘴', '嘴细直、全黑，与大白鹭的黄色嘴明显不同。'); this.Numbered('02', '黑腿与鲜黄脚趾', '飞行或浅水行走时，黄色脚趾是最醒目的识别点。'); this.Numbered('03', '枕后两枚饰羽', '繁殖期成鸟枕后生出两枚狭长羽冠。'); Image($r('app.media.egret_feet')).width('100%').height(150).objectFit(ImageFit.Cover).borderRadius(8); Text('相似鸟种').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%'); this.Candidate('大白鹭', '体型更大 · 黄嘴'); this.Candidate('黄嘴白鹭', '黄嘴 · 海岸湿地') }
              else if (this.detailMode === '声音') { Text('鸣声记录').fontFamily('serif').fontSize(19).fontColor(INK).width('100%'); this.AudioPlayer(); Text('通常沉默，受惊或飞行时会发出低沉而粗哑的“嘎”声。').fontSize(14).fontColor(MUTED).lineHeight(22) }
              else if (this.detailMode === '习性') { Text('生活习性').fontFamily('serif').fontSize(19).fontColor(INK).width('100%'); Text('单独或成小群活动于浅水区，以小鱼、虾、蛙及水生昆虫为食。觅食时缓慢涉水，也会快速追逐猎物。').fontSize(14).fontColor(MUTED).lineHeight(23); Row({ space: 8 }) { this.Feature('浅水觅食'); this.Feature('集群繁殖'); this.Feature('晨昏活跃') } }
              else { Text('分布与季节').fontFamily('serif').fontSize(19).fontColor(INK).width('100%'); Image($r('app.media.editor_map')).width('100%').height(180).objectFit(ImageFit.Cover).borderRadius(8); Text('广泛分布于中国大部分地区的河流、湖泊、湿地和沿海滩涂。北京春夏秋较常见。').fontSize(14).fontColor(MUTED).lineHeight(22) }
            } else {
              Text(this.species.description).fontSize(14).fontColor(INK).lineHeight(23).width('100%')
              if (this.species.features !== undefined && this.species.features!.length > 0) { Text('关键辨识特征').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%'); ForEach(this.species.features!, (feature: string, index: number) => { this.Numbered((index + 1).toString().padStart(2, '0'), feature, '请结合照片中的羽色、体型和活动环境综合确认。') }, (feature: string) => feature) }
              this.SettingRow('分类', this.species.category)
              this.SettingRow('记录地区', this.species.regions.join(' · '))
              if (this.species.dataSource === 'GBIF') { Text('数据来源：GBIF · 分类与出现记录以来源页为准').fontSize(12).fontColor(GREEN).width('100%') }
            }
            if (this.species.imageCreator !== undefined && this.species.imageCreator!.length > 0) { Text('图片：' + this.species.imageCreator! + ' · ' + this.species.imageLicense! + ' · 来源详情已保存在许可清单').fontSize(11).fontColor(MUTED).width('100%') }
            this.Privacy()
          }.padding({ left: 16, right: 16, top: 18, bottom: 24 }).backgroundColor(BG).borderRadius({ topLeft: 16, topRight: 16 }).margin({ top: -14 })
        }
      }.layoutWeight(1).scrollBar(BarState.Off)
      Button('＋  记录我看到了').width('92%').height(48).backgroundColor(GREEN).borderRadius(8).margin({ top: 8, bottom: 10 }).onClick(() => this.onNewObservation(this.species.id))
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
