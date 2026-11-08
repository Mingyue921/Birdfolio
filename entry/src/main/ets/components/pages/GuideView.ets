import { BirdSpecies } from '../../models/BirdModels';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const SERIF = 'serif';

@Component
export struct GuideView {
  @Link keyword: string;
  @Link mode: string;
  @Prop species: BirdSpecies[];
  @Prop speciesImages: Resource[];
  @Prop speciesFrequencies: number[];
  @Prop catalogCount: number;
  @Prop recordedSpeciesCount: number;
  @Prop loading: boolean;
  @Prop message: string;
  @BuilderParam onSearchOnline: (keyword: string) => void;
  @BuilderParam onModeChange: (mode: string) => void;
  @BuilderParam onSelectSpecies: (id: string) => void;

  @Builder Metric(label: string, value: string) {
    Row({ space: 12 }) {
      Text(value).fontFamily(SERIF).fontSize(27).fontWeight(FontWeight.Medium).fontColor(GREEN).width(52)
      Column({ space: 3 }) {
        Text(label).fontSize(13).fontColor(INK)
        Text('当前数据').fontSize(10).fontColor(MUTED)
      }.alignItems(HorizontalAlign.Start)
    }.layoutWeight(1).height(78).padding({ left: 14, right: 12 }).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  @Builder ModeChip(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.mode === title ? GREEN : MUTED)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.mode === title ? GREEN_SOFT : WHITE)
      .border({ width: 1, color: this.mode === title ? GREEN : BORDER })
      .borderRadius(18)
      .onClick(() => { this.mode = title; this.onModeChange(title) })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 3 }) {
          Text('鸟类图鉴').fontFamily(SERIF).fontSize(24).fontWeight(FontWeight.Medium).fontColor(INK)
          Text('Aves Handbook · 认识身边的有翼邻居').fontSize(13).fontColor(MUTED).maxLines(2)
        }.alignItems(HorizontalAlign.Start).width('100%')

        Row({ space: 10 }) {
          this.Metric('当前图鉴', this.catalogCount.toString() + ' 种')
          this.Metric('已记录鸟种', this.recordedSpeciesCount.toString() + ' 种')
        }
        Row({ space: 8 }) {
          TextInput({ text: this.keyword, placeholder: '搜索中文名、别名或学名' })
            .layoutWeight(1)
            .height(48)
            .fontSize(15)
            .fontColor(INK)
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
            .onChange((value: string) => this.keyword = value)
          Button('GBIF 补充').height(48).fontSize(13).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onSearchOnline(this.keyword))
        }
        Text(this.loading ? '正在从 GBIF 补充在线资料…' : this.message)
          .fontSize(11)
          .fontColor(this.message.startsWith('GBIF 在线') ? GREEN : MUTED)
          .width('100%')
        Scroll() {
          Row({ space: 8 }) {
            this.ModeChip('附近常见')
            this.ModeChip('我见过的')
            this.ModeChip('湿地')
            this.ModeChip('秋季')
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

        ForEach(this.species, (item: BirdSpecies, index: number) => {
          Row({ space: 13 }) {
            Image(item.imageUrl !== undefined && item.imageUrl.length > 0 ? item.imageUrl : (this.speciesImages[index] || $r('app.media.background')))
              .alt($r('app.media.background'))
              .width(90)
              .height(90)
              .objectFit(ImageFit.Cover)
              .borderRadius(6)
            Column({ space: 3 }) {
              Text(item.name).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK)
              Text(item.scientificName).fontFamily(SERIF).fontSize(12).fontStyle(FontStyle.Italic).fontColor(MUTED)
              Text(item.category + ' · ' + item.regions[0]).fontSize(13).fontColor(MUTED)
              Text((this.speciesFrequencies[index] || 0) > 0 ? '✓ 已记录 ' + this.speciesFrequencies[index].toString() + ' 次' : '○ 尚未记录').fontSize(12).fontColor(GREEN)
              if (item.imageCreator !== undefined && item.imageCreator.length > 0) {
                Text('图片：' + item.imageCreator + ' · ' + item.imageLicense).fontSize(9).fontColor(MUTED).maxLines(1)
              }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(22).fontColor(MUTED)
          }
          .padding(12)
          .backgroundColor(WHITE)
          .border({ width: 1, color: BORDER })
          .borderRadius(8)
          .onClick(() => this.onSelectSpecies(item.id))
        }, (item: BirdSpecies) => item.id)
      }.padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
