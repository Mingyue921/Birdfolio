import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';

@Component
export struct ProfileEditView {
  @Link displayName: string;
  @Link bio: string;
  @Link avatarUri: string;
  @Prop profileSaving: boolean;
  @BuilderParam onBack: () => void;
  @BuilderParam onPickAvatar: () => void;
  @BuilderParam onSave: () => void;

  @Builder Label(text: string) {
    Text(text).fontSize(13).fontWeight(FontWeight.Medium).fontColor(MUTED).width('100%')
  }

  build() {
    Column() {
      PageHeaderView({ title: '编辑资料', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 14 }) {
          Image(this.avatarUri.length > 0 ? this.avatarUri : $r('app.media.avatar_sparrow'))
            .width(96)
            .height(96)
            .objectFit(ImageFit.Cover)
            .borderRadius(48)
          Text('更换头像').fontSize(13).fontColor(GREEN).onClick(() => this.onPickAvatar())
          this.Label('昵称')
          TextInput({ text: this.displayName })
            .height(48)
            .fontColor('#1C241F')
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
            .onChange((value: string) => this.displayName = value)
          this.Label('个人简介')
          TextArea({ text: this.bio })
            .height(110)
            .fontColor('#1C241F')
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
            .onChange((value: string) => this.bio = value)
          Button(this.profileSaving ? '正在保存…' : '保存资料')
            .enabled(!this.profileSaving)
            .width('100%')
            .height(48)
            .backgroundColor(GREEN)
            .borderRadius(8)
            .onClick(() => this.onSave())
        }
        .padding({ left: 16, right: 16, bottom: 28 })
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
