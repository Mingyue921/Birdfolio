import { Observation } from '../../models/BirdModels';
import { ObservationDetailView } from '../ObservationDetailView';

const BG = '#F9FAF7';
const INK = '#1C241F';
const MUTED = '#5E6861';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';

@Component
export struct ObservationDetailPage {
  @Prop record: Observation | undefined;
  @Prop birdName: string;
  @Prop scientificName: string;
  @Prop image: Resource;
  @BuilderParam onBack: () => void;
  @BuilderParam onEdit: () => void;
  @BuilderParam onDelete: () => void;
  @BuilderParam onCreateJournal: () => void;

  build() {
    if (this.record === undefined) {
      Column({ space: 12 }) {
        Text('找不到这条观察记录').fontFamily('serif').fontSize(20).fontColor(INK)
        Text('记录可能已被删除或尚未同步。').fontSize(13).fontColor(MUTED)
        Button('返回观察列表').height(46).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onBack())
      }.justifyContent(FlexAlign.Center).layoutWeight(1).width('100%').backgroundColor(BG)
    } else {
      ObservationDetailView({ record: this.record!, birdName: this.birdName, scientificName: this.scientificName, image: this.image, onBack: () => this.onBack(), onEdit: () => this.onEdit(), onDelete: () => this.onDelete(), onCreateJournal: () => this.onCreateJournal() })
    }
  }
}
