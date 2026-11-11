/** Pure release logging policy: only stable event identifiers are emitted. */
export class ReleaseLogPolicy {
  static event(value: string): string {
    return value.replace(/[^a-zA-Z0-9_.-]/g, '_').slice(0, 80) || 'unknown';
  }
}
