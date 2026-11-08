import { DrawerItem, Observation, RoadmapPhase, StickerAsset, TabItem } from '../models/BirdModels';
export { SPECIES } from './BirdCatalog.generated';

export const STICKERS: StickerAsset[] = [
  { id: 'leaf', name: '叶片', category: 'natural', imageUrl: '', free: true },
  { id: 'feather', name: '羽毛', category: 'natural', imageUrl: '', free: true },
  { id: 'water', name: '水纹', category: 'place', imageUrl: '', free: true },
  { id: 'sun', name: '晴天', category: 'weather', imageUrl: '', free: true }
];

export const TABS: TabItem[] = [
  { id: 'home', label: '首页' },
  { id: 'journal', label: '手账' },
  { id: 'community', label: '社区' },
  { id: 'guide', label: '图鉴' },
  { id: 'mine', label: '我的' }
];

export const PHASES: RoadmapPhase[] = [
  {
    id: 'phase-1',
    title: 'Phase 1 · 核心体验',
    status: 'active',
    summary: '把记录、图鉴、地图、统计和手账做顺。',
    items: ['手动选鸟', '本地保存', '个人统计', '地图足迹', '模板手账']
  },
  {
    id: 'phase-2',
    title: 'Phase 2 · 创作工具',
    status: 'planned',
    summary: '把模板、贴纸、排版和导出做扎实。',
    items: ['模板切换', '贴纸商店', '字体选择', '图片排版', '导出图片']
  },
  {
    id: 'phase-3',
    title: 'Phase 3 · 云同步',
    status: 'planned',
    summary: '接账号、对象存储和同步队列。',
    items: ['账号登录', '云数据库', '对象存储', '失败重试', '权限申请']
  },
  {
    id: 'phase-4',
    title: 'Phase 4 · 扩展生态',
    status: 'planned',
    summary: '再打开识别、社区、商店和 AI 绘图。',
    items: ['图片识别', '音频识别', 'AI 绘图', '社区帖子', '虚拟货币']
  }
];

export const DRAWER_ITEMS: DrawerItem[] = [
  { id: 'settings', label: '设置', detail: '偏好、隐私、权限' },
  { id: 'wallet', label: '钱包', detail: 'Phase 3 后接入' },
  { id: 'orders', label: '订单', detail: '商店购买记录' },
  { id: 'cart', label: '购物车', detail: '贴纸与周边' },
  { id: 'drafts', label: '草稿', detail: '未完成手账' },
  { id: 'history', label: '浏览记录', detail: '图鉴与内容历史' }
];

export const INITIAL_OBSERVATIONS: Observation[] = [
  {
    id: 'obs-1',
    userId: 'demo-user',
    speciesId: 'egret',
    count: 2,
    observedAt: '2026-06-08',
    latitude: 39.9921,
    longitude: 116.3908,
    placeName: '奥森南园湿地',
    photos: ['placeholder'],
    audioNote: '短促鸣叫，伴随水声。',
    note: '白鹭在浅水区觅食，偶尔低飞换到另一片芦苇边。',
    fuzzyLocation: true,
    createdAt: '2026-06-08 09:40'
  },
  {
    id: 'obs-2',
    userId: 'demo-user',
    speciesId: 'kingfisher',
    count: 1,
    observedAt: '2026-06-07',
    latitude: 39.9868,
    longitude: 116.3819,
    placeName: '清河步道',
    photos: [],
    audioNote: '',
    note: '停在低枝上观察水面，颜色非常醒目。',
    fuzzyLocation: true,
    createdAt: '2026-06-07 17:12'
  },
  {
    id: 'obs-3',
    userId: 'demo-user',
    speciesId: 'bulbul',
    count: 4,
    observedAt: '2026-06-03',
    latitude: 39.9762,
    longitude: 116.3652,
    placeName: '社区花园',
    photos: [],
    audioNote: '清亮连续鸣叫。',
    note: '傍晚在香樟树上活动，成对出现。',
    fuzzyLocation: false,
    createdAt: '2026-06-03 18:20'
  }
];
