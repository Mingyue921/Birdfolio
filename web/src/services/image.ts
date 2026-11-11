export interface CompressedImage { dataUrl: string; previewUrl: string; width: number; height: number }

export async function compressImage(file: File, maxEdge = 1600, quality = 0.85): Promise<CompressedImage> {
  if (!file.type.startsWith('image/')) throw new Error('INVALID_FILE_TYPE')
  if (file.size > 20 * 1024 * 1024) throw new Error('FILE_TOO_LARGE')
  const bitmap = await createImageBitmap(file)
  const scale = Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height))
  const width = Math.max(1, Math.round(bitmap.width * scale))
  const height = Math.max(1, Math.round(bitmap.height * scale))
  const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height
  const context = canvas.getContext('2d')
  if (!context) { bitmap.close(); throw new Error('CANVAS_UNAVAILABLE') }
  context.drawImage(bitmap, 0, 0, width, height); bitmap.close()
  const dataUrl = canvas.toDataURL('image/jpeg', quality)
  return { dataUrl, previewUrl: dataUrl, width, height }
}
