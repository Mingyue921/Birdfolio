export type LegalDocumentId = 'privacy' | 'agreement' | 'ai' | 'licenses';

export interface LegalSection {
  title: string;
  body: string;
}

export interface LegalDocumentContent {
  id: LegalDocumentId;
  title: string;
  version: string;
  notice: string;
  sections: LegalSection[];
}

const DRAFT_NOTICE = '商业发布前草案，需在正式发布前由专业人员复核。运营主体、联系方式、服务商和数据保留期限仍为待确认事项。';

export function legalDocument(id: LegalDocumentId): LegalDocumentContent {
  if (id === 'agreement') return {
    id, title: '用户协议', version: '0.1-draft', notice: DRAFT_NOTICE,
    sections: [
      { title: '服务范围', body: 'Birdfolio 提供本地观察、图鉴、地图、手账，以及可选的账号、AI、同步和社区能力。游客可使用主要本地功能。' },
      { title: 'AI 候选', body: 'AI 结果仅用于缩小候选范围，不构成科研级鉴定。用户确认后才会形成观察记录。' },
      { title: '用户内容', body: '用户应确保上传照片和社区内容具有合法来源，不得发布违法、有害或泄露敏感鸟类位置的信息。' },
      { title: '当前边界', body: '生产 HTTPS、正式邮件服务、社区审核后台和运营联系方式尚待完成；未完成前不对外承诺正式商业服务等级。' }
    ]
  };
  if (id === 'ai') return {
    id, title: 'AI 图片处理说明', version: '2026-11-beta-draft', notice: DRAFT_NOTICE,
    sections: [
      { title: '识鸟用途', body: '只有在你单独同意并选择照片后，应用才会将照片发送至 Birdfolio 后端，再由后端调用配置的视觉模型。' },
      { title: '抠图用途', body: '未来的 AI 主体抠图使用独立授权。同意识鸟不会自动同意抠图，反之亦然。' },
      { title: '撤回', body: '撤回后停止后续上传，但不会自动删除此前已处理的数据。历史数据删除与服务商联动仍待正式部署确认。' },
      { title: '人工确认', body: '识别结果最多提供候选及依据；低置信度需要人工判断，未经确认不会自动创建观察记录。' }
    ]
  };
  if (id === 'licenses') return {
    id, title: '第三方许可与来源', version: '0.1-draft', notice: '以下为仓库可验证的发布归属摘要，完整逐项清单随项目 THIRD_PARTY_ASSETS.md 和素材清单保存。',
    sections: [
      { title: '鸟类照片', body: '离线图鉴照片来自 GBIF 与 Wikimedia Commons，仅使用 CC0 1.0 或 CC BY 4.0 素材；作者、许可和来源记录在逐图清单中。' },
      { title: '贴纸', body: '内置 OpenMoji 子集采用 CC BY-SA 4.0，需保留作者归属及相同方式共享要求。' },
      { title: '字体', body: '手账字体来自 Google Fonts，采用 SIL Open Font License 1.1，原始 OFL 文本随字体资源保留。' },
      { title: '编辑器与地图', body: 'Fabric.js 5.3.0 使用 MIT 许可。腾讯地图按其 SDK 条款和隐私政策提供在线地图能力。' }
    ]
  };
  return {
    id: 'privacy', title: '隐私政策', version: '0.1-draft', notice: DRAFT_NOTICE,
    sections: [
      { title: '本地优先', body: '观察、手账、草稿和偏好默认保存在设备中。游客无需账号即可使用主要本地功能。' },
      { title: '账号与同步', body: '邮箱登录、云同步、社区和 AI 需要网络。会话 Token 使用 HarmonyOS 安全资产存储，不写入普通 Preferences。' },
      { title: '照片与 AI', body: '照片只在用户选择且对应处理目的已授权时上传。识鸟和抠图分别授权，可随时撤回后续处理许可。' },
      { title: '定位与地图', body: '只有点击“使用当前位置”时才请求模糊定位。拒绝权限仍可保存无坐标记录。社区不应公开精确位置。' },
      { title: '用户控制', body: '设置中可撤回 AI 授权、退出登录、导出基础云端数据、删除云端账号或清除本地数据。清除本地数据不等于删除云端账号。' }
    ]
  };
}
