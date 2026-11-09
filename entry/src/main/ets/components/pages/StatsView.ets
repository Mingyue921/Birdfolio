import { MonthlyObservationStat, Observation, PlaceObservationStat, SpeciesObservationStat, YearStats } from '../../models/BirdModels';
import { ObservationService } from '../../services/ObservationService';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const BLUE = '#4F8396';

@Component
export struct StatsView {
  @Prop records: Observation[];
  @Link selectedYear: number;
  @BuilderParam birdName: (id: string) => string;
  @BuilderParam onBack: () => void;
  @BuilderParam onNewObservation: () => void;

  private stats(): YearStats { return ObservationService.yearStats(this.records, this.selectedYear); }
  private maxMonth(): number { let max = 1; this.stats().monthly.forEach((item: MonthlyObservationStat) => { if (item.count > max) max = item.count; }); return max; }
  private placeTotal(): number { let total = 0; this.stats().places.forEach((item: PlaceObservationStat) => total += item.recordCount); return Math.max(1, total); }

  @Builder Metric(label: string, value: string) {
    Row({ space: 12 }) {
      Text(value).fontFamily('serif').fontSize(27).fontWeight(FontWeight.Medium).fontColor(GREEN).width(44)
      Column({ space: 3 }) { Text(label).fontSize(13).fontColor(INK); Text('本年度').fontSize(10).fontColor(MUTED) }.alignItems(HorizontalAlign.Start)
    }.height(78).padding({ left: 14, right: 12 }).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  @Builder Rank(no: string, name: string, count: string, width: number) {
    Row({ space: 12 }) {
      Text(no).fontFamily('serif').fontSize(18).fontColor(GREEN).width(28).height(28).textAlign(TextAlign.Center).backgroundColor(GREEN_SOFT).borderRadius(14)
      Column({ space: 7 }) {
        Row() { Text(name).fontSize(15).fontColor(INK).layoutWeight(1); Text(count).fontSize(12).fontColor(MUTED) }
        Stack({ alignContent: Alignment.Start }) { Column().width('100%').height(6).backgroundColor('#EDF0EC').borderRadius(3); Column().width(width.toString() + '%').height(6).backgroundColor(GREEN).borderRadius(3) }.width('100%').height(6)
      }.layoutWeight(1)
    }.padding(13).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  @Builder PlaceShare(name: string, count: number, percent: number) {
    Column({ space: 7 }) {
      Row() { Text(name).fontSize(14).fontColor(INK).layoutWeight(1); Text(count.toString() + ' 次 · ' + percent.toString() + '%').fontSize(12).fontColor(MUTED) }
      Stack({ alignContent: Alignment.Start }) { Column().width('100%').height(7).backgroundColor('#EDF0EC').borderRadius(4); Column().width(Math.max(6, percent).toString() + '%').height(7).backgroundColor(BLUE).borderRadius(4) }.width('100%').height(7)
    }.width('100%')
  }

  @Builder SpeciesTimeline(no: number, name: string, count: number) {
    Row({ space: 12 }) {
      Text(no.toString()).fontSize(11).fontColor(WHITE).width(25).height(25).textAlign(TextAlign.Center).backgroundColor(GREEN).borderRadius(13)
      Text(name).fontFamily('serif').fontSize(15).fontColor(INK).layoutWeight(1)
      Text(count.toString() + ' 次记录').fontSize(12).fontColor(MUTED)
    }.height(52).padding({ left: 13, right: 13 }).border({ width: { bottom: 1 }, color: BORDER })
  }

  build() {
    Column() {
      PageHeaderView({ title: '年度统计', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 20 }) {
          Row() {
            Column({ space: 3 }) { Text(this.selectedYear.toString() + ' · 我的观鸟年').fontFamily('serif').fontSize(22).fontColor(INK); Text('每一次相遇，都在这里留下坐标').fontSize(12).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Row({ space: 8 }) { ForEach(ObservationService.years(this.records), (year: number) => { Text(year.toString()).fontSize(13).fontColor(this.selectedYear === year ? WHITE : GREEN).padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(this.selectedYear === year ? GREEN : GREEN_SOFT).borderRadius(8).onClick(() => this.selectedYear = year) }, (year: number) => year.toString()) }
          }
          Grid() { this.Metric('观察次数', this.stats().observations.toString()); this.Metric('记录鸟种', this.stats().speciesCount.toString()); this.Metric('地点足迹', this.stats().placeCount.toString()); this.Metric('鸟只总数', this.stats().birdCount.toString()) }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10)
          Text('全年观察趋势').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
          Row({ space: 4 }) { ForEach(this.stats().monthly, (item: MonthlyObservationStat) => { Column({ space: 5 }) { Text(item.count > 0 ? item.count.toString() : '').fontSize(9).fontColor(GREEN).height(14); Column().width(16).height(Math.max(4, item.count / this.maxMonth() * 104)).backgroundColor(item.count > 0 ? GREEN : BORDER).borderRadius({ topLeft: 4, topRight: 4 }); Text(item.month.toString() + '月').fontSize(8).fontColor(MUTED) }.layoutWeight(1).height(145).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center) }, (item: MonthlyObservationStat) => item.month.toString()) }.height(174).padding({ left: 10, right: 10, top: 12, bottom: 10 }).alignItems(VerticalAlign.Bottom).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          Text('常遇鸟种').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
          ForEach(this.stats().species.slice(0, 5), (item: SpeciesObservationStat, index: number) => { this.Rank((index + 1).toString(), this.birdName(item.speciesId), item.count.toString() + ' 次', Math.max(8, Math.round(item.ratio * 100))) }, (item: SpeciesObservationStat) => item.speciesId)
          if (this.stats().species.length === 0) { Text('该年份暂无观察记录').fontSize(14).fontColor(MUTED).padding(16).width('100%').backgroundColor(WHITE).borderRadius(8) }
          Text('观察地点构成').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
          Column({ space: 13 }) { ForEach(this.stats().places.slice(0, 4), (item: PlaceObservationStat) => { this.PlaceShare(item.placeName, item.recordCount, Math.round(item.recordCount / this.placeTotal() * 100)) }, (item: PlaceObservationStat) => item.placeName) }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          Text('年度鸟种清单').fontFamily('serif').fontSize(19).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
          Column({ space: 0 }) { ForEach(this.stats().species, (item: SpeciesObservationStat, index: number) => { this.SpeciesTimeline(index + 1, this.birdName(item.speciesId), item.count) }, (item: SpeciesObservationStat) => item.speciesId) }.backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
          if (this.stats().observations === 0) { Button('＋ 新建观察').width('100%').height(48).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onNewObservation()) }
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }.backgroundColor(BG)
  }
}
