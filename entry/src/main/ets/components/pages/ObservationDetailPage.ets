import { Observation } from '../../models/BirdModels';
import { ObservationDetailView } from '../ObservationDetailView';
import { AppStateView } from '../common/AppStateView';

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
      Column() {
        AppStateView({ type: 'error', title: '找不到这条观察记录', message: '记录可能已被删除，或尚未从其他设备同步。', actionLabel: '返回观察列表', onAction: () => this.onBack() })
      }.justifyContent(FlexAlign.Center).padding(20).layoutWeight(1).width('100%').backgroundColor(BG)
    } else {
      ObservationDetailView({ record: this.record!, birdName: this.birdName, scientificName: this.scientificName, image: this.image, onBack: () => this.onBack(), onEdit: () => this.onEdit(), onDelete: () => this.onDelete(), onCreateJournal: () => this.onCreateJournal() })
    }
  }
}
