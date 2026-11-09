import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import picker from '@ohos.file.picker';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { INITIAL_OBSERVATIONS, SPECIES } from '../data/BirdSeedData';
import { catalogSpeciesImage } from '../data/BirdImageMap.generated';
import { BirdSpecies, Observation, ObservationInput, JournalBook, JournalPage, JournalElement, JournalElementStyle, BackendStatus, CommunityPost, PostComment, PostDraft, CreatePostInput, IdentificationCandidate, IdentificationResult, SpeciesCatalogResult, UserProfile, HealthResult } from '../models/BirdModels';
import { AppRoute } from '../models/AppRoute';
import { AuthMode, AuthSession, IdentificationResultV2, IdentificationMetadata, SyncMutation, SyncPushInput, PrivacySettings } from '../models/BetaModels';
import { LegalDocumentContent, LegalDocumentId, legalDocument } from '../data/LegalContent';
import { SyncJob } from '../models/SyncModels';
import { ObservationService } from '../services/ObservationService';
import { ObservationStorage } from '../services/ObservationStorage';
import { MapService } from '../services/MapService';
import { MapPrivacyStorage } from '../services/MapPrivacyStorage';
import { Privacy } from '@tencentmap/map';
import { ObservationEditorView } from '../components/ObservationEditorView';
import { AudioPlanningView } from '../components/pages/AudioPlanningView';
import { MigrationPlanningView } from '../components/pages/MigrationPlanningView';
import { NotificationsPlanningView } from '../components/pages/NotificationsPlanningView';
import { ProductDetailView } from '../components/pages/ProductDetailView';
import { ProfileEditView } from '../components/pages/ProfileEditView';
import { IdentificationResultView } from '../components/pages/IdentificationResultView';
import { SettingsView } from '../components/pages/SettingsView';
import { HomeView } from '../components/pages/HomeView';
import { CommunityView } from '../components/pages/CommunityView';
import { JournalBooksView } from '../components/pages/JournalBooksView';
import { GuideView } from '../components/pages/GuideView';
import { ProfileView } from '../components/pages/ProfileView';
import { BirdDetailView } from '../components/pages/BirdDetailView';
import { MapView } from '../components/pages/MapView';
import { ObservationsView } from '../components/pages/ObservationsView';
import { PostDetailView } from '../components/pages/PostDetailView';
import { PublishView } from '../components/pages/PublishView';
import { StatsView } from '../components/pages/StatsView';
import { JournalEditorWebView, JournalWebBridge } from '../components/pages/JournalEditorWebView';
import { ObservationDetailPage } from '../components/pages/ObservationDetailPage';
import { SpeciesPickerView } from '../components/pages/SpeciesPickerView';
import { LegalDocumentView } from '../components/pages/LegalDocumentView';
import { LocationService } from '../services/LocationService';
import { JournalService } from '../services/JournalService';
import { JournalStorage } from '../services/JournalStorage';
import { ApiService, ApiServiceError } from '../services/ApiService';
import { BackendConfigStorage } from '../services/BackendConfigStorage';
import { CommunityStorage } from '../services/CommunityStorage';
import { SyncQueueService } from '../services/SyncQueueService';
import { SyncQueueStorage } from '../services/SyncQueueStorage';
import { SyncCursorStorage } from '../services/SyncCursorStorage';
import { SpeciesStorage } from '../services/SpeciesStorage';
import { PrivacyStorage } from '../services/PrivacyStorage';
import { ProfileStorage } from '../services/ProfileStorage';
import { AuthStorage } from '../services/AuthStorage';
import { AuthController } from '../services/AuthController';
import { LocalDataCleanupService } from '../services/LocalDataCleanupService';
import { SafeLogger } from '../services/SafeLogger';

const BG = '#F9FAF7';
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

interface JournalObservationText {
  id: string;
  text: string;
}

interface JournalEditorPayload {
  book: JournalBook;
  observations: JournalObservationText[];
  pageIndex: number;
}

interface JournalPickedImage {
  uri: string;
  dataUrl: string;
  error?: string;
}

interface ProfilePhotoItem {
  id: string;
  observationId: string;
  uri: string;
}

@Entry
@Component
struct Index {
  private get context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }
  @State tab: string = 'home';
  @State page: AppRoute = AppRoute.home();
  @State keyword: string = '';
  @State speciesId: string = 'egret';
  @State countText: string = '1';
  @State place: string = '奥森南园湿地';
  @State note: string = '它停在水边的枝头，安静地观察水面。';
  @State fuzzy: boolean = true;
  @State photos: string[] = [];
  @State records: Observation[] = INITIAL_OBSERVATIONS;
  @State liked: boolean = false;
  @State toast: string = '';
  @State communityMode: string = '发现';
  @State guideMode: string = '附近常见';
  @State profileMode: string = '作品';
  @State shopMode: string = '数字素材';
  @State shopCategory: string = '精选';
  @State publishMode: string = '照片动态';
  @State detailMode: string = '辨识';
  @State behavior: string = '觅食';
  @State audioRecording: boolean = false;
  @State publishVisibility: string = '所有人';
  @State displayName: string = '林中客';
  @State bio: string = '在城市里寻找有翅膀的邻居';
  @State avatarUri: string = '';
  @State observationFilter: string = '全部';
  @State editingRecordId: string = '';
  @State confirmDelete: boolean = false;
  @State selectedYear: number = new Date().getFullYear();
  @State mapPrivacyLoaded: boolean = false;
  @State mapPrivacyAgreed: boolean = false;
  @State selectedPlaceFilter: string = '';
  @State locationStatus: string = '尚未设置坐标';
  @State recordLatitude: number = 0;
  @State recordLongitude: number = 0;
  @State journalBooks: JournalBook[] = [];
  @State selectedJournalPage: number = 0;
  @State selectedJournalElementId: string = '';
  @State journalTitle: string = '自然观察手账';
  @State journalTool: string = '选择';
  @State journalTemplate: string = 'wetland';
  @State journalSaveStatus: string = '自动保存';
  @State journalBrushColor: string = '#2F6B4F';
  @State journalBrushWidth: number = 4;
  @State journalConfirmDelete: boolean = false;
  @State drawingStartX: number = 0;
  @State drawingStartY: number = 0;
  @State journalActivePath: string = '';
  @State journalTextDraft: string = '';
  @State backendUrl: string = 'http://127.0.0.1:8787';
  @State backendStatus: BackendStatus = 'offline';
  @State backendMessage: string = '仅保存在本机';
  @State syncJobs: SyncJob[] = [];
  @State communityPosts: CommunityPost[] = [];
  @State communityDrafts: PostDraft[] = [];
  @State communityLoading: boolean = false;
  @State postComments: PostComment[] = [];
  @State publishTitle: string = '';
  @State publishBody: string = '';
  @State publishPhotoUri: string = '';
  @State activePostDraftId: string = '';
  @State publishing: boolean = false;
  @State commentDraft: string = '';
  @State identificationCandidates: IdentificationCandidate[] = [];
  @State identificationMode: string = 'unavailable';
  @State identificationWarning: string = '';
  @State identificationLoading: boolean = false;
  @State guideSpecies: BirdSpecies[] = SPECIES;
  @State customSpecies: BirdSpecies[] = [];
  @State guideLoading: boolean = false;
  @State guideMessage: string = '离线中文图鉴 · 50 种';
  @State aiUploadConsent: boolean = false;
  @State cutoutUploadConsent: boolean = false;
  @State profileSaving: boolean = false;
  @State authMode: AuthMode = 'guest';
  @State authEmail: string = '';
  @State authCode: string = '';
  @State authMessage: string = '';
  @State authLoading: boolean = false;
  @State aiProviderStatus: string = 'unavailable';
  @State aiRequestStatus: string = '';
  @State syncConflictCount: number = 0;
  private authSession: AuthSession | null = null;
  private authCodeRequestedAt: number = 0;
  private authCursor: string = '';
  private aiRequestId: string = '';
  private journalDragLastX: number = 0;
  private journalDragLastY: number = 0;
  private journalWebController: webview.WebviewController = new webview.WebviewController();
  private journalImageCache: Map<string, string> = new Map<string, string>();
  @State journalWebNeedsProxyReload: boolean = false;
  private journalSavedRevisions: Map<string, number> = new Map<string, number>();
  private journalExportChunks: Map<string, string[]> = new Map<string, string[]>();
  private journalExportSizes: Map<string, number> = new Map<string, number>();
  private journalWebBridge: JournalWebBridge = new JournalWebBridge(
    (payload: string, pageIndex: number, revision: number, requestId: string) => this.requestJournalWebSave(payload, pageIndex, revision, requestId),
    (requestId: string) => this.requestCloseJournalWebEditor(requestId),
    (id: string) => this.deleteJournalFromWeb(id),
    () => this.pickJournalWebImage(),
    (uri: string) => this.readJournalImage(uri),
    (exportId: string, chunk: string, reset: boolean) => this.receiveJournalWebExportChunk(exportId, chunk, reset),
    (exportId: string, title: string, page: number, requestId: string) => this.finishJournalWebExport(exportId, title, page, requestId),
    (_message: string) => SafeLogger.info('BirdfolioJournal', 'editor_event')
  );

  aboutToAppear(): void {
    webview.WebviewController.initializeWebEngine();
    const initialized = MapService.init();
    SafeLogger.info('BirdfolioMap', initialized ? 'page_ready_map_configured' : 'page_ready_map_unconfigured');
    this.load();
    this.loadMapPrivacy();
  }

  private async loadMapPrivacy(): Promise<void> {
    const agreed = await MapPrivacyStorage.load(this.context);
    Privacy.setUserAgreePrivacy(agreed);
    this.mapPrivacyAgreed = agreed;
    this.mapPrivacyLoaded = true;
    SafeLogger.info('BirdfolioMap', agreed ? 'privacy_loaded_agreed' : 'privacy_loaded_declined');
  }

  private showConfirmDialog(
    title: string,
    message: string,
    cancelText: string,
    confirmText: string,
    confirmColor: string,
    onConfirm: () => void,
    onCancel?: () => void
  ): void {
    this.getUIContext().getPromptAction().showDialog({
      title: title,
      message: message,
      buttons: [
        { text: cancelText, color: MUTED },
        { text: confirmText, color: confirmColor }
      ]
    }).then((result) => {
      if (result.index === 1) onConfirm();
      else if (onCancel !== undefined) onCancel();
    }).catch(() => {
      this.toast = '无法显示确认弹窗，请重试';
    });
  }

  private requestMapPrivacyConsent(): void {
    this.showConfirmDialog(
      '启用腾讯在线地图',
      '在线地图需要连接腾讯位置服务，并由腾讯地图 SDK 处理必要的设备与网络信息。应用只展示已保存的观察坐标，不会自动获取你的当前位置。',
      '暂不启用',
      '同意并启用',
      GREEN,
      async () => {
        Privacy.setUserAgreePrivacy(true);
        this.mapPrivacyAgreed = true;
        const saved = await MapPrivacyStorage.save(this.context, true);
        if (!saved) this.toast = '授权状态保存失败，下次需要重新确认';
        SafeLogger.info('BirdfolioMap', 'privacy_agreed');
      },
      () => { Privacy.setUserAgreePrivacy(false); }
    );
  }
  private async load(): Promise<void> {
    this.records = await ObservationStorage.load(this.context, INITIAL_OBSERVATIONS);
    const profile: UserProfile = await ProfileStorage.load(this.context);
    this.displayName = profile.displayName;
    this.bio = profile.bio;
    this.avatarUri = profile.avatarUri;
    const privacySettings: PrivacySettings = await PrivacyStorage.load(this.context);
    this.aiUploadConsent = PrivacyStorage.hasActiveConsent(privacySettings, 'identification');
    this.cutoutUploadConsent = PrivacyStorage.hasActiveConsent(privacySettings, 'cutout');
    this.customSpecies = await SpeciesStorage.load(this.context);
    this.guideSpecies = SPECIES.concat(this.customSpecies);
    this.journalBooks = await JournalStorage.load(this.context);
    this.backendUrl = await BackendConfigStorage.load(this.context);
    await this.loadAuthSession();
    this.communityPosts = await CommunityStorage.loadPosts(this.context);
    this.communityDrafts = await CommunityStorage.loadDrafts(this.context);
    this.syncJobs = await SyncQueueStorage.load(this.context);
    this.authCursor = await SyncCursorStorage.load(this.context);
    this.selectedYear = ObservationService.years(this.records)[0];
    await this.checkBackend();
    await this.processSyncQueue();
  }

  private async loadAuthSession(): Promise<void> {
    const restored = await new AuthController(this.context, this.backendUrl).restore();
    const saved = restored.session;
    if (saved === null) {
      this.authSession = null;
      this.authMode = 'guest';
      if (restored.expired) this.authMessage = '登录已过期，仍可继续使用本地功能';
      return;
    }
    this.authSession = saved;
    this.authMode = 'authenticated';
    this.authEmail = saved.email;
    this.displayName = saved.displayName && saved.displayName.length > 0 ? saved.displayName : this.displayName;
  }

  private api(): ApiService { return new ApiService(this.backendUrl, AuthStorage.accessToken(this.authSession)); }

  private async healthAt(url: string): Promise<HealthResult> {
    const health = await new ApiService(url).health();
    if (!health.ok || health.service !== 'birdfolio') throw new Error('不是 Birdfolio 后端');
    return health;
  }

  private async requestLoginCode(): Promise<void> {
    const email = this.authEmail.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      this.authMessage = '请输入有效邮箱地址';
      return;
    }
    this.authLoading = true;
    try {
      const result = await new AuthController(this.context, this.backendUrl).requestCode(email);
      this.authEmail = email;
      this.authCodeRequestedAt = new Date().getTime();
      this.authMessage = result.debugCode !== undefined && result.debugCode.length > 0
        ? '开发模式验证码（仅本机）：' + result.debugCode
        : (result.message || ('验证码已发送，' + result.expiresInSeconds.toString() + ' 秒内有效'));
    } catch (error) {
      this.authMessage = '验证码发送失败：' + this.networkError(error);
    }
    this.authLoading = false;
  }

  private async verifyLoginCode(): Promise<void> {
    const email = this.authEmail.trim().toLowerCase();
    const code = this.authCode.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !/^\d{6}$/.test(code)) {
      this.authMessage = '请输入邮箱和 6 位验证码';
      return;
    }
    this.authLoading = true;
    try {
      const session = await new AuthController(this.context, this.backendUrl).verify({ email: email, code: code });
      this.authSession = session;
      this.authMode = 'authenticated';
      this.authEmail = session.email;
      this.authCode = '';
      this.authMessage = '已登录，可开启云同步';
      this.toast = '登录成功';
      await this.checkBackend();
      await this.processSyncQueue();
    } catch (error) {
      this.authMessage = '登录失败：' + this.networkError(error);
    }
    this.authLoading = false;
  }

  private async logoutAccount(): Promise<void> {
    const current = this.authSession;
    try {
      await new AuthController(this.context, this.backendUrl, current).logout();
    } catch (_error) {
      // A network failure must not trap the user in a local session.
    }
    this.authSession = null;
    this.authMode = 'guest';
    this.authMessage = '已退出登录，本地观察仍保留';
    this.toast = '已退出登录';
  }

  private async exportAccountData(): Promise<void> {
    if (this.authMode !== 'authenticated') { this.toast = '登录后才能导出云端数据'; return; }
    this.authLoading = true;
    try {
      const result = await new AuthController(this.context, this.backendUrl, this.authSession).exportAccount();
      this.toast = result.format ? '数据导出已生成' : '数据导出成功';
    } catch (error) {
      this.toast = '数据导出失败：' + this.networkError(error);
    }
    this.authLoading = false;
  }

  private deleteAccount(): void {
    if (this.authMode !== 'authenticated') { this.toast = '当前为游客模式'; return; }
    this.showConfirmDialog(
      '删除云端账号？',
      '此操作会删除云端观察、社区内容和会话，已经保存在本机的观察不会被删除。',
      '取消',
      '确认删除',
      RED,
      async () => {
        this.authLoading = true;
        try {
          await new AuthController(this.context, this.backendUrl, this.authSession).deleteAccount();
          this.authSession = null;
          this.authMode = 'guest';
          this.authMessage = '云端账号已删除，本地数据仍保留';
          this.toast = '云端账号已删除';
        } catch (error) {
          this.toast = '删除账号失败：' + this.networkError(error);
        }
        this.authLoading = false;
      }
    );
  }

  private async acceptBackend(health: HealthResult, notice: string = ''): Promise<boolean> {
    this.aiProviderStatus = health.aiMode === 'provider' ? 'provider' : 'unavailable';
    this.backendStatus = SyncQueueService.pendingCount(this.syncJobs) > 0 ? 'pending' : 'online';
    this.backendMessage = notice + '后端已连接 · ' + (health.aiMode === 'provider' ? '视觉模型已配置' : '识鸟服务暂不可用');
    await this.refreshCommunity();
    this.backendStatus = SyncQueueService.pendingCount(this.syncJobs) > 0 ? 'pending' : 'online';
    this.backendMessage = notice + '后端已连接 · ' + (health.aiMode === 'provider' ? '视觉模型已配置' : '识鸟服务暂不可用');
    return true;
  }

  private mergeGuideSpecies(remote: BirdSpecies[]): BirdSpecies[] {
    const merged: BirdSpecies[] = SPECIES.concat(this.customSpecies);
    remote.forEach((item: BirdSpecies) => {
      const scientificName = item.scientificName.toLowerCase();
      const index = merged.findIndex((existing: BirdSpecies) => existing.id === item.id || existing.scientificName.toLowerCase() === scientificName);
      if (index >= 0) {
        const local = merged[index];
        merged[index] = {
          id: local.id, name: local.name, scientificName: local.scientificName, aliases: local.aliases,
          category: local.category, description: local.description, regions: local.regions, imageHint: local.imageHint,
          gbifKey: item.gbifKey, imageUrl: item.imageUrl, imageCreator: item.imageCreator,
          imageLicense: item.imageLicense, imageSourceUrl: item.imageSourceUrl,
          sourceUrl: item.sourceUrl, dataSource: item.dataSource
        };
      } else {
        if (item.name.length === 0 || item.name.toLowerCase() === scientificName) item.name = '中文名待核对';
        merged.push(item);
      }
    });
    return merged;
  }

  private async loadGuideSpecies(query: string): Promise<void> {
    this.guideLoading = true;
    try {
      const result: SpeciesCatalogResult = await this.api().species(query, 24);
      this.guideSpecies = this.mergeGuideSpecies(result.items);
      if (result.source === 'GBIF') this.guideMessage = 'GBIF 在线图鉴 · ' + result.items.length.toString() + ' 条结果';
      else if (result.source === 'GBIF_CACHE') this.guideMessage = 'GBIF 缓存图鉴 · ' + result.items.length.toString() + ' 条结果';
      else this.guideMessage = 'GBIF 当前连接失败，已使用离线图鉴';
    } catch (_error) {
      this.guideSpecies = SPECIES.concat(this.customSpecies);
      this.guideMessage = 'GBIF 暂不可用，已使用离线图鉴';
    }
    this.guideLoading = false;
  }

  private backendStatusText(): string {
    if (this.backendStatus === 'syncing') return '正在同步';
    if (this.backendStatus === 'pending') return '等待同步 · ' + SyncQueueService.pendingCount(this.syncJobs).toString();
    if (this.backendStatus === 'online') return '已同步';
    if (this.backendStatus === 'error') return '同步出错';
    return '仅保存在本机';
  }

  private fallbackPosts(): CommunityPost[] {
    // Seed content is server-side demo data only. Never present it as a local
    // user's real community content when the network is unavailable.
    return [];
  }

  private visibleCommunityPosts(): CommunityPost[] {
    let posts = this.communityPosts.length > 0 ? this.communityPosts : this.fallbackPosts();
    if (this.communityMode === '关注') posts = posts.filter((item: CommunityPost) => item.userId === 'demo-user' || item.userId === 'forest-letter');
    if (this.communityMode === '附近') posts = posts.filter((item: CommunityPost) => item.placeName.length > 0);
    return posts;
  }

  private selectedPost(): CommunityPost | undefined { return this.communityPosts.concat(this.fallbackPosts()).find((item: CommunityPost) => item.id === this.page.postId); }

  private async refreshCommunity(): Promise<boolean> {
    this.communityLoading = true;
    let connected = true;
    try {
      const posts = await this.api().posts(this.communityMode);
      this.communityPosts = posts;
      await CommunityStorage.savePosts(this.context, posts);
      this.backendStatus = SyncQueueService.pendingCount(this.syncJobs) > 0 ? 'pending' : 'online';
      this.backendMessage = '后端连接正常';
    } catch (error) {
      connected = false;
      const failure = error as ApiServiceError;
      if (failure.statusCode === 401 && this.authMode === 'guest') {
        this.communityPosts = [];
        this.backendMessage = '后端已连接 · 登录后查看社区';
        this.communityLoading = false;
        return true;
      }
      this.backendStatus = SyncQueueService.pendingCount(this.syncJobs) > 0 ? 'pending' : 'offline';
      this.backendMessage = '社区离线：' + this.networkError(error);
      if (this.communityPosts.length === 0) this.communityPosts = this.fallbackPosts();
    }
    this.communityLoading = false;
    return connected;
  }

  private networkError(error: Object): string {
    const failure = error as BusinessError;
    if (failure.message) return failure.message.substring(0, 100);
    if (failure.code !== undefined) return '错误码 ' + failure.code.toString();
    return '连接失败';
  }

  private async checkBackend(): Promise<boolean> {
    this.backendStatus = 'syncing';
    this.backendMessage = '正在检查 ' + this.backendUrl;
    try {
      return await this.acceptBackend(await this.healthAt(this.backendUrl));
    } catch (error) {
      const savedUrl = BackendConfigStorage.normalize(this.backendUrl);
      const localUrl = BackendConfigStorage.localUrl();
      if (savedUrl.length > 0 && savedUrl !== localUrl) {
        try {
          const localHealth = await this.healthAt(localUrl);
          const saved = await BackendConfigStorage.save(this.context, localUrl);
          if (!saved) throw new Error('本机通道地址保存失败');
          this.backendUrl = localUrl;
          return await this.acceptBackend(localHealth, '已自动切换 USB 本机通道 · ');
        } catch (_fallbackError) {
          // Keep the original error below so a stale LAN address remains diagnosable.
        }
      }
      this.backendStatus = SyncQueueService.pendingCount(this.syncJobs) > 0 ? 'pending' : 'offline';
      this.backendMessage = '连接失败：' + this.networkError(error) + '。可尝试 127.0.0.1（USB/HDC）或电脑局域网IP';
      return false;
    }
  }

  private async saveBackendUrl(): Promise<void> {
    const ok = await BackendConfigStorage.save(this.context, this.backendUrl);
    if (!ok) { this.toast = '地址格式错误，请以 http:// 或 https:// 开头'; return; }
    this.backendUrl = await BackendConfigStorage.load(this.context);
    const connected = await this.checkBackend();
    this.toast = connected ? '后端连接成功' : this.backendMessage;
  }

  private async enqueueObservation(action: string, observation: Observation): Promise<void> {
    const job = SyncQueueService.createJob(action, observation.id, JSON.stringify(observation));
    this.syncJobs = this.syncJobs.filter((item: SyncJob) => item.entityId !== observation.id).concat([job]);
    await SyncQueueStorage.save(this.context, this.syncJobs);
    this.backendStatus = 'pending';
    await this.processSyncQueue();
  }

  private async enqueueDeletedObservation(id: string): Promise<void> {
    const now = new Date().toISOString();
    const job = SyncQueueService.createJob('delete', id, now);
    this.syncJobs = this.syncJobs.filter((item: SyncJob) => item.entityId !== id).concat([job]);
    await SyncQueueStorage.save(this.context, this.syncJobs);
    this.backendStatus = 'pending';
    await this.processSyncQueue();
  }

  private async processSyncQueue(): Promise<void> {
    const pending = this.syncJobs.filter((item: SyncJob) => item.status === 'pending' || item.status === 'failed');
    if (pending.length === 0) {
      await this.pullRemoteObservations();
      return;
    }
    this.backendStatus = 'syncing';
    const completed: string[] = [];
    try {
      if (this.authMode === 'authenticated') {
        const mutations: SyncMutation[] = pending.map((job: SyncJob): SyncMutation => ({
          mutationId: job.id,
          entity: 'observation',
          entityId: job.entityId,
          operation: job.action === 'delete' ? 'delete' : 'upsert',
          updatedAt: job.updatedAt,
          payload: job.action === 'delete' ? '' : job.payload
        }));
        const input: SyncPushInput = { mutations: mutations, idempotencyKey: 'batch-' + pending[0].id };
        const pushed = await this.api().pushSync(input);
        const conflicts: string[] = [];
        pushed.results.forEach((item) => {
          if (item.result === 'applied' || item.result === 'unchanged') completed.push(item.mutationId);
          if (item.result === 'conflict') conflicts.push(item.mutationId);
        });
        this.syncConflictCount = conflicts.length;
        this.syncJobs = this.syncJobs.map((job: SyncJob): SyncJob => {
          if (completed.indexOf(job.id) >= 0) return { id: job.id, action: job.action, entityId: job.entityId, payload: job.payload, status: 'synced', retryCount: job.retryCount, createdAt: job.createdAt, updatedAt: new Date().getTime().toString(), lastError: job.lastError };
          if (conflicts.indexOf(job.id) >= 0) return { id: job.id, action: job.action, entityId: job.entityId, payload: job.payload, status: 'conflict', retryCount: job.retryCount, createdAt: job.createdAt, updatedAt: new Date().getTime().toString(), lastError: '云端存在更新版本' };
          return job;
        });
      } else {
        for (let index = 0; index < pending.length; index++) {
          const job = pending[index];
          if (job.action === 'delete') await this.api().deleteObservation(job.entityId, job.payload);
          else await this.api().syncObservation(JSON.parse(job.payload) as Observation);
          completed.push(job.id);
        }
      }
      const remaining = this.syncJobs.filter((item: SyncJob) => item.status !== 'synced' && completed.indexOf(item.id) < 0);
      if (await SyncQueueStorage.save(this.context, remaining)) this.syncJobs = remaining;
      else { this.backendStatus = 'error'; this.backendMessage = '同步队列保存失败，请重试'; return; }
      this.backendStatus = this.syncConflictCount > 0 ? 'error' : (this.syncJobs.length === 0 ? 'online' : 'pending');
      this.backendMessage = this.syncConflictCount > 0 ? '存在同步冲突，请在本机保留或重新编辑后重试' : '同步完成';
      if (this.syncConflictCount === 0) await this.pullRemoteObservations();
    } catch (error) {
      this.backendStatus = 'pending';
      this.backendMessage = '同步失败：' + this.networkError(error);
      this.syncJobs = this.syncJobs.filter((item: SyncJob) => completed.indexOf(item.id) < 0).map((item: SyncJob): SyncJob => ({ id: item.id, action: item.action, entityId: item.entityId, payload: item.payload, status: 'pending', retryCount: item.retryCount + 1, createdAt: item.createdAt, updatedAt: new Date().toISOString() }));
      await SyncQueueStorage.save(this.context, this.syncJobs);
    }
  }

  private observationTimestamp(value: string | undefined): number {
    const text = String(value || '').trim();
    if (text.length === 0) return NaN;
    if (/^\d+$/.test(text)) {
      const numeric = Number(text);
      return numeric < 100000000000 ? numeric * 1000 : numeric;
    }
    return Date.parse(text);
  }

  private async pullRemoteObservations(): Promise<void> {
    if (this.authMode !== 'authenticated') return;
    try {
      const pulled = await this.api().pullSync(this.authCursor);
      let nextRecords: Observation[] = this.records.slice();
      let changed = false;
      pulled.mutations.forEach((mutation: SyncMutation) => {
        if (mutation.entity !== 'observation') return;
        let remote: Observation;
        try { remote = JSON.parse(mutation.payload) as Observation; } catch (_error) { return; }
        const remoteTime = this.observationTimestamp(mutation.updatedAt || remote.updatedAt || remote.createdAt);
        const index = nextRecords.findIndex((item: Observation) => item.id === mutation.entityId);
        const localTime = index >= 0 ? this.observationTimestamp(nextRecords[index].updatedAt || nextRecords[index].createdAt) : NaN;
        if (!Number.isFinite(remoteTime) || (index >= 0 && Number.isFinite(localTime) && remoteTime <= localTime)) return;
        if (mutation.operation === 'delete') nextRecords = nextRecords.filter((item: Observation) => item.id !== mutation.entityId);
        else if (index >= 0) nextRecords[index] = remote;
        else nextRecords = [remote].concat(nextRecords);
        changed = true;
      });
      if (changed) {
        this.records = nextRecords;
        await ObservationStorage.save(this.context, this.records);
        this.selectedYear = ObservationService.years(this.records)[0];
      }
      const nextCursor: string = pulled.nextCursor || pulled.cursor || '';
      if (nextCursor && nextCursor.length > 0) {
        this.authCursor = nextCursor;
        await SyncCursorStorage.save(this.context, nextCursor);
      }
    } catch (error) {
      this.backendMessage = '同步拉取失败：' + this.networkError(error);
    }
  }
  private selectedJournal(): JournalBook | undefined { return this.journalBooks.find((book: JournalBook) => book.id === this.page.bookId); }
  private async saveJournals(books: JournalBook[]): Promise<void> {
    this.journalSaveStatus = '保存中…';
    this.journalBooks = books;
    const ok = await JournalStorage.save(this.context, books);
    this.journalSaveStatus = ok ? '已自动保存' : '保存失败';
    if (!ok) this.toast = '手账保存失败，已保留当前内容';
  }
  private async receiveJournalWebSave(payload: string, pageIndex: number, revision: number): Promise<string> {
    try {
      const parsed = JournalService.normalizeBook(JSON.parse(payload) as JournalBook);
      if (parsed.id !== this.page.bookId) return 'error';
      const savedRevision = this.journalSavedRevisions.get(parsed.id) ?? -1;
      if (revision < savedRevision) {
        SafeLogger.warn('BirdfolioJournal', 'stale_save_ignored');
        return 'stale';
      }
      this.selectedJournalPage = Math.max(0, Math.min(pageIndex, parsed.pages.length - 1));
      this.journalTitle = parsed.title;
      this.journalBooks = this.journalBooks.map((book: JournalBook) => book.id === parsed.id ? parsed : book);
      const ok = await JournalStorage.save(this.context, this.journalBooks);
      if (ok) this.journalSavedRevisions.set(parsed.id, revision);
      this.journalSaveStatus = ok ? '已自动保存' : '保存失败'; if (!ok) this.toast = '手账保存失败，请重试'; return ok ? 'ok' : 'error';
    } catch (_error) { this.journalSaveStatus = '保存失败'; this.toast = '手账数据格式异常'; return 'error'; }
  }
  private finishJournalWebRequest(requestId: string, result: string): void {
    const script = 'window.BirdfolioEditor.resolveNativeRequest(' + JSON.stringify(requestId) + ',' + JSON.stringify(result) + ')';
    this.journalWebController.runJavaScript(script).catch((_error: BusinessError) => {});
  }
  private requestJournalWebSave(payload: string, pageIndex: number, revision: number, requestId: string): void {
    this.receiveJournalWebSave(payload, pageIndex, revision)
      .then((result: string) => this.finishJournalWebRequest(requestId, result))
      .catch((_error: BusinessError) => this.finishJournalWebRequest(requestId, 'error'));
  }
  private closeJournalWebEditor(): void { this.page = AppRoute.home(); this.selectedJournalElementId = ''; }
  private requestCloseJournalWebEditor(requestId: string): void {
    SafeLogger.info('BirdfolioJournal', 'editor_close_requested');
    this.closeJournalWebEditor();
  }
  private deleteJournalFromWeb(id: string): void {
    if (id !== this.page.bookId) return;
    const books = this.journalBooks.filter((book: JournalBook) => book.id !== id);
    this.journalBooks = books;
    JournalStorage.save(this.context, books).then((ok: boolean) => { if (!ok) this.toast = '手账删除保存失败'; });
    this.selectedJournalPage = 0; this.page = AppRoute.home(); this.toast = '手账已删除';
  }
  private async pickJournalWebImage(): Promise<string> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions(); options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length === 0) return '';
      const uri = result.photoUris[0]; const dataUrl = await this.readJournalImage(uri);
      const picked: JournalPickedImage = { uri: uri, dataUrl: dataUrl, error: dataUrl.length > 0 ? '' : '照片读取失败，请确认照片仍在本机并重试' };
      return JSON.stringify(picked);
    } catch (_error) { const failed: JournalPickedImage = { uri: '', dataUrl: '', error: '无法打开系统相册或读取所选照片' }; return JSON.stringify(failed); }
  }
  private selectJournalWebFile(result: FileSelectorResult): void {
    const options = new photoAccessHelper.PhotoSelectOptions(); options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
    new photoAccessHelper.PhotoViewPicker().select(options).then((selection: photoAccessHelper.PhotoSelectResult) => {
      result.handleFileList(selection.photoUris);
    }).catch((_error: BusinessError) => { result.handleFileList([]); });
  }
  private async readJournalImage(uri: string): Promise<string> {
    if (!uri || uri === 'placeholder') return '';
    const cached = this.journalImageCache.get(uri); if (cached) return cached;
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY); const source = image.createImageSource(file.fd); const info = await source.getImageInfo();
      const longest = Math.max(info.size.width, info.size.height); const ratio = longest > 960 ? 960 / longest : 1;
      const previewSize: image.Size = { width: Math.max(1, Math.round(info.size.width * ratio)), height: Math.max(1, Math.round(info.size.height * ratio)) };
      const decoding: image.DecodingOptions = { desiredSize: previewSize };
      const pixelMap = await source.createPixelMap(decoding); const packer = image.createImagePacker();
      const packing: image.PackingOption = { format: 'image/jpeg', quality: 72 };
      const preview = await packer.packToData(pixelMap, packing); pixelMap.release(); source.release(); packer.release(); fs.closeSync(file);
      const dataUrl = 'data:image/jpeg;base64,' + new util.Base64Helper().encodeToStringSync(new Uint8Array(preview));
      this.journalImageCache.set(uri, dataUrl); return dataUrl;
    } catch (_error) { return ''; }
  }
  private async exportJournalWebImage(dataUrl: string, title: string, page: number): Promise<string> {
    try {
      const comma = dataUrl.indexOf(','); if (comma < 0) return 'error';
      const bytes = new util.Base64Helper().decodeSync(dataUrl.substring(comma + 1));
      const name = 'journal_export_' + Date.now().toString() + '_' + page.toString() + '.png';
      const path = this.context.cacheDir + '/' + name;
      SafeLogger.info('BirdfolioJournal', 'export_cache_creating');
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, bytes);
      fs.closeSync(file);
      SafeLogger.info('BirdfolioJournal', 'export_cache_ready');
      try {
        const sourceUri = fileUri.getUriFromPath(path);
        const config: photoAccessHelper.PhotoCreationConfig = { title: title + '_第' + page.toString() + '页', fileNameExtension: 'png', photoType: photoAccessHelper.PhotoType.IMAGE };
        SafeLogger.info('BirdfolioJournal', 'album_dialog_opening');
        const savedUris = await photoAccessHelper.getPhotoAccessHelper(this.context).showAssetsCreationDialog([sourceUri], [config]);
        SafeLogger.info('BirdfolioJournal', savedUris.length > 0 ? 'album_dialog_saved' : 'album_dialog_cancelled');
        return savedUris.length > 0 ? 'ok' : 'cancelled';
      } catch (_albumError) {
        SafeLogger.warn('BirdfolioJournal', 'album_dialog_failed_using_picker');
        return await this.exportJournalWebImageToFile(bytes, title, page);
      }
    } catch (_error) {
      SafeLogger.error('BirdfolioJournal', 'journal_export_failed');
      return 'error';
    }
  }
  private async exportJournalWebImageToFile(bytes: Uint8Array, title: string, page: number): Promise<string> {
    try {
      const safeTitle = title.replace(/[\\/:*?"<>|]/g, '_').substring(0, 48) || '自然观察手账';
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = ['观鸟手账_' + safeTitle + '_第' + page.toString() + '页_' + Date.now().toString() + '.png'];
      options.fileSuffixChoices = ['PNG 图片|.png'];
      const destinations = await new picker.DocumentViewPicker(this.context).save(options);
      if (destinations.length === 0) return 'cancelled';
      const output = fs.openSync(destinations[0], fs.OpenMode.READ_WRITE);
      fs.writeSync(output.fd, bytes);
      fs.closeSync(output);
      SafeLogger.info('BirdfolioJournal', 'file_picker_export_finished');
      return 'ok';
    } catch (error) {
      const businessError = error as BusinessError;
      SafeLogger.error('BirdfolioJournal', businessError.code === 13900020 ? 'file_picker_export_cancelled' : 'file_picker_export_failed');
      return businessError.code === 13900020 ? 'cancelled' : 'error';
    }
  }
  private requestJournalWebExport(dataUrl: string, title: string, page: number, requestId: string): void {
    this.exportJournalWebImage(dataUrl, title, page)
      .then((result: string) => this.finishJournalWebRequest(requestId, result))
      .catch((_error: BusinessError) => this.finishJournalWebRequest(requestId, 'error'));
  }
  private receiveJournalWebExportChunk(exportId: string, chunk: string, reset: boolean): void {
    if (!exportId || !chunk) return;
    if (reset) {
      this.journalExportChunks.set(exportId, []);
      this.journalExportSizes.set(exportId, 0);
      SafeLogger.info('BirdfolioJournal', 'export_chunks_started');
    }
    const chunks = this.journalExportChunks.get(exportId);
    const currentSize = this.journalExportSizes.get(exportId) ?? 0;
    if (!chunks || chunks.length >= 400 || currentSize + chunk.length > 50 * 1024 * 1024) {
      this.journalExportChunks.delete(exportId);
      this.journalExportSizes.delete(exportId);
      return;
    }
    chunks.push(chunk);
    this.journalExportSizes.set(exportId, currentSize + chunk.length);
  }
  private finishJournalWebExport(exportId: string, title: string, page: number, requestId: string): void {
    const chunks = this.journalExportChunks.get(exportId);
    this.journalExportChunks.delete(exportId);
    this.journalExportSizes.delete(exportId);
    if (!chunks || chunks.length === 0) {
      SafeLogger.error('BirdfolioJournal', 'export_chunks_missing');
      this.finishJournalWebRequest(requestId, 'error');
      return;
    }
    SafeLogger.info('BirdfolioJournal', 'export_chunks_complete');
    const dataUrl = 'data:image/png;base64,' + chunks.join('');
    this.requestJournalWebExport(dataUrl, title, page, requestId);
  }
  private loadJournalIntoWeb(): void {
    const book = this.selectedJournal(); if (!book) return;
    const observations: JournalObservationText[] = [];
    this.records.forEach((item: Observation) => { const textItem: JournalObservationText = { id: item.id, text: this.observationText(item.id) }; observations.push(textItem); });
    const payload: JournalEditorPayload = { book: book, observations: observations, pageIndex: this.selectedJournalPage };
    this.journalWebController.runJavaScript('window.BirdfolioEditor.init(' + JSON.stringify(payload) + ')').catch((_error: BusinessError) => { this.toast = '手账编辑器初始化失败'; });
  }
  private openJournal(id: string): void {
    const book = this.journalBooks.find((item: JournalBook) => item.id === id); if (!book) return;
    this.selectedJournalPage = 0; this.selectedJournalElementId = ''; this.journalTitle = book.title; this.page = AppRoute.journalEditor(id);
  }
  private async createJournal(observationIds: string[] = this.records.slice(0, 3).map((item: Observation) => item.id)): Promise<void> {
    const selected = this.records.filter((item: Observation) => observationIds.indexOf(item.id) >= 0);
    const book = JournalService.createBook(selected, SPECIES);
    await this.saveJournals(this.journalBooks.concat([book])); this.openJournal(book.id);
  }
  private async updateSelectedJournal(update: (book: JournalBook) => JournalBook): Promise<void> {
    const next = this.journalBooks.map((book: JournalBook) => book.id === this.page.bookId ? update(book) : book);
    await this.saveJournals(next);
  }
  private currentJournalPage(): JournalPage | undefined { const book = this.selectedJournal(); return book ? book.pages[this.selectedJournalPage] : undefined; }
  private selectedJournalElement(): JournalElement | undefined { const page = this.currentJournalPage(); return page ? page.elements.find((item: JournalElement) => item.id === this.selectedJournalElementId) : undefined; }
  private selectJournalElement(element: JournalElement): void { this.selectedJournalElementId = element.id; if (element.type === 'text') { this.journalTool = '文字'; this.journalTextDraft = element.content; } else { this.journalTool = '选择'; } }
  private async addJournalText(content: string = '写下这次相遇…'): Promise<void> {
    const style: JournalElementStyle = { fontSize: 18, color: INK };
    const element = JournalService.element('text-' + Date.now().toString(), 'text', 35, 400, 250, 70, content, 20, style);
    await this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element)); this.selectedJournalElementId = element.id;
  }
  private async addJournalSticker(content: string = 'leaf'): Promise<void> {
    const style: JournalElementStyle = { color: GREEN };
    const element = JournalService.element('sticker-' + Date.now().toString(), 'sticker', 220, 350, 72, 72, content, 30, style);
    await this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element)); this.selectedJournalElementId = element.id;
  }
  private async addJournalDrawing(): Promise<void> {
    const style: JournalElementStyle = { strokeColor: this.journalBrushColor, strokeWidth: this.journalBrushWidth };
    const element = JournalService.element('drawing-' + Date.now().toString(), 'drawing', 40, 250, 220, this.journalBrushWidth, 'stroke', 40, style);
    await this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element)); this.selectedJournalElementId = element.id;
  }
  private async transformJournalElement(id: string, dx: number, dy: number, scale: number, angle: number): Promise<void> { await this.updateSelectedJournal((book: JournalBook) => JournalService.transformElement(book, this.selectedJournalPage, id, dx, dy, scale, angle)); }
  private beginJournalDrag(element: JournalElement): void { this.selectJournalElement(element); this.journalDragLastX = 0; this.journalDragLastY = 0; }
  private updateJournalDrag(id: string, offsetX: number, offsetY: number): void {
    const dx = offsetX - this.journalDragLastX; const dy = offsetY - this.journalDragLastY;
    this.journalDragLastX = offsetX; this.journalDragLastY = offsetY;
    this.journalBooks = this.journalBooks.map((book: JournalBook) => book.id === this.page.bookId ? JournalService.transformElement(book, this.selectedJournalPage, id, dx, dy, 1, 0) : book);
  }
  private async finishJournalDrag(): Promise<void> {
    this.journalDragLastX = 0; this.journalDragLastY = 0; this.journalSaveStatus = '保存中…';
    const ok = await JournalStorage.save(this.context, this.journalBooks); this.journalSaveStatus = ok ? '已自动保存' : '保存失败';
    if (!ok) this.toast = '位置保存失败，请重试';
  }
  private async editSelectedJournalText(value: string): Promise<void> { if (this.selectedJournalElementId.length === 0) return; await this.updateSelectedJournal((book: JournalBook) => JournalService.updateElementContent(book, this.selectedJournalPage, this.selectedJournalElementId, value)); }
  private async deleteSelectedJournalElement(): Promise<void> { if (this.selectedJournalElementId.length === 0) return; const id = this.selectedJournalElementId; await this.updateSelectedJournal((book: JournalBook) => JournalService.deleteElement(book, this.selectedJournalPage, id)); this.selectedJournalElementId = ''; this.toast = '元素已删除'; }
  private async deleteCurrentJournalPage(): Promise<void> { const index = this.selectedJournalPage; await this.updateSelectedJournal((book: JournalBook) => JournalService.deletePage(book, index)); const count = this.selectedJournal()?.pages.length || 1; this.selectedJournalPage = Math.min(index, count - 1); this.selectedJournalElementId = ''; this.toast = '页面已删除'; }
  private confirmDeleteJournalBook(): void {
    this.showConfirmDialog('删除这本手账？', '删除后只会移除本地手账草稿，不会删除观察记录和相册原图。', '取消', '确认删除', RED, () => this.deleteSelectedJournal());
  }
  private confirmDeleteJournalBookById(id: string): void { this.showConfirmDialog('删除这本手账？', '删除后只会移除本地手账草稿，不会删除观察记录和相册原图。', '取消', '确认删除', RED, () => this.deleteJournal(id, false)); }
  private confirmDeleteJournalPage(): void { this.showConfirmDialog('删除当前页面？', '页面中的文字、图片、贴纸和笔画都会被移除。', '取消', '确认删除', RED, () => this.deleteCurrentJournalPage()); }
  private async finishJournalStroke(x: number, y: number): Promise<void> {
    const left = Math.min(this.drawingStartX, x); const top = Math.min(this.drawingStartY, y); const width = Math.max(4, Math.abs(x - this.drawingStartX)); const height = Math.max(4, Math.abs(y - this.drawingStartY));
    const style: JournalElementStyle = { strokeColor: this.journalBrushColor, strokeWidth: this.journalBrushWidth };
    const element = JournalService.element('drawing-' + Date.now().toString(), 'drawing', left, top, width, height, 'stroke', 40, style);
    await this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element));
  }
  private stickerSymbol(id: string): string { if (id === 'feather') return '羽'; if (id === 'water') return '水'; if (id === 'sun') return '日'; if (id === 'bird') return '鸟'; if (id === 'date') return '印'; return '叶'; }
  private handleJournalDraw(event: TouchEvent): void {
    if (event.touches.length === 0 && event.changedTouches.length === 0) return;
    const point = event.touches.length > 0 ? event.touches[0] : event.changedTouches[0];
    if (event.type === TouchType.Down) this.journalActivePath = 'M ' + point.x.toString() + ' ' + point.y.toString();
    else if (event.type === TouchType.Move) this.journalActivePath += ' L ' + point.x.toString() + ' ' + point.y.toString();
    else if (event.type === TouchType.Up && this.journalActivePath.length > 0) {
      const style: JournalElementStyle = { strokeColor: this.journalBrushColor, strokeWidth: this.journalBrushWidth };
      const element = JournalService.element('drawing-' + Date.now().toString(), 'drawing', 0, 0, 320, 500, this.journalActivePath, 40, style);
      this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element)); this.journalActivePath = '';
    }
  }
  private observationText(id: string): string {
    const item = this.records.find((record: Observation) => record.id === id);
    return item ? this.birdName(item.speciesId) + ' · ' + item.count.toString() + '只\n' + item.placeName + '\n' + (item.note || '暂无笔记') : '关联观察已删除';
  }
  private async addJournalImage(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions(); options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length > 0) { const element = JournalService.element('image-' + Date.now().toString(), 'image', 25, 120, 270, 170, result.photoUris[0], 10); await this.updateSelectedJournal((book: JournalBook) => JournalService.addElement(book, this.selectedJournalPage, element)); this.selectedJournalElementId = element.id; }
    } catch (_error) { this.toast = '未选择图片'; }
  }
  private async replaceSelectedJournalImage(): Promise<void> {
    const selected = this.selectedJournalElement();
    if (!selected || selected.type !== 'image') return;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions(); options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length > 0) { await this.editSelectedJournalText(result.photoUris[0]); this.toast = '图片已替换'; }
    } catch (_error) { this.toast = '未选择图片'; }
  }
  private async addJournalPageAndOpen(): Promise<void> { const nextIndex = this.selectedJournal()?.pages.length || 0; await this.updateSelectedJournal((book: JournalBook) => JournalService.addPage(book)); this.selectedJournalPage = nextIndex; this.selectedJournalElementId = ''; }
  private async duplicateJournalPageAndOpen(): Promise<void> { const nextIndex = this.selectedJournalPage + 1; await this.updateSelectedJournal((book: JournalBook) => JournalService.duplicatePage(book, this.selectedJournalPage)); this.selectedJournalPage = nextIndex; this.selectedJournalElementId = ''; }
  private async applyJournalTemplate(): Promise<void> {
    const next = this.journalTemplate === 'wetland' ? 'forest' : (this.journalTemplate === 'forest' ? 'minimal' : 'wetland');
    this.journalTemplate = next;
    await this.updateSelectedJournal((book: JournalBook) => JournalService.applyTemplate(book, next));
    this.toast = next === 'wetland' ? '已切换到湿地晨光模板' : (next === 'forest' ? '已切换到林间观察模板' : '已切换到极简档案模板');
  }
  private async exportJournalPage(): Promise<void> {
    try {
      this.journalSaveStatus = '正在导出…';
      const pixelMap = await this.getUIContext().getComponentSnapshot().get('journal-canvas');
      const packer = image.createImagePacker(); const option: image.PackingOption = { format: 'image/png', quality: 100 };
      const buffer = await packer.packToData(pixelMap, option); const name = '观鸟手账_' + Date.now().toString() + '.png'; const path = this.context.cacheDir + '/' + name;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC); fs.writeSync(file.fd, buffer); fs.closeSync(file);
      const config: photoAccessHelper.PhotoCreationConfig = { title: this.journalTitle + '_第' + (this.selectedJournalPage + 1).toString() + '页', fileNameExtension: 'png', photoType: photoAccessHelper.PhotoType.IMAGE };
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context); await helper.showAssetsCreationDialog([fileUri.getUriFromPath(path)], [config]);
      this.journalSaveStatus = '已自动保存'; this.toast = '手账图片已保存到相册';
    } catch (_error) { this.journalSaveStatus = '已自动保存'; this.toast = '导出失败，请确认相册保存授权'; }
  }
  private async deleteJournal(id: string, closeEditor: boolean): Promise<void> { if (id.length === 0) { this.toast = '没有选中的手账'; return; } await this.saveJournals(this.journalBooks.filter((book: JournalBook) => book.id !== id)); this.selectedJournalPage = 0; this.selectedJournalElementId = ''; if (closeEditor) this.page = AppRoute.home(); this.toast = '手账已删除'; }
  private async deleteSelectedJournal(): Promise<void> { await this.deleteJournal(this.page.bookId, true); }
  private birdName(id: string): string { return ObservationService.speciesName(this.guideSpecies, id); }
  private birdScientificName(id: string): string { return this.guideSpecies.find((item: BirdSpecies) => item.id === id)?.scientificName || ''; }
  private selectedBirdSpecies(speciesId: string = this.speciesId): BirdSpecies { return this.guideSpecies.find((item: BirdSpecies) => item.id === speciesId) || SPECIES[0]; }
  private formatPostTime(value: string): string { return value.length >= 16 ? value.substring(0, 16).replace('T', ' ') : value; }
  private visibleObservations(): Observation[] {
    let result = this.records;
    if (this.selectedPlaceFilter.length > 0) result = result.filter((item: Observation) => item.placeName === this.selectedPlaceFilter);
    if (this.observationFilter === '本月') result = result.filter((item: Observation) => item.observedAt.indexOf(new Date().getFullYear().toString() + '-' + (new Date().getMonth() + 1).toString().padStart(2, '0')) === 0);
    if (this.observationFilter === '有照片') result = result.filter((item: Observation) => item.photos.length > 0);
    return result;
  }
  private selectedRecord(): Observation | undefined { return ObservationService.findById(this.records, this.page.observationId); }
  private beginNewRecord(speciesId: string = 'egret', keepPhotos: boolean = false): void {
    this.editingRecordId = ''; this.speciesId = speciesId; this.countText = '1'; this.place = '奥森南园湿地';
    this.note = ''; this.behavior = '觅食'; if (!keepPhotos) this.photos = []; this.fuzzy = true; this.recordLatitude = 0; this.recordLongitude = 0; this.locationStatus = '尚未设置坐标'; this.page = AppRoute.observationEditor('', speciesId);
  }
  private beginEditRecord(id: string): void {
    const record = ObservationService.findById(this.records, id);
    if (!record) { this.toast = '记录不存在'; return; }
    this.editingRecordId = id; this.speciesId = record.speciesId;
    this.countText = record.count.toString(); this.place = record.placeName; this.note = record.note;
    this.photos = record.photos; this.fuzzy = record.fuzzyLocation;
    this.recordLatitude = record.latitude; this.recordLongitude = record.longitude; this.locationStatus = record.latitude !== 0 || record.longitude !== 0 ? '已保存观察位置' : '尚未设置坐标';
    this.behavior = record.behaviors && record.behaviors.length > 0 ? record.behaviors[0] : '觅食'; this.page = AppRoute.observationEditor(id, record.speciesId);
  }
  private async useCurrentLocation(): Promise<void> {
    this.locationStatus = '正在获取当前位置…';
    const result = await LocationService.getCurrentLocation(this.context);
    if (result.success) {
      this.recordLatitude = result.latitude; this.recordLongitude = result.longitude; this.locationStatus = '已使用当前位置'; this.toast = result.message;
    } else {
      this.locationStatus = '尚未设置坐标'; this.toast = result.message;
    }
  }
  private async saveRecord(): Promise<void> {
    const hasLocation = this.recordLatitude !== 0 || this.recordLongitude !== 0;
    const input: ObservationInput = { speciesId: this.speciesId, countText: this.countText, observedAt: '', placeName: this.place,
      audioNote: '', note: this.note, fuzzyLocation: this.fuzzy, photos: this.photos, behaviors: [this.behavior],
      latitude: hasLocation ? this.recordLatitude : (this.editingRecordId.length > 0 ? undefined : 0),
      longitude: hasLocation ? this.recordLongitude : (this.editingRecordId.length > 0 ? undefined : 0),
      locationSource: hasLocation ? 'current' : (this.editingRecordId.length > 0 ? undefined : 'none'), existingCount: this.records.length };
    if (this.editingRecordId.length > 0) {
      this.records = ObservationService.updateObservation(this.records, this.editingRecordId, input);
      if (!await ObservationStorage.save(this.context, this.records)) { this.toast = '保存失败，已保留当前编辑'; return; }
      const changed = ObservationService.findById(this.records, this.editingRecordId); if (changed) await this.enqueueObservation('upsert', changed);
      const observationId = this.editingRecordId; this.resetIdentification(); this.page = AppRoute.observationDetail(observationId); this.toast = '观察已更新'; return;
    }
    const item = ObservationService.createObservation(input); this.records = [item].concat(this.records);
    if (!await ObservationStorage.save(this.context, this.records)) { this.records = this.records.filter((record: Observation) => record.id !== item.id); this.toast = '保存失败，请重试'; return; }
    await this.enqueueObservation('upsert', item);
    this.resetIdentification(); this.page = AppRoute.observationDetail(item.id); this.toast = '观察已保存';
  }
  private async removeSelectedRecord(): Promise<void> {
    const observationId = this.page.observationId; if (observationId.length === 0) return;
    const previous = this.records; this.records = ObservationService.deleteObservation(this.records, observationId);
    if (!await ObservationStorage.save(this.context, this.records)) { this.records = previous; this.toast = '删除失败，请重试'; return; }
    await this.enqueueDeletedObservation(observationId);
    this.confirmDelete = false; this.editingRecordId = ''; this.page = AppRoute.observations(); this.toast = '观察已删除';
  }
  private speciesImage(id: string): Resource {
    const catalogImage = catalogSpeciesImage(id);
    if (catalogImage !== undefined) return catalogImage;
    return $r('app.media.background');
  }
  private birds(): BirdSpecies[] {
    const matches = ObservationService.filterSpecies(this.guideSpecies, this.keyword);
    if (this.guideMode === '我见过的') return matches.filter((item: BirdSpecies) => ObservationService.speciesFrequency(this.records, item.id) > 0);
    if (this.guideMode === '湿地') return matches.filter((item: BirdSpecies) => item.regions.indexOf('湿地') >= 0 || item.regions.indexOf('城市湿地') >= 0);
    return matches;
  }
  private resetIdentification(): void {
    this.photos = [];
    this.identificationCandidates = [];
    this.identificationMode = 'unavailable';
    this.identificationWarning = '';
    this.identificationLoading = false;
  }
  private pickPhoto(): void {
    if (!this.aiUploadConsent) {
      this.requestAiConsent(true);
      return;
    }
    if (this.authMode !== 'authenticated') {
      this.toast = 'AI 识鸟需要先登录；照片不会在登录前打开或上传';
      this.page = AppRoute.settings();
      return;
    }
    this.selectIdentificationPhoto();
  }
  private requestAiConsent(startIdentification: boolean): void {
    this.showConfirmDialog(
      '允许 AI 分析照片？',
      '识鸟照片会发送到你配置的 Birdfolio 后端，并由后端转发给视觉模型进行分析。照片不会在你同意前上传；使用 AI 前还需要邮箱登录。',
      startIdentification ? '改为手动选择' : '取消',
      '同意并继续',
      GREEN,
      async () => {
        const saved = await PrivacyStorage.setAiPhotoConsent(this.context, true);
        if (!saved) { this.toast = '授权状态保存失败，请重试'; return; }
        this.aiUploadConsent = true;
        this.toast = '已允许 AI 图片识别';
        if (startIdentification) this.selectIdentificationPhoto();
      },
      () => {
        if (startIdentification) {
          this.beginNewRecord('egret', false);
          this.page = AppRoute.speciesPicker(AppRoute.observationEditor('', this.speciesId));
        }
      }
    );
  }
  private requestRevokeAiConsent(): void {
    if (!this.aiUploadConsent) { this.requestAiConsent(false); return; }
    this.showConfirmDialog(
      '撤销 AI 图片授权？',
      '撤销后，应用不会再上传识鸟照片；下次使用时会重新询问。',
      '取消',
      '确认撤销',
      RED,
      async () => {
        const saved = await PrivacyStorage.revokeAiPhotoConsent(this.context);
        if (!saved) { this.toast = '授权状态保存失败，请重试'; return; }
        this.aiUploadConsent = false;
        this.toast = '已撤销 AI 图片授权';
      }
    );
  }
  private requestCutoutConsent(): void {
    const granting = !this.cutoutUploadConsent;
    this.showConfirmDialog(
      granting ? '允许 AI 主体抠图？' : '撤销 AI 抠图授权？',
      granting
        ? '未来使用主体抠图时，应用会把你主动选择的图片发送到 Birdfolio 后端生成蒙版。此授权与识鸟分开记录；当前版本尚未启用抠图上传。'
        : '撤销后，未来的主体抠图不会上传照片，除非你再次单独同意。',
      '取消',
      granting ? '单独同意' : '确认撤销',
      granting ? GREEN : RED,
      async () => {
        const saved = await PrivacyStorage.setConsent(this.context, 'cutout', granting);
        if (!saved) { this.toast = '授权状态保存失败，请重试'; return; }
        this.cutoutUploadConsent = granting;
        this.toast = granting ? '已记录 AI 抠图授权' : '已撤销 AI 抠图授权';
      }
    );
  }
  private requestClearLocalData(): void {
    this.showConfirmDialog(
      '清除本机数据？',
      '将清除本机观察、手账、草稿、缓存、授权记录和登录会话。此操作不会删除云端账号或云端数据，且无法在本机撤销。',
      '取消',
      '清除本机数据',
      RED,
      async () => {
        const cleared = await LocalDataCleanupService.clear(this.context);
        if (!cleared) { this.toast = '部分本机数据清理失败，请重试'; return; }
        await ObservationStorage.save(this.context, []);
        await JournalStorage.save(this.context, []);
        await CommunityStorage.savePosts(this.context, []);
        await CommunityStorage.saveDrafts(this.context, []);
        await SyncQueueStorage.save(this.context, []);
        await SpeciesStorage.save(this.context, []);
        this.records = [];
        this.journalBooks = [];
        this.communityPosts = [];
        this.communityDrafts = [];
        this.syncJobs = [];
        this.customSpecies = [];
        this.guideSpecies = SPECIES;
        this.authSession = null;
        this.authMode = 'guest';
        this.authEmail = '';
        this.authCode = '';
        this.aiUploadConsent = false;
        this.cutoutUploadConsent = false;
        this.mapPrivacyAgreed = false;
        Privacy.setUserAgreePrivacy(false);
        this.page = AppRoute.home();
        this.toast = '本机数据已清除，云端账号和云端数据未删除';
      }
    );
  }
  private currentLegalDocument(): LegalDocumentContent {
    const id = this.page.legalDocumentId;
    if (id === 'agreement' || id === 'ai' || id === 'licenses') return legalDocument(id as LegalDocumentId);
    return legalDocument('privacy');
  }
  private async selectIdentificationPhoto(): Promise<void> {
    this.resetIdentification();
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 3;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      this.photos = result.photoUris;
      if (this.photos.length > 0) { this.page = AppRoute.identificationResult(this.speciesId); await this.identifySelectedPhoto(); }
    } catch (error) { this.toast = '未选择照片'; }
  }
  private async pickAvatar(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length > 0) this.avatarUri = result.photoUris[0];
    } catch (error) { this.toast = '未选择头像'; }
  }
  private async saveProfile(): Promise<void> {
    if (this.displayName.trim().length === 0) { this.toast = '昵称不能为空'; return; }
    this.profileSaving = true;
    const profile: UserProfile = { displayName: this.displayName, bio: this.bio, avatarUri: this.avatarUri };
    const saved = await ProfileStorage.save(this.context, profile);
    this.profileSaving = false;
    if (!saved) { this.toast = '资料保存失败，请重试'; return; }
    this.displayName = this.displayName.trim();
    this.bio = this.bio.trim();
    this.toast = '资料已保存';
    this.page = AppRoute.home();
  }
  private profilePosts(): CommunityPost[] {
    const ownerId = this.authSession !== null ? this.authSession.userId : 'demo-user';
    return this.communityPosts.filter((item: CommunityPost) => item.userId === ownerId);
  }
  private profilePhotos(): ProfilePhotoItem[] {
    const result: ProfilePhotoItem[] = [];
    this.records.forEach((record: Observation) => {
      record.photos.forEach((uri: string, index: number) => {
        if (uri.length > 0 && uri !== 'placeholder') result.push({ id: record.id + '-' + index.toString(), observationId: record.id, uri: uri });
      });
    });
    return result;
  }
  private async pickPublishPhoto(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 3;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length > 0) this.publishPhotoUri = result.photoUris[0];
    } catch (error) { this.toast = '未选择照片'; }
  }

  private candidateSpecies(candidate: IdentificationCandidate): BirdSpecies {
    return { id: candidate.speciesId, name: candidate.name, scientificName: candidate.scientificName,
      aliases: candidate.aliases, category: candidate.category, description: candidate.description,
      regions: candidate.regions, imageHint: candidate.imageHint, features: candidate.reasons, dataSource: candidate.inCatalog ? 'OFFLINE' : 'AI' };
  }

  private selectedIdentificationCandidate(): IdentificationCandidate | undefined {
    return this.identificationCandidates.find((item: IdentificationCandidate) => item.speciesId === this.speciesId);
  }

  private async confirmIdentifiedSpecies(): Promise<void> {
    const candidate = this.selectedIdentificationCandidate();
    if (!candidate) return;
    if (this.aiRequestId.length > 0 && this.authMode === 'authenticated') {
      try {
        await this.api().confirmIdentification(this.aiRequestId, candidate.speciesId);
        await this.api().submitIdentificationFeedback({ requestId: this.aiRequestId, selectedSpeciesId: candidate.speciesId, accepted: true, note: '用户确认候选' });
        this.aiRequestStatus = 'user_confirmed';
      } catch (_error) {
        // The local observation remains the source of truth when telemetry is unavailable.
        this.aiRequestStatus = 'user_confirmed';
      }
    }
    if (!candidate.inCatalog && this.customSpecies.findIndex((item: BirdSpecies) => item.id === candidate.speciesId) < 0) {
      const species = this.candidateSpecies(candidate);
      const next = [species].concat(this.customSpecies);
      if (!await SpeciesStorage.save(this.context, next)) { this.toast = '鸟种资料保存失败，请重试'; return; }
      this.customSpecies = next;
    }
    const selected = this.candidateSpecies(candidate);
    if (this.guideSpecies.findIndex((item: BirdSpecies) => item.id === selected.id) < 0) this.guideSpecies = [selected].concat(this.guideSpecies);
    this.beginNewRecord(candidate.speciesId, true);
  }

  private async identifySelectedPhoto(): Promise<void> {
    if (this.photos.length === 0) return;
    if (!this.aiUploadConsent) {
      this.identificationMode = 'unavailable';
      this.identificationWarning = '尚未同意上传照片。你可以从离线图鉴手动选择鸟种。';
      return;
    }
    if (this.authMode !== 'authenticated') {
      this.identificationMode = 'unavailable';
      this.aiRequestStatus = 'unavailable';
      this.identificationWarning = 'AI 识鸟需要先登录后上传照片。照片不会在登录前发送；你可以从离线图鉴手动选择鸟种。';
      return;
    }
    this.identificationLoading = true;
    this.identificationCandidates = [];
    this.identificationWarning = '';
    this.aiRequestId = '';
    this.aiRequestStatus = 'uploading';
    try {
      const dataUrl = await this.readJournalImage(this.photos[0]);
      if (dataUrl.length === 0) throw new Error('IMAGE_READ_FAILED');
      let result: IdentificationResult | IdentificationResultV2;
      const media = await this.api().uploadMedia({ dataUrl: dataUrl, fileName: 'bird.jpg', mimeType: 'image/jpeg' });
      const metadata: IdentificationMetadata = { placeName: this.place, observedAt: new Date().toISOString().slice(0, 10) };
      const v2 = await this.api().identifyMedia(media.mediaId, metadata);
      result = v2;
      this.aiRequestId = v2.requestId;
      this.aiRequestStatus = v2.status;
      this.identificationMode = result.mode === 'provider' ? 'provider' : 'unavailable';
      this.identificationCandidates = result.candidates;
      this.identificationWarning = result.warning;
      if (result.candidates.length > 0) {
        this.speciesId = result.candidates[0].speciesId;
        result.candidates.forEach((candidate: IdentificationCandidate) => {
          if (this.guideSpecies.findIndex((item: BirdSpecies) => item.id === candidate.speciesId) < 0) this.guideSpecies = [this.candidateSpecies(candidate)].concat(this.guideSpecies);
        });
      }
      if (this.aiRequestStatus === 'provider_success' || this.aiRequestStatus === 'user_confirmed') {
        this.backendMessage = '后端已连接 · 视觉模型可用';
      } else {
        this.backendMessage = '后端已连接 · 识鸟服务暂不可用';
      }
    } catch (error) {
      const failure = error as ApiServiceError;
      this.aiRequestStatus = ApiService.identificationStatusForError(failure.errorCode || 'NETWORK_ERROR');
      this.identificationMode = 'unavailable';
      this.identificationCandidates = [];
      const statusText = this.aiRequestStatus === 'quota_exceeded' ? '今日识别次数已用完' : (this.aiRequestStatus === 'provider_error' ? '视觉服务返回错误' : '网络或服务暂不可用');
      this.identificationWarning = statusText + '：' + this.networkError(error) + '。没有伪造候选，请重试或从图鉴手动选择。';
    }
    this.identificationLoading = false;
  }

  private candidatePercent(candidate: IdentificationCandidate): string { return Math.round(candidate.finalScore * 100).toString() + '%'; }
  private identificationBadge(): string {
    if (this.identificationMode === 'provider' && this.aiRequestStatus === 'user_confirmed') return '已确认 · 可生成记录';
    if (this.identificationMode === 'provider') return 'AI 候选 · 待确认';
    if (this.aiRequestStatus === 'quota_exceeded') return '今日额度已用完';
    if (this.aiRequestStatus === 'provider_error') return '视觉服务错误';
    if (this.aiRequestStatus === 'transport_error') return '网络不可用';
    return '识别暂不可用';
  }

  private openPost(id: string): void {
    this.page = AppRoute.postDetail(id); this.commentDraft = ''; this.postComments = [];
    this.loadPostComments();
  }

  private async loadPostComments(): Promise<void> {
    if (this.page.postId.length === 0) return;
    try { this.postComments = await this.api().comments(this.page.postId); } catch (_error) { this.postComments = []; }
  }

  private replaceCommunityPost(post: CommunityPost): void {
    this.communityPosts = this.communityPosts.map((item: CommunityPost) => item.id === post.id ? post : item);
    CommunityStorage.savePosts(this.context, this.communityPosts);
  }

  private copyPost(post: CommunityPost): CommunityPost {
    return { id: post.id, userId: post.userId, authorName: post.authorName, type: post.type, title: post.title, body: post.body, speciesId: post.speciesId, behavior: post.behavior, placeName: post.placeName, visibility: post.visibility, imageUrl: post.imageUrl, createdAt: post.createdAt, updatedAt: post.updatedAt, likeCount: post.likeCount, favoriteCount: post.favoriteCount, commentCount: post.commentCount, liked: post.liked, favorited: post.favorited };
  }

  private async togglePostReaction(kind: 'like' | 'favorite'): Promise<void> {
    if (this.authMode !== 'authenticated') { this.toast = '登录后才能点赞或收藏'; this.page = AppRoute.settings(); return; }
    const post = this.selectedPost(); if (!post) return;
    const active = kind === 'like' ? !!post.liked : !!post.favorited;
    const optimistic: CommunityPost = this.copyPost(post);
    if (kind === 'like') { optimistic.liked = !active; optimistic.likeCount = Math.max(0, post.likeCount + (active ? -1 : 1)); }
    else { optimistic.favorited = !active; optimistic.favoriteCount = Math.max(0, post.favoriteCount + (active ? -1 : 1)); }
    this.replaceCommunityPost(optimistic);
    try {
      const remote = await this.api().react(post.id, kind, !active);
      remote.liked = kind === 'like' ? !active : optimistic.liked;
      remote.favorited = kind === 'favorite' ? !active : optimistic.favorited;
      this.replaceCommunityPost(remote);
    } catch (_error) { this.replaceCommunityPost(post); this.toast = '互动未同步，请检查后端连接'; }
  }

  private async submitComment(): Promise<void> {
    if (this.authMode !== 'authenticated') { this.toast = '登录后才能发表评论'; this.page = AppRoute.settings(); return; }
    const postId = this.page.postId; const body = this.commentDraft.trim(); if (body.length === 0 || postId.length === 0) { this.toast = '请输入评论内容'; return; }
    try {
      const comment = await this.api().addComment(postId, body);
      this.postComments = this.postComments.concat([comment]); this.commentDraft = '';
      const post = this.selectedPost(); if (post) { const updated: CommunityPost = this.copyPost(post); updated.commentCount = post.commentCount + 1; this.replaceCommunityPost(updated); }
      this.toast = '评论已发布';
    } catch (_error) { this.toast = '评论发送失败，请检查后端连接'; }
  }

  private currentPostDraft(): PostDraft {
    return { id: this.activePostDraftId.length > 0 ? this.activePostDraftId : 'draft-' + Date.now().toString(), title: this.publishTitle.trim(), body: this.publishBody.trim(), speciesId: this.speciesId, behavior: this.behavior, placeName: this.place, visibility: this.publishVisibility, type: this.publishMode === '手账作品' ? 'journal' : 'photo', imageUri: this.publishPhotoUri, updatedAt: new Date().toISOString() };
  }

  private async savePostDraft(showToast: boolean = true): Promise<void> {
    const draft = this.currentPostDraft();
    this.activePostDraftId = draft.id;
    this.communityDrafts = [draft].concat(this.communityDrafts.filter((item: PostDraft) => item.id !== draft.id));
    await CommunityStorage.saveDrafts(this.context, this.communityDrafts);
    if (showToast) this.toast = '草稿已保存在本机';
  }

  private restoreLatestPostDraft(): void {
    if (this.communityDrafts.length === 0) { this.toast = '没有可恢复的发布草稿'; return; }
    const draft = this.communityDrafts[0]; this.activePostDraftId = draft.id; this.publishTitle = draft.title; this.publishBody = draft.body; this.speciesId = draft.speciesId; this.behavior = draft.behavior; this.place = draft.placeName; this.publishVisibility = draft.visibility; this.publishMode = draft.type === 'journal' ? '手账作品' : '照片动态'; this.publishPhotoUri = draft.imageUri; this.toast = '已恢复最近草稿';
  }

  private clearPublishForm(): void { this.publishTitle = ''; this.publishBody = ''; this.publishPhotoUri = ''; this.publishVisibility = '所有人'; this.activePostDraftId = ''; }

  private async publishPost(): Promise<void> {
    if (this.authMode !== 'authenticated') { await this.savePostDraft(false); this.toast = '请先登录，内容已保存为本地草稿'; this.page = AppRoute.settings(); return; }
    if (this.publishTitle.trim().length === 0 || this.publishBody.trim().length === 0) { this.toast = '请填写标题和正文'; return; }
    this.publishing = true;
    try {
      let imageBase64 = '';
      let mediaId = '';
      if (this.publishPhotoUri.length > 0) {
        const dataUrl = await this.readJournalImage(this.publishPhotoUri);
        if (this.authMode === 'authenticated') {
          const media = await this.api().uploadMedia({ dataUrl: dataUrl, fileName: 'community.jpg', mimeType: 'image/jpeg' });
          mediaId = media.mediaId;
        } else {
          imageBase64 = dataUrl;
        }
      }
      const input: CreatePostInput = { authorName: this.displayName, type: this.publishMode === '手账作品' ? 'journal' : 'photo', title: this.publishTitle.trim(), body: this.publishBody.trim(), speciesId: this.speciesId, behavior: this.behavior, placeName: this.place, visibility: this.publishVisibility, imageBase64: imageBase64, mediaId: mediaId.length > 0 ? mediaId : undefined };
      const post = await this.api().createPost(input);
      this.communityPosts = [post].concat(this.communityPosts.filter((item: CommunityPost) => item.id !== post.id));
      await CommunityStorage.savePosts(this.context, this.communityPosts);
      if (this.activePostDraftId.length > 0) { this.communityDrafts = this.communityDrafts.filter((item: PostDraft) => item.id !== this.activePostDraftId); await CommunityStorage.saveDrafts(this.context, this.communityDrafts); }
      this.clearPublishForm(); this.page = AppRoute.home(); this.tab = 'community'; this.backendStatus = 'online'; this.toast = '已发布到社区';
    } catch (_error) {
      await this.savePostDraft(false); this.backendStatus = 'offline'; this.toast = '发布失败，内容已保存为本地草稿';
    }
    this.publishing = false;
  }
  build() {
    Stack() {
      if (this.page.name === 'home') {
        Column() {
          if (this.tab === 'home') HomeView({
            avatarUri: this.avatarUri,
            recentRecords: this.records.slice(0, 2),
            recentBirdNames: this.records.slice(0, 2).map((item: Observation) => this.birdName(item.speciesId)),
            recentBirdImages: this.records.slice(0, 2).map((item: Observation) => this.speciesImage(item.speciesId)),
            onOpenProfile: () => this.tab = 'mine',
            onOpenMigration: () => this.page = AppRoute.migration(),
            onIdentify: () => this.pickPhoto(),
            onOpenAudio: () => this.page = AppRoute.audio(),
            onNewObservation: () => this.beginNewRecord(),
            onOpenObservations: () => this.page = AppRoute.observations(),
            onSelectObservation: (id: string) => this.page = AppRoute.observationDetail(id)
          })
          else if (this.tab === 'journal') JournalBooksView({
            books: this.journalBooks,
            recentRecords: this.records.slice(0, 3),
            recentBirdNames: this.records.slice(0, 3).map((item: Observation) => this.birdName(item.speciesId)),
            onOpenShop: () => this.page = AppRoute.shop(),
            onCreateBook: () => this.createJournal(),
            onOpenBook: (id: string) => this.openJournal(id),
            onDeleteBook: (id: string) => this.confirmDeleteJournalBookById(id),
            onOpenObservations: () => this.page = AppRoute.observations(),
            onCreateFromObservation: (id: string) => this.createJournal([id]),
            onOpenWorks: () => { this.profileMode = '作品'; this.tab = 'mine' }
          })
          else if (this.tab === 'community') CommunityView({
            mode: $communityMode,
            backendMessage: this.backendMessage,
            backendStatus: this.backendStatus,
            loading: this.communityLoading,
            authMode: this.authMode,
            posts: this.visibleCommunityPosts(),
            postSpeciesNames: this.visibleCommunityPosts().map((item: CommunityPost) => this.birdName(item.speciesId)),
            postTimes: this.visibleCommunityPosts().map((item: CommunityPost) => this.formatPostTime(item.createdAt)),
            postMediaUrls: this.visibleCommunityPosts().map((item: CommunityPost) => this.api().mediaUrl(item.imageUrl)),
            onPublish: () => { this.clearPublishForm(); this.page = AppRoute.publish(this.speciesId) },
            onPlanningNotice: () => this.toast = '关注关系将在后续版本开放',
            onModeChange: (_mode: string) => this.refreshCommunity(),
            onOpenPost: (id: string) => this.openPost(id)
          })
          else if (this.tab === 'guide') GuideView({
            keyword: $keyword,
            mode: $guideMode,
            species: this.birds(),
            speciesImages: this.birds().map((item: BirdSpecies) => this.speciesImage(item.id)),
            speciesFrequencies: this.birds().map((item: BirdSpecies) => ObservationService.speciesFrequency(this.records, item.id)),
            catalogCount: this.guideSpecies.length,
            recordedSpeciesCount: ObservationService.speciesCount(this.records),
            loading: this.guideLoading,
            message: this.guideMessage,
            onSearchOnline: (value: string) => this.loadGuideSpecies(value),
            onModeChange: (_mode: string) => {},
            onSelectSpecies: (id: string) => { this.speciesId = id; this.page = AppRoute.birdDetail(id) }
          })
          else ProfileView({
            mode: $profileMode,
            backendStatus: this.backendStatus,
            backendStatusLabel: this.backendStatusText(),
            displayName: this.displayName,
            bio: this.bio,
            avatarUri: this.avatarUri,
            authMode: this.authMode,
            authEmail: this.authEmail,
            observationCount: this.records.length,
            speciesCount: ObservationService.speciesCount(this.records),
            placeCount: ObservationService.placeCount(this.records),
            observations: this.records,
            observationBirdNames: this.records.map((item: Observation) => this.birdName(item.speciesId)),
            observationBirdImages: this.records.map((item: Observation) => this.speciesImage(item.speciesId)),
            posts: this.profileMode === '收藏' ? this.communityPosts.filter((item: CommunityPost) => !!item.favorited) : this.profilePosts(),
            postSpeciesNames: (this.profileMode === '收藏' ? this.communityPosts.filter((item: CommunityPost) => !!item.favorited) : this.profilePosts()).map((item: CommunityPost) => this.birdName(item.speciesId)),
            postTimes: (this.profileMode === '收藏' ? this.communityPosts.filter((item: CommunityPost) => !!item.favorited) : this.profilePosts()).map((item: CommunityPost) => this.formatPostTime(item.createdAt)),
            postMediaUrls: (this.profileMode === '收藏' ? this.communityPosts.filter((item: CommunityPost) => !!item.favorited) : this.profilePosts()).map((item: CommunityPost) => this.api().mediaUrl(item.imageUrl)),
            books: this.journalBooks,
            photoUris: this.profilePhotos().map((item: ProfilePhotoItem) => item.uri),
            photoObservationIds: this.profilePhotos().map((item: ProfilePhotoItem) => item.observationId),
            onRetrySync: () => this.processSyncQueue(),
            onOpenSettings: () => this.page = AppRoute.settings(),
            onEditProfile: () => this.page = AppRoute.profileEdit(),
            onOpenMap: () => this.page = AppRoute.map(),
            onOpenStats: () => this.page = AppRoute.stats(),
            onSelectObservation: (id: string) => { if (id.length > 0) this.page = AppRoute.observationDetail(id) },
            onOpenPost: (id: string) => this.openPost(id),
            onOpenBook: (id: string) => this.openJournal(id),
            onOpenShop: () => this.page = AppRoute.shop()
          })
          this.Nav()
        }.width('100%').height('100%').backgroundColor(BG)
      } else {
        Column() {
          if (this.page.name === 'identificationResult') IdentificationResultView({
            speciesId: $speciesId,
            photoUri: this.photos.length > 0 ? this.photos[0] : '',
            badge: this.identificationBadge(),
            loading: this.identificationLoading,
            candidates: this.identificationCandidates,
            candidateImages: this.identificationCandidates.map((item: IdentificationCandidate) => this.speciesImage(item.speciesId)),
            selectedName: this.birdName(this.speciesId),
            selectedScientificName: this.birdScientificName(this.speciesId),
            selectedScore: this.identificationCandidates.length > 0 ? this.candidatePercent(this.identificationCandidates.find((item: IdentificationCandidate) => item.speciesId === this.speciesId) || this.identificationCandidates[0]) : '0%',
            warning: this.identificationWarning,
            onBack: () => this.page = AppRoute.home(),
            onConfirm: () => this.confirmIdentifiedSpecies(),
            onManualSelect: () => this.page = AppRoute.speciesPicker(AppRoute.observationEditor('', this.speciesId)),
            onRetry: () => this.pickPhoto()
          })
          else if (this.page.name === 'audio') AudioPlanningView({ onBack: () => this.page = AppRoute.home(), onReturnHome: () => { this.page = AppRoute.home(); this.tab = 'home' } })
          else if (this.page.name === 'observationEditor') this.Record()
          else if (this.page.name === 'observationDetail') ObservationDetailPage({
            record: this.selectedRecord(),
            birdName: this.selectedRecord() === undefined ? '' : this.birdName(this.selectedRecord()!.speciesId),
            scientificName: this.selectedRecord() === undefined ? '' : this.birdScientificName(this.selectedRecord()!.speciesId),
            image: this.speciesImage(this.selectedRecord() === undefined ? '' : this.selectedRecord()!.speciesId),
            onBack: () => this.page = AppRoute.observations(),
            onEdit: () => { if (this.selectedRecord() !== undefined) this.beginEditRecord(this.selectedRecord()!.id) },
            onDelete: () => this.confirmDelete = true,
            onCreateJournal: () => { if (this.selectedRecord() !== undefined) this.createJournal([this.selectedRecord()!.id]) }
          })
          else if (this.page.name === 'journalEditor') JournalEditorWebView({
            controller: this.journalWebController,
            bridge: this.journalWebBridge,
            needsProxyReload: $journalWebNeedsProxyReload,
            onSelectFile: (result: FileSelectorResult) => this.selectJournalWebFile(result),
            onReady: () => this.loadJournalIntoWeb(),
            onError: (_error: BusinessError) => { SafeLogger.error('BirdfolioJournal', 'bridge_registration_failed'); this.toast = '手账编辑器连接失败，请重新进入' }
          })
          else if (this.page.name === 'birdDetail') BirdDetailView({
            species: this.selectedBirdSpecies(this.page.speciesId),
            image: this.selectedBirdSpecies(this.page.speciesId).imageUrl !== undefined && this.selectedBirdSpecies(this.page.speciesId).imageUrl!.length > 0 ? this.selectedBirdSpecies(this.page.speciesId).imageUrl! : this.speciesImage(this.page.speciesId),
            detailMode: $detailMode,
            onBack: () => this.page = AppRoute.home(),
            onNewObservation: (id: string) => this.beginNewRecord(id)
          })
          else if (this.page.name === 'stats') StatsView({ records: this.records, selectedYear: $selectedYear, birdName: (id: string) => this.birdName(id), onBack: () => this.page = AppRoute.home(), onNewObservation: () => this.beginNewRecord() })
          else if (this.page.name === 'shop') this.Shop()
          else if (this.page.name === 'publish') PublishView({
            mode: $publishMode,
            title: $publishTitle,
            body: $publishBody,
            behavior: $behavior,
            postVisibility: $publishVisibility,
            photoUri: this.publishPhotoUri,
            speciesName: this.birdName(this.speciesId),
            draftCount: this.communityDrafts.length,
            hasActiveDraft: this.activePostDraftId.length > 0,
            publishing: this.publishing,
            onBack: () => this.page = AppRoute.home(),
            onRestoreDraft: () => this.restoreLatestPostDraft(),
            onPickPhoto: () => this.pickPublishPhoto(),
            onPickSpecies: () => this.page = AppRoute.speciesPicker(AppRoute.publish(this.speciesId)),
            onSaveDraft: () => { this.savePostDraft(); this.page = AppRoute.home(); this.tab = 'community' },
            onPublish: () => this.publishPost()
          })
          else if (this.page.name === 'postDetail') PostDetailView({
            post: this.selectedPost(),
            comments: this.postComments,
            speciesName: this.selectedPost() === undefined ? '' : this.birdName(this.selectedPost()!.speciesId),
            scientificName: this.selectedPost() === undefined ? '' : this.birdScientificName(this.selectedPost()!.speciesId),
            mediaUrl: this.selectedPost() === undefined ? '' : this.api().mediaUrl(this.selectedPost()!.imageUrl),
            commentDraft: $commentDraft,
            onBack: () => this.page = AppRoute.home(),
            onReturnCommunity: () => { this.page = AppRoute.home(); this.tab = 'community' },
            onLike: () => this.togglePostReaction('like'),
            onFavorite: () => this.togglePostReaction('favorite'),
            onSubmitComment: () => this.submitComment()
          })
          else if (this.page.name === 'observations') ObservationsView({
            filter: $observationFilter,
            placeFilter: $selectedPlaceFilter,
            observations: this.visibleObservations(),
            birdNames: this.visibleObservations().map((item: Observation) => this.birdName(item.speciesId)),
            birdImages: this.visibleObservations().map((item: Observation) => this.speciesImage(item.speciesId)),
            onBack: () => this.page = AppRoute.home(),
            onSelectObservation: (id: string) => this.page = AppRoute.observationDetail(id),
            onNewObservation: () => this.beginNewRecord()
          })
          else if (this.page.name === 'migration') MigrationPlanningView({ onBack: () => this.page = AppRoute.home() })
          else if (this.page.name === 'map') MapView({
            records: this.records,
            privacyLoaded: this.mapPrivacyLoaded,
            privacyAgreed: this.mapPrivacyAgreed,
            birdName: (id: string) => this.birdName(id),
            onBack: () => this.page = AppRoute.home(),
            onRequestPrivacy: () => this.requestMapPrivacyConsent(),
            onOpenObservations: (placeName: string) => { this.selectedPlaceFilter = placeName; this.page = AppRoute.observations() },
            onNewObservation: () => this.beginNewRecord(),
            onNotice: (message: string) => this.toast = message
          })
          else if (this.page.name === 'profileEdit') ProfileEditView({ displayName: $displayName, bio: $bio, avatarUri: $avatarUri, profileSaving: this.profileSaving, onBack: () => this.page = AppRoute.home(), onPickAvatar: () => this.pickAvatar(), onSave: () => this.saveProfile() })
          else if (this.page.name === 'settings') SettingsView({
            backendUrl: $backendUrl,
            authEmail: $authEmail,
            authCode: $authCode,
            fuzzy: $fuzzy,
            backendStatus: this.backendStatus,
            backendStatusLabel: this.backendStatusText(),
            backendMessage: this.backendMessage,
            syncSummary: '连接顺序：先检查当前地址；若失败且 USB/HDC 本机通道可用，会自动切换到 http://127.0.0.1:8787。无线连接请填写电脑 WLAN IPv4 地址。待同步 ' + SyncQueueService.pendingCount(this.syncJobs).toString() + ' 条 · 本地发布草稿 ' + this.communityDrafts.length.toString() + ' 篇',
            authMode: this.authMode,
            authLoading: this.authLoading,
            authMessage: this.authMessage,
            aiUploadConsent: this.aiUploadConsent,
            cutoutUploadConsent: this.cutoutUploadConsent,
            onBack: () => this.page = AppRoute.home(),
            onSaveBackend: () => this.saveBackendUrl(),
            onRetrySync: () => { this.checkBackend().then(() => this.processSyncQueue()) },
            onRequestCode: () => this.requestLoginCode(),
            onLogin: () => this.verifyLoginCode(),
            onExportData: () => this.exportAccountData(),
            onLogout: () => this.logoutAccount(),
            onDeleteAccount: () => this.deleteAccount(),
            onAiConsentAction: () => this.requestRevokeAiConsent(),
            onCutoutConsentAction: () => this.requestCutoutConsent(),
            onOpenLegal: (id: string) => this.page = AppRoute.legal(id),
            onClearLocalData: () => this.requestClearLocalData(),
            onShowStorageInfo: () => this.toast = '观察、手账和社区缓存均保存在本机',
            onShowAbout: () => this.toast = 'Birdfolio 商业 Beta · AI 结果需用户确认'
          })
          else if (this.page.name === 'legal') LegalDocumentView({ document: this.currentLegalDocument(), onBack: () => this.page = AppRoute.settings() })
          else if (this.page.name === 'speciesPicker') SpeciesPickerView({
            keyword: $keyword,
            selectedSpeciesId: this.speciesId,
            species: this.birds(),
            speciesImages: this.birds().map((item: BirdSpecies) => this.speciesImage(item.id)),
            onBack: () => this.page = this.page.returnRoute(),
            onSelect: (id: string) => { const returnRoute = this.page.returnRoute(); this.speciesId = id; this.keyword = ''; this.page = returnRoute.name === 'publish' ? AppRoute.publish(id) : AppRoute.observationEditor(returnRoute.observationId, id) }
          })
          else if (this.page.name === 'product') ProductDetailView({ onBack: () => this.page = AppRoute.shop() })
          else if (this.page.name === 'notifications') NotificationsPlanningView({ onBack: () => this.page = AppRoute.home() })
        }.width('100%').height('100%').backgroundColor(BG)
      }
      if (this.toast.length > 0) {
        Text(this.toast).fontSize(13).fontColor(WHITE).backgroundColor(INK)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 }).borderRadius(8)
          .align(Alignment.Bottom).margin({ bottom: 86 }).onClick(() => this.toast = '')
      }
      if (this.confirmDelete) {
        this.DeleteDialog()
      }
    }
  }

  @Builder Record() {
    ObservationEditorView({
      speciesId: $speciesId,
      countText: $countText,
      place: $place,
      behavior: $behavior,
      note: $note,
      fuzzy: $fuzzy,
      speciesImage: this.speciesImage(this.speciesId),
      species: this.selectedBirdSpecies(),
      editing: this.editingRecordId.length > 0,
      onBack: () => this.page = this.editingRecordId.length > 0 ? AppRoute.observationDetail(this.page.observationId) : AppRoute.home(),
      onSpeciesPicker: () => this.page = AppRoute.speciesPicker(AppRoute.observationEditor(this.page.observationId, this.speciesId)),
      locationStatus: $locationStatus,
      latitude: $recordLatitude,
      longitude: $recordLongitude,
      onUseCurrentLocation: () => this.useCurrentLocation(),
      onSave: () => this.saveRecord()
    })
  }

  @Builder Shop() {
    Column() { this.Header('创作素材'); Scroll() { Column({ space: 16 }) {
      Row({ space: 24 }) {
        Text('数字素材').fontSize(15).fontWeight(this.shopMode === '数字素材' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.shopMode === '数字素材' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.shopMode === '数字素材' ? 2 : 0 }, color: GREEN }).onClick(() => this.shopMode = '数字素材')
        Text('实体周边').fontSize(15).fontWeight(this.shopMode === '实体周边' ? FontWeight.Bold : FontWeight.Regular).fontColor(this.shopMode === '实体周边' ? GREEN : MUTED).height(36).padding({ bottom: 7 }).border({ width: { bottom: this.shopMode === '实体周边' ? 2 : 0 }, color: GREEN }).onClick(() => this.shopMode = '实体周边')
      }; Scroll() { Row({ space: 8 }) { this.ShopChip('精选'); this.ShopChip('模板'); this.ShopChip('贴纸'); this.ShopChip('字体'); this.ShopChip('画笔') } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      if (this.shopMode === '数字素材') { Stack({ alignContent: Alignment.BottomStart }) { Image($r('app.media.shop_feature')).width('100%').height(220).objectFit(ImageFit.Cover).borderRadius(8); Column({ space: 4 }) { Text('湿地博物志 · 创作套装').fontFamily(SERIF).fontSize(20).fontColor(WHITE); Text('本地模板、贴纸与字体素材').fontSize(12).fontColor(WHITE) }.padding(14).width('100%').backgroundColor('#771C241F') }.onClick(() => this.page = AppRoute.product()); Grid() { this.Product('野外观察单页模板', '本地素材', $r('app.media.shop_template')); this.Product('东亚涉禽贴纸组', '本地素材', $r('app.media.shop_stickers')); this.Product('自然志衬线字体', '本地素材', $r('app.media.journal_herons')); this.Product('湿画法水彩笔刷', '规划中', $r('app.media.shop_feature')) }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(12) }
      else { Image($r('app.media.journal_waterbirds')).width('100%').height(260).objectFit(ImageFit.Cover).borderRadius(8); Column({ space: 5 }) { Text('实体自然手账 · 规划中').fontFamily(SERIF).fontSize(18).fontColor(INK); Text('当前课程原型不包含实体商品、支付或到货提醒。').fontSize(13).fontColor(MUTED) }.padding(16).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8) }
    }.padding({ left: 16, right: 16, bottom: 28 }) }.layoutWeight(1) }.backgroundColor(BG)
  }

  @Builder DeleteDialog() {
    Stack() { Column({ space: 14 }) { Text('删除这条观察？').fontFamily(SERIF).fontSize(20).fontColor(INK); Text('删除后只会移除 Birdfolio 中的记录，系统相册中的原图不会被删除。').fontSize(13).fontColor(MUTED).lineHeight(20); Row({ space: 10 }) { Button('取消').layoutWeight(1).height(44).fontColor(INK).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.confirmDelete = false); Button('确认删除').layoutWeight(1).height(44).fontColor(WHITE).backgroundColor(RED).borderRadius(8).onClick(() => this.removeSelectedRecord()) } }.padding(20).width('88%').backgroundColor(WHITE).borderRadius(16).shadow({ radius: 18, color: '#33000000', offsetY: 6 }) }.width('100%').height('100%').backgroundColor('#66000000').alignContent(Alignment.Center)
  }

  @Builder Header(title: string) { Row() { this.Icon($r('app.media.ic_back'), '返回', () => this.page = AppRoute.home()); Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).textAlign(TextAlign.Center).layoutWeight(1); Stack().width(44).height(44) }.width('100%').height(58).padding({ left: 12, right: 12 }).backgroundColor(WHITE).border({ width: { bottom: 1 }, color: BORDER }) }
  @Builder SubHeader(title: string, fn: () => void) { Row() { this.Icon($r('app.media.ic_back'), '返回', fn); Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).textAlign(TextAlign.Center).layoutWeight(1); Stack().width(44).height(44) }.width('100%').height(58).padding({ left: 12, right: 12 }).backgroundColor(WHITE).border({ width: { bottom: 1 }, color: BORDER }) }
  @Builder Icon(icon: Resource, label: string, fn: () => void) { Stack() { Image(icon).width(24).height(24).objectFit(ImageFit.Contain) }.width(44).height(44).borderRadius(8).onClick(() => fn()).accessibilityText(label) }
  @Builder Cover(t: string, c: string) { GridItem() { Column({ space: 9 }) { Image($r('app.media.bird_hero')).width('100%').height(148).objectFit(ImageFit.Cover).borderRadius(4); Text(t).fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK).width('100%') }.padding(10).backgroundColor(c).borderRadius(8).onClick(() => this.createJournal()) } }
  @Builder ShopChip(t: string) { Text(t).fontSize(13).fontColor(this.shopCategory === t ? GREEN : MUTED).padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor(this.shopCategory === t ? GREEN_SOFT : WHITE).border({ width: 1, color: this.shopCategory === t ? GREEN : BORDER }).borderRadius(18).onClick(() => this.shopCategory = t) }
  @Builder Nav() { Row() { this.NavItem($r('app.media.ic_home'), $r('app.media.ic_home_active'), '首页', 'home'); this.NavItem($r('app.media.ic_book'), $r('app.media.ic_book_active'), '手账', 'journal'); this.NavItem($r('app.media.ic_community'), $r('app.media.ic_community_active'), '社区', 'community'); this.NavItem($r('app.media.ic_search'), $r('app.media.ic_search_active'), '图鉴', 'guide'); this.NavItem($r('app.media.ic_user'), $r('app.media.ic_user_active'), '我的', 'mine') }.width('100%').height(64).padding({ left: 16, right: 16, top: 4, bottom: 4 }).justifyContent(FlexAlign.SpaceAround).backgroundColor(WHITE).border({ width: { top: 1 }, color: BORDER }) }
  @Builder NavItem(icon: Resource, activeIcon: Resource, t: string, id: string) { Column({ space: 2 }) { Image(this.tab === id ? activeIcon : icon).width(22).height(22).objectFit(ImageFit.Contain); Text(t).fontSize(11).fontWeight(this.tab === id ? FontWeight.Medium : FontWeight.Regular).fontColor(this.tab === id ? GREEN : MUTED) }.justifyContent(FlexAlign.Center).width(56).height(52).backgroundColor(this.tab === id ? GREEN_SOFT : '#00000000').borderRadius(8).onClick(() => this.tab = id) }
  @Builder Product(name: string, price: string, img: Resource) { GridItem() { Column({ space: 7 }) { Image(img).width('100%').height(130).objectFit(ImageFit.Cover).borderRadius(6); Text(name).fontFamily(SERIF).fontSize(14).fontColor(INK).width('100%').maxLines(2); Text(price).fontSize(13).fontColor(GREEN).width('100%') }.padding(9).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.page = AppRoute.product()) } }
}
