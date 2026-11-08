import { AuthMode } from '../../models/BetaModels';
import { BackendStatus } from '../../models/BirdModels';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';
const RED = '#D7644A';
const SERIF = 'serif';

@Component
export struct SettingsView {
  @Link backendUrl: string;
  @Link authEmail: string;
  @Link authCode: string;
  @Link fuzzy: boolean;
  @Prop backendStatus: BackendStatus;
  @Prop backendStatusLabel: string;
  @Prop backendMessage: string;
  @Prop syncSummary: string;
  @Prop authMode: AuthMode;
  @Prop authLoading: boolean;
  @Prop authMessage: string;
  @Prop aiUploadConsent: boolean;
  @BuilderParam onBack: () => void;
  @BuilderParam onSaveBackend: () => void;
  @BuilderParam onRetrySync: () => void;
  @BuilderParam onRequestCode: () => void;
  @BuilderParam onLogin: () => void;
  @BuilderParam onExportData: () => void;
  @BuilderParam onLogout: () => void;
  @BuilderParam onDeleteAccount: () => void;
  @BuilderParam onAiConsentAction: () => void;
  @BuilderParam onShowStorageInfo: () => void;
  @BuilderParam onShowAbout: () => void;

  @Builder Section(title: string, detail: string) {
    Row() {
      Text(title).fontFamily(SERIF).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
      Text(detail).fontSize(13).fontColor(GREEN)
    }.width('100%')
  }

  @Builder SettingAction(label: string, value: string, action: () => void) {
    Row() {
      Text(label).fontSize(13).fontColor(MUTED)
      Text(value).fontSize(13).fontColor(INK).layoutWeight(1).textAlign(TextAlign.End)
    }
    .height(48)
    .padding({ left: 14, right: 14 })
    .backgroundColor(WHITE)
    .border({ width: 1, color: BORDER })
    .borderRadius(8)
    .onClick(() => action())
  }

  build() {
    Column() {
      PageHeaderView({ title: '设置', onBack: () => this.onBack() })
      Scroll() {
        Column({ space: 12 }) {
          this.Section('后端与同步', this.backendStatusLabel)
          TextInput({ text: this.backendUrl, placeholder: 'http://电脑局域网IP:8787' })
            .height(48)
            .fontSize(13)
            .fontColor(INK)
            .backgroundColor(WHITE)
            .border({ width: 1, color: BORDER })
            .borderRadius(8)
            .onChange((value: string) => this.backendUrl = value)
          Button('保存地址并测试连接').width('100%').height(44).fontColor(WHITE).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onSaveBackend())
          Text(this.backendMessage).fontSize(12).fontColor(this.backendStatus === 'online' ? GREEN : RED).lineHeight(19).width('100%')
          Text(this.syncSummary).fontSize(12).fontColor(MUTED).lineHeight(19).width('100%')
          Button('立即重试同步').width('100%').height(42).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onRetrySync())

          this.Section('账号与云同步', this.authMode === 'authenticated' ? '已登录' : '游客模式')
          if (this.authMode === 'guest') {
            Text('登录后可同步观察记录、发布社区内容并跨设备恢复。未登录也可以完整使用本地记录、地图和手账。').fontSize(12).fontColor(MUTED).lineHeight(19).width('100%')
            TextInput({ text: this.authEmail, placeholder: '邮箱地址' }).height(46).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((value: string) => this.authEmail = value)
            Row({ space: 8 }) {
              TextInput({ text: this.authCode, placeholder: '6 位验证码' }).layoutWeight(1).height(46).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((value: string) => this.authCode = value)
              Button('获取验证码').enabled(!this.authLoading).height(46).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onRequestCode())
            }.width('100%')
            Button(this.authLoading ? '正在登录…' : '邮箱验证码登录').enabled(!this.authLoading).width('100%').height(46).fontColor(WHITE).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onLogin())
          } else {
            Text('当前账号：' + this.authEmail).fontSize(13).fontColor(INK).width('100%')
            Button('导出云端个人数据').enabled(!this.authLoading).width('100%').height(44).fontColor(GREEN).backgroundColor(GREEN_SOFT).borderRadius(8).onClick(() => this.onExportData())
            Button('退出登录').enabled(!this.authLoading).width('100%').height(44).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onLogout())
            Button('删除云端账号').enabled(!this.authLoading).width('100%').height(44).fontColor(RED).backgroundColor(WHITE).border({ width: 1, color: RED }).borderRadius(8).onClick(() => this.onDeleteAccount())
          }
          if (this.authMessage.length > 0) {
            Text(this.authMessage).fontSize(12).fontColor(this.authMessage.indexOf('失败') >= 0 ? RED : MUTED).lineHeight(19).width('100%')
          }

          this.Section('隐私', '')
          this.SettingAction('AI 图片识别', this.aiUploadConsent ? '已授权，点此撤销  ›' : '未授权，点此设置  ›', () => this.onAiConsentAction())
          this.SettingAction('默认位置精度', this.fuzzy ? '模糊位置  ›' : '精确位置  ›', () => this.fuzzy = !this.fuzzy)
          this.Section('数据与服务', '')
          this.SettingAction('存储空间', '本地缓存  ›', () => this.onShowStorageInfo())
          this.SettingAction('导出观察数据', this.authMode === 'authenticated' ? '导出云端数据  ›' : '登录后可用', () => this.onExportData())
          this.SettingAction('关于 Birdfolio', 'Beta 0.2 · 本地优先', () => this.onShowAbout())
        }.padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
