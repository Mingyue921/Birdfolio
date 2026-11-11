import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export class LegacyPreferencesReader {
  static readString(context: common.UIAbilityContext, storeName: string, key: string): string {
    const path = context.preferencesDir + '/' + storeName;
    let file: fs.File | null = null;
    try {
      const stat = fs.statSync(path);
      if (stat.size <= 0) return '';
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const bytes = new Uint8Array(stat.size);
      const read = fs.readSync(file.fd, bytes.buffer);
      if (read !== stat.size) return '';
      return LegacyPreferencesReader.parseString(bytes, key);
    } catch (_error) {
      return '';
    } finally {
      if (file !== null) fs.closeSync(file);
    }
  }

  static parseString(bytes: Uint8Array, key: string): string {
    const source = util.TextDecoder.create('utf-8').decodeToString(bytes);
    return LegacyPreferencesReader.parseSource(source, key);
  }

  static parseSource(source: string, key: string): string {
    const marker = '<string key="' + key + '">';
    const start = source.indexOf(marker);
    if (start < 0) return '';
    const valueStart = start + marker.length;
    const end = source.indexOf('</string>', valueStart);
    if (end < 0) return '';
    return LegacyPreferencesReader.decodeXml(source.substring(valueStart, end));
  }

  private static decodeXml(value: string): string {
    return value.replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  }
}
