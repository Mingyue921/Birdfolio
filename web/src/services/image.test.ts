import { describe, expect, it } from 'vitest'
import { compressImage } from './image'

describe('compressImage', () => {
  it('rejects non-image files before reading bytes', async () => {
    await expect(compressImage(new File(['hello'], 'note.txt', { type: 'text/plain' }))).rejects.toThrow('INVALID_FILE_TYPE')
  })
  it('rejects files larger than 20 MB', async () => {
    const large = new File([new Uint8Array(20 * 1024 * 1024 + 1)], 'large.jpg', { type: 'image/jpeg' })
    await expect(compressImage(large)).rejects.toThrow('FILE_TOO_LARGE')
  })
})
