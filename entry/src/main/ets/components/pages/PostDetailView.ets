import { CommunityPost, PostComment } from '../../models/BirdModels';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const RED = '#D7644A';
const AMBER = '#E5A832';

@Component
export struct PostDetailView {
  @Prop post: CommunityPost | undefined;
  @Prop comments: PostComment[];
  @Prop speciesName: string;
  @Prop scientificName: string;
  @Prop mediaUrl: string;
  @Link commentDraft: string;
  @BuilderParam onBack: () => void;
  @BuilderParam onReturnCommunity: () => void;
  @BuilderParam onLike: () => void;
  @BuilderParam onFavorite: () => void;
  @BuilderParam onSubmitComment: () => void;

  private formatTime(value: string): string { return value.length >= 16 ? value.substring(0, 16).replace('T', ' ') : value; }
  @Builder SettingRow(label: string, value: string) { Row() { Text(label).fontSize(13).fontColor(MUTED); Text(value).fontSize(13).fontColor(INK).layoutWeight(1).textAlign(TextAlign.End) }.padding(14).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8) }
  @Builder PostImage(post: CommunityPost) {
    if (post.imageUrl === '/seed/community_egret' || post.imageUrl.length === 0 && post.type === 'photo') { Image($r('app.media.community_egret')).width('100%').height(340).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6) }
    else if (post.imageUrl === '/seed/community_journal' || post.imageUrl.length === 0) { Image($r('app.media.community_journal')).width('100%').height(340).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6) }
    else { Image(this.mediaUrl).width('100%').height(340).objectFit(ImageFit.Contain).backgroundColor('#EEF1ED').borderRadius(6) }
  }

  build() {
    if (this.post === undefined) {
      Column({ space: 12 }) {
        PageHeaderView({ title: '社区详情', onBack: () => this.onBack() })
        Text('帖子不存在或缓存已失效').fontSize(16).fontColor(MUTED)
        Button('返回社区').onClick(() => this.onReturnCommunity())
      }.width('100%').height('100%').backgroundColor(BG)
    } else {
      Column() {
        PageHeaderView({ title: '观察札记', onBack: () => this.onBack() })
        Scroll() {
          Column({ space: 14 }) {
            Row({ space: 10 }) { Image($r('app.media.community_avatar')).width(42).height(42).objectFit(ImageFit.Cover).borderRadius(21); Column({ space: 2 }) { Text(this.post!.authorName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK); Text(this.formatTime(this.post!.createdAt) + ' · ' + (this.post!.placeName || '未填写地点')).fontSize(11).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(this.post!.type === 'journal' ? '手账作品' : '观察动态').fontSize(11).fontColor(GREEN).padding({ left: 9, right: 9, top: 6, bottom: 6 }).backgroundColor(GREEN_SOFT).borderRadius(14) }
            this.PostImage(this.post!)
            Text(this.post!.title).fontFamily('serif').fontSize(25).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text(this.post!.body).fontFamily('serif').fontSize(15).fontColor(INK).lineHeight(25).width('100%')
            this.SettingRow('物种', this.speciesName + ' · ' + this.scientificName)
            this.SettingRow('行为', this.post!.behavior || '未填写')
            this.SettingRow('地点', this.post!.placeName || '未填写')
            this.SettingRow('时间', this.formatTime(this.post!.createdAt))
            Row() { Text('评论').fontFamily('serif').fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1); Text(this.comments.length.toString() + ' 条').fontSize(13).fontColor(GREEN) }.width('100%')
            if (this.comments.length === 0) { Text('还没有评论，来写第一条吧').fontSize(13).fontColor(MUTED).padding({ top: 12, bottom: 12 }) }
            ForEach(this.comments, (item: PostComment) => { Row({ space: 10 }) { Text(item.authorName.substring(0, 1)).fontSize(14).fontColor(WHITE).width(34).height(34).textAlign(TextAlign.Center).backgroundColor(GREEN).borderRadius(17); Column({ space: 3 }) { Text(item.authorName).fontSize(13).fontWeight(FontWeight.Medium).fontColor(INK); Text(item.body).fontSize(13).fontColor(MUTED).lineHeight(20); Text(this.formatTime(item.createdAt)).fontSize(10).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1) }.padding(11).backgroundColor(WHITE).borderRadius(8) }, (item: PostComment) => item.id)
          }.padding({ left: 16, right: 16, bottom: 28 })
        }.layoutWeight(1)
        Row({ space: 12 }) { Text(this.post!.liked ? '♥ ' + this.post!.likeCount.toString() : '♡ ' + this.post!.likeCount.toString()).fontColor(this.post!.liked ? RED : MUTED).onClick(() => this.onLike()); Text(this.post!.favorited ? '★' : '☆').fontColor(this.post!.favorited ? AMBER : MUTED).onClick(() => this.onFavorite()); TextInput({ text: this.commentDraft, placeholder: '写评论…' }).fontColor(INK).layoutWeight(1).height(40).backgroundColor(BG).borderRadius(20).onChange((value: string) => this.commentDraft = value); Button('发送').height(40).fontSize(12).backgroundColor(GREEN).borderRadius(20).onClick(() => this.onSubmitComment()) }.padding(10).backgroundColor(WHITE).border({ width: { top: 1 }, color: BORDER })
      }.backgroundColor(BG)
    }
  }
}
