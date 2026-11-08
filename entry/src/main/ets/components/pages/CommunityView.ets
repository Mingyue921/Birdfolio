import { AuthMode } from '../../models/BetaModels';
import { BackendStatus, CommunityPost } from '../../models/BirdModels';

const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const BLUE = '#4F8396';
const RED = '#D7644A';
const AMBER = '#E5A832';
const SERIF = 'serif';

@Component
export struct CommunityView {
  @Link mode: string;
  @Prop backendMessage: string;
  @Prop backendStatus: BackendStatus;
  @Prop loading: boolean;
  @Prop authMode: AuthMode;
  @Prop posts: CommunityPost[];
  @Prop postSpeciesNames: string[];
  @Prop postTimes: string[];
  @Prop postMediaUrls: string[];
  @BuilderParam onPublish: () => void;
  @BuilderParam onPlanningNotice: () => void;
  @BuilderParam onModeChange: (mode: string) => void;
  @BuilderParam onOpenPost: (id: string) => void;

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
    }
    .padding(12)
    .backgroundColor(WHITE)
    .border({ width: 1, color: BORDER })
    .borderRadius(8)
    .onClick(() => this.onOpenPost(post.id))
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 2 }) {
            Text('观鸟社区').fontFamily(SERIF).fontSize(24).fontWeight(FontWeight.Medium).fontColor(INK)
            Text(this.backendMessage).fontSize(11).fontColor(this.backendStatus === 'online' ? GREEN : MUTED)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Stack() {
            Image($r('app.media.ic_add')).width(24).height(24).objectFit(ImageFit.Contain)
          }.width(44).height(44).borderRadius(8).onClick(() => this.onPublish()).accessibilityText('发布')
        }
        Row({ space: 24 }) {
          Text('关注 · 规划中').fontSize(15).fontWeight(FontWeight.Regular).fontColor(MUTED).height(36).padding({ bottom: 7 }).onClick(() => this.onPlanningNotice())
          Text('发现').fontSize(15).fontWeight(this.mode === '发现' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.mode === '发现' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.mode === '发现' ? 2 : 0 }, color: GREEN }).onClick(() => { this.mode = '发现'; this.onModeChange('发现') })
          Text('附近').fontSize(15).fontWeight(this.mode === '附近' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.mode === '附近' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.mode === '附近' ? 2 : 0 }, color: GREEN }).onClick(() => { this.mode = '附近'; this.onModeChange('附近') })
        }
        if (this.loading && this.posts.length === 0) {
          Text('正在加载社区内容…').fontSize(13).fontColor(MUTED).padding(24).width('100%').textAlign(TextAlign.Center)
        }
        ForEach(this.posts, (item: CommunityPost, index: number) => {
          this.PostCard(item, index)
        }, (item: CommunityPost) => item.id)
        if (!this.loading && this.posts.length === 0) {
          Text(this.authMode === 'guest' ? '登录后查看社区内容，游客可继续使用本地观察。' : '暂时还没有符合条件的内容。')
            .fontSize(13)
            .fontColor(MUTED)
            .padding(24)
            .width('100%')
            .textAlign(TextAlign.Center)
            .backgroundColor(WHITE)
            .borderRadius(8)
        }
      }.padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
