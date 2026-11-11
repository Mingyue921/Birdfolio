import { LegalDocumentContent, LegalSection } from '../../data/LegalContent';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const AMBER = '#9A6818';

@Component
export struct LegalDocumentView {
  @Prop document: LegalDocumentContent;
  @BuilderParam onBack: () => void;

  build() {
    Column() {
      PageHeaderView({ title: this.document.title, onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 14 }) {
          Text(this.document.notice).fontSize(12).fontColor(AMBER).lineHeight(19).width('100%')
            .padding(12).backgroundColor('#FFF6E3').border({ width: 1, color: '#EDD39E' }).borderRadius(8)
          Text('版本 ' + this.document.version).fontSize(12).fontColor(MUTED).width('100%')
          ForEach(this.document.sections, (section: LegalSection) => {
            Column({ space: 7 }) {
              Text(section.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
              Text(section.body).fontSize(13).fontColor(MUTED).lineHeight(21).width('100%')
            }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).width('100%')
          })
          Text('完整草案和工程合规清单位于项目 docs/legal。正式发布文本必须补齐待确认信息并完成专业复核。')
            .fontSize(12).fontColor(MUTED).lineHeight(19).width('100%').padding({ top: 6, bottom: 18 })
        }.padding({ left: 16, right: 16, top: 14 }).width('100%')
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
