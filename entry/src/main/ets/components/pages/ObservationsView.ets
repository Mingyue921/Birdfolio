import { Observation } from '../../models/BirdModels';
import { ObservationCard } from '../ObservationCard';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';

@Component
export struct ObservationsView {
  @Link filter: string;
  @Link placeFilter: string;
  @Prop observations: Observation[];
  @Prop birdNames: string[];
  @Prop birdImages: Resource[];
  @BuilderParam onBack: () => void;
  @BuilderParam onSelectObservation: (id: string) => void;
  @BuilderParam onNewObservation: () => void;

  @Builder FilterChip(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.filter === label ? GREEN : MUTED)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.filter === label ? GREEN_SOFT : WHITE)
      .border({ width: 1, color: this.filter === label ? GREEN : BORDER })
      .borderRadius(18)
      .onClick(() => this.filter = label)
  }

  build() {
    Column() {
      PageHeaderView({ title: '全部观察', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            this.FilterChip('全部')
            this.FilterChip('本月')
            this.FilterChip('有照片')
          }
          if (this.placeFilter.length > 0) {
            Row() {
              Text('地点：' + this.placeFilter).fontSize(13).fontColor(GREEN).layoutWeight(1)
              Text('清除筛选').fontSize(12).fontColor(GREEN).onClick(() => this.placeFilter = '')
            }
          }
          Row() {
            Text(this.observations.length.toString() + ' 次观察').fontFamily('serif').fontSize(20).fontColor(INK).layoutWeight(1)
            Text('按时间排序').fontSize(12).fontColor(MUTED)
          }
          ForEach(this.observations, (item: Observation, index: number) => {
            ObservationCard({
              item: item,
              birdName: this.birdNames[index] || '',
              image: this.birdImages[index],
              onSelect: () => this.onSelectObservation(item.id)
            })
          }, (item: Observation) => item.id)
          Button('＋  新建观察').width('100%').height(48).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onNewObservation())
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
