import { AuthMode } from '../../models/BetaModels';
import { BackendStatus, CommunityPost, JournalBook, Observation } from '../../models/BirdModels';
import { ObservationCard } from '../ObservationCard';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const BLUE = '#4F8396';
const BLUE_SOFT = '#E5F0F3';
const RED = '#D7644A';
const AMBER = '#E5A832';
const SERIF = 'serif';

@Component
export struct ProfileView {
  @Link mode: string;
  @Prop backendStatus: BackendStatus;
  @Prop backendStatusLabel: string;
  @Prop displayName: string;
  @Prop bio: string;
  @Prop avatarUri: string;
  @Prop authMode: AuthMode;
  @Prop authEmail: string;
  @Prop observationCount: number;
  @Prop speciesCount: number;
  @Prop placeCount: number;
  @Prop observations: Observation[];
  @Prop observationBirdNames: string[];
  @Prop observationBirdImages: Resource[];
  @Prop posts: CommunityPost[];
  @Prop postSpeciesNames: string[];
  @Prop postTimes: string[];
  @Prop postMediaUrls: string[];
  @Prop books: JournalBook[];
  @Prop photoUris: string[];
  @Prop photoObservationIds: string[];
  @BuilderParam onRetrySync: () => void;
  @BuilderParam onOpenSettings: () => void;
  @BuilderParam onEditProfile: () => void;
  @BuilderParam onOpenMap: () => void;
  @BuilderParam onOpenStats: () => void;
  @BuilderParam onSelectObservation: (id: string) => void;
  @BuilderParam onOpenPost: (id: string) => void;
  @BuilderParam onOpenBook: (id: string) => void;
  @BuilderParam onOpenShop: () => void;

  @Builder Stat(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK)
      Text(label).fontSize(12).fontColor(MUTED)
    }.layoutWeight(1)
  }

  @Builder Entry(icon: string, title: string, color: string, action: () => void) {
    Row({ space: 10 }) {
      Text(icon).fontSize(19).fontColor(INK)
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(INK)
    }.layoutWeight(1).padding(16).backgroundColor(color).borderRadius(8).onClick(() => action())
  }

  @Builder ProfileTab(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(this.mode === title ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.mode === title ? GREEN : MUTED)
      .height(36)
      .padding({ bottom: 7 })
      .border({ width: { bottom: this.mode === title ? 2 : 0 }, color: GREEN })
      .onClick(() => this.mode = title)
  }

  @Builder EmptyState(message: string) {
    Column({ space: 7 }) {
      Text(message).fontSize(14).fontColor(INK)
      Text('这里仅展示你实际保存的内容').fontSize(12).fontColor(MUTED)
    }.justifyContent(FlexAlign.Center).width('100%').height(112).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
  }

  @Builder PostImage(post: CommunityPost, index: number) {
    if (post.imageUrl === '/seed/community_egret' || post.imageUrl.length === 0 && post.type === 'photo') {
      Image($r('app.media.community_egret')).width('100%').height(250).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6)
    } else if (post.imageUrl === '/seed/community_journal' || post.imageUrl.length === 0) {
      Image($r('app.media.community_journal')).width('100%').height(250).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6)
    } else {
      Image(this.postMediaUrls[index]).width('100%').height(250).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6)
    }
  }

  @Builder PostCard(post: CommunityPost, index: number) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image($r('app.media.community_avatar')).width(38).height(38).objectFit(ImageFit.Cover).borderRadius(19)
        Column({ space: 1 }) {
          Text(post.authorName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK)
          Text((this.postTimes[index] || '') + ' · ' + (post.placeName || '未填写地点')).fontSize(11).fontColor(MUTED)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(post.type === 'journal' ? '手账' : '观察').fontSize(11).fontColor(GREEN).padding({ left: 8, right: 8, top: 5, bottom: 5 }).backgroundColor(GREEN_SOFT).borderRadius(12)
      }
      this.PostImage(post, index)
      Text(post.title).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
      Text(post.body).fontSize(14).fontColor(INK).lineHeight(21).maxLines(3).width('100%')
      Text((this.postSpeciesNames[index] || '未知鸟种') + ' · ' + (post.behavior || '观察记录')).fontSize(12).fontColor(BLUE)
      Row({ space: 24 }) {
        Text((post.liked ? '♥ ' : '♡ ') + post.likeCount.toString()).fontSize(14).fontColor(post.liked ? RED : MUTED)
        Text('◯ ' + post.commentCount.toString()).fontSize(14).fontColor(MUTED)
        Text((post.favorited ? '★ ' : '☆ ') + post.favoriteCount.toString()).fontSize(14).fontColor(post.favorited ? AMBER : MUTED)
      }
    }.padding(12).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onOpenPost(post.id))
  }

  @Builder BookCard(book: JournalBook) {
    Row({ space: 12 }) {
      Image(book.coverImageUri !== undefined && book.coverImageUri.length > 0 ? book.coverImageUri : $r('app.media.journal_waterbirds'))
        .width(76)
        .height(92)
        .objectFit(ImageFit.Contain)
        .backgroundColor(GREEN_SOFT)
        .borderRadius(6)
      Column({ space: 5 }) {
        Text(book.title).fontFamily(SERIF).fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(2)
        Text(book.pages.length.toString() + ' 页 · ' + book.observationIds.length.toString() + ' 条关联观察').fontSize(12).fontColor(MUTED)
        Text('继续编辑  ›').fontSize(12).fontColor(GREEN)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.padding(12).width('100%').backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onOpenBook(book.id))
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 8 }) {
          Text('我的').fontFamily(SERIF).fontSize(24).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
          Text(this.backendStatusLabel).fontSize(11).fontColor(this.backendStatus === 'online' ? GREEN : AMBER).onClick(() => this.onRetrySync())
          Stack() { Image($r('app.media.ic_settings')).width(24).height(24).objectFit(ImageFit.Contain) }
            .width(44).height(44).borderRadius(8).onClick(() => this.onOpenSettings()).accessibilityText('设置')
        }.width('100%')
        Row({ space: 14 }) {
          Image(this.avatarUri.length > 0 ? this.avatarUri : $r('app.media.avatar_sparrow')).width(76).height(76).objectFit(ImageFit.Cover).borderRadius(38)
          Column({ space: 4 }) {
            Text(this.displayName).fontFamily(SERIF).fontSize(21).fontWeight(FontWeight.Medium).fontColor(INK)
            Text(this.authMode === 'authenticated' ? '@' + this.authEmail : '@本机用户').fontSize(12).fontColor(MUTED)
            Text(this.bio).fontSize(13).fontColor(INK)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('编辑').height(36).fontSize(13).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onEditProfile())
        }
        Text('“每一次停驻，都是自然写下的一行旁注。”').fontFamily(SERIF).fontSize(14).fontColor(MUTED).width('100%')
        Row() {
          this.Stat('今年观察', this.observationCount.toString())
          this.Stat('已记录鸟种', this.speciesCount.toString())
          this.Stat('地点足迹', this.placeCount.toString())
        }.padding({ top: 18, bottom: 18 }).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8)
        Row({ space: 10 }) {
          this.Entry('⌖', '地图足迹', BLUE_SOFT, () => this.onOpenMap())
          this.Entry('↗', '年度统计', GREEN_SOFT, () => this.onOpenStats())
        }
        Row({ space: 20 }) {
          this.ProfileTab('作品')
          this.ProfileTab('观察')
          this.ProfileTab('相册')
          this.ProfileTab('收藏')
        }
        if (this.mode === '观察') {
          ForEach(this.observations, (item: Observation, index: number) => {
            ObservationCard({
              item: item,
              birdName: this.observationBirdNames[index] || '未知鸟种',
              image: this.observationBirdImages[index] || $r('app.media.background'),
              onSelect: () => this.onSelectObservation(item.id)
            })
          }, (item: Observation) => item.id)
          if (this.observations.length === 0) this.EmptyState('还没有观察记录')
        } else if (this.mode === '相册') {
          Grid() {
            ForEach(this.photoUris, (uri: string, index: number) => {
              GridItem() {
                Image(uri).alt($r('app.media.background')).width('100%').aspectRatio(1).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6)
                  .onClick(() => this.onSelectObservation(this.photoObservationIds[index] || ''))
              }
            }, (uri: string, index: number) => uri + index.toString())
          }.columnsTemplate('1fr 1fr').columnsGap(8).rowsGap(8)
          if (this.photoUris.length === 0) this.EmptyState('观察记录中还没有照片')
        } else {
          ForEach(this.posts, (item: CommunityPost, index: number) => {
            this.PostCard(item, index)
          }, (item: CommunityPost) => item.id)
          if (this.mode === '作品') {
            ForEach(this.books, (book: JournalBook) => { this.BookCard(book) }, (book: JournalBook) => book.id)
            if (this.posts.length === 0 && this.books.length === 0) this.EmptyState('还没有发布或创作作品')
          } else if (this.posts.length === 0) {
            this.EmptyState('还没有收藏的社区内容')
          }
        }
        Row() {
          Text('我的素材与模板').fontSize(15).fontColor(INK).layoutWeight(1)
          Text('进入商店  ›').fontSize(13).fontColor(GREEN)
        }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onOpenShop())
      }.padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
