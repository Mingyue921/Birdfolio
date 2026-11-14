import { JournalBook, Observation } from '../../models/BirdModels';
import { AppStateView } from '../common/AppStateView';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const RED = '#D7644A';
const AMBER = '#E5A832';
const SERIF = 'serif';

@Component
export struct JournalBooksView {
  @Prop books: JournalBook[];
  @Prop recentRecords: Observation[];
  @Prop recentBirdNames: string[];
  @Prop recentBirdImages: Resource[];
  @BuilderParam onOpenShop: () => void;
  @BuilderParam onCreateBook: () => void;
  @BuilderParam onOpenBook: (id: string) => void;
  @BuilderParam onDeleteBook: (id: string) => void;
  @BuilderParam onOpenObservations: () => void;
  @BuilderParam onCreateFromObservation: (id: string) => void;
  @BuilderParam onOpenWorks: () => void;

  @Builder SectionLink(title: string, detail: string, action: () => void) {
    Row() {
      Text(title).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
      Text(detail).fontSize(13).fontColor(GREEN)
    }.width('100%').height(32).onClick(() => action())
  }

  @Builder SampleCover(title: string, imageResource: Resource) {
    GridItem() {
      Column({ space: 8 }) {
        Image(imageResource).width('100%').height(155).objectFit(ImageFit.Cover).borderRadius(4)
        Text(title).fontFamily(SERIF).fontSize(14).fontColor(INK).width('100%').maxLines(2)
        Text('示例封面').fontSize(11).fontColor(MUTED)
      }.padding(9).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Text('我的手账').fontFamily(SERIF).fontSize(24).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
          Stack() {
            Image($r('app.media.ic_shop')).width(24).height(24).objectFit(ImageFit.Contain)
          }.width(44).height(44).borderRadius(8).onClick(() => this.onOpenShop()).accessibilityText('素材商店')
        }
        Row() {
          Text('我的草稿').fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
          Text(this.books.length.toString() + ' 本').fontSize(12).fontColor(AMBER)
        }
        Button('＋ 新建手账').width('100%').height(46).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onCreateBook())
        if (this.books.length === 0) {
          AppStateView({ type: 'empty', title: '还没有手账', message: '可新建空白手账，或从一条真实观察开始。', actionLabel: '新建手账', onAction: () => this.onCreateBook() })
        }
        ForEach(this.books, (book: JournalBook) => {
          Row({ space: 14 }) {
            Image(book.coverImageUri && book.coverImageUri.length > 0 ? book.coverImageUri : $r('app.media.journal_draft')).width(102).height(136).objectFit(ImageFit.Cover).borderRadius(6)
            Column({ space: 7 }) {
              Text(book.title).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK)
              Text(book.pages.length.toString() + '页 · ' + book.observationIds.length.toString() + '条观察').fontSize(12).fontColor(MUTED)
              Text(book.updatedAt === book.createdAt ? '刚刚创建' : '已自动保存').fontSize(12).fontColor(GREEN)
              Row({ space: 8 }) {
                Button('继续编辑').height(38).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onOpenBook(book.id))
                Button('删除').height(38).fontColor(RED).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onDeleteBook(book.id))
              }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
        }, (book: JournalBook) => book.id)

        this.SectionLink('从观察开始', '查看全部', () => this.onOpenObservations())
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.recentRecords, (item: Observation, index: number) => {
              Column({ space: 5 }) {
                Image(this.recentBirdImages[index] || $r('app.media.background')).width(116).height(88).objectFit(ImageFit.Cover).borderRadius(6)
                Text(this.recentBirdNames[index] || '未知鸟种').fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK)
                Text(item.observedAt).fontSize(11).fontColor(MUTED)
              }.alignItems(HorizontalAlign.Start).onClick(() => this.onCreateFromObservation(item.id))
            }, (item: Observation) => item.id)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

        this.SectionLink('灵感模板', '示例内容，不是用户作品', () => this.onOpenWorks())
        Grid() {
          this.SampleCover('北京水鸟观察手册', $r('app.media.journal_waterbirds'))
          this.SampleCover('秋日林鸟晨鸣志', $r('app.media.journal_song'))
          this.SampleCover('湿地鹭类辨识图谱', $r('app.media.journal_herons'))
          this.SampleCover('刺槐林初遇歌鸲', $r('app.media.journal_rubythroat'))
        }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10)
        Row({ space: 10 }) {
          Text('!').fontSize(13).fontWeight(FontWeight.Bold).fontColor(RED)
          Text('珍稀鸟类及巢址坐标已开启模糊保护，仅展示区县级概览').fontSize(12).fontColor(MUTED).lineHeight(18).layoutWeight(1)
        }.padding(12).backgroundColor(WHITE).border({ width: { left: 3, top: 1, right: 1, bottom: 1 }, color: RED }).borderRadius(8)
      }.padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
