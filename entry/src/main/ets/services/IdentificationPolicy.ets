export class IdentificationPolicy {
  static readonly LOW_CONFIDENCE_THRESHOLD: number = 0.55;

  static shouldAutoSelect(finalScore: number): boolean {
    return Number.isFinite(finalScore) && finalScore >= IdentificationPolicy.LOW_CONFIDENCE_THRESHOLD;
  }

  static failureTitle(status: string, errorCode: string): string {
    const code = errorCode.toUpperCase();
    if (status === 'quota_exceeded') return '今日识别次数已用完';
    if (code === 'TIMEOUT') return 'AI 请求超时';
    if (code === 'IMAGE_READ_FAILED' || code === 'MEDIA_UPLOAD_FAILED') return '图片上传失败';
    if (status === 'provider_error') return 'AI 视觉服务返回错误';
    if (status === 'transport_error') return '无法连接 Birdfolio 服务';
    return 'AI 服务未配置或暂不可用';
  }
}
