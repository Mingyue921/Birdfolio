type IconProps = { size?: number }
const base = (size: number) => ({ width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true })
export function LeafIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="M19.5 4.5C12 4 6.2 7.4 5 13.1c-.7 3.4 1.3 5.8 4.5 5.4 5.8-.8 8.9-6.7 10-14Z"/><path d="M4.5 20c2.8-5.2 6.3-8.2 11.5-11"/></svg> }
export function CameraIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="M4 7h3l1.4-2h7.2L17 7h3v12H4Z"/><circle cx="12" cy="13" r="4"/></svg> }
export function CheckIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="m5 12 4 4L19 6"/></svg> }
export function MapIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="m4 6 5-2 6 2 5-2v14l-5 2-6-2-5 2Z"/><path d="M9 4v14M15 6v14"/></svg> }
export function ChartIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg> }
export function ShieldIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="M12 3 4.5 6v5.5c0 4.5 3 7.7 7.5 9.5 4.5-1.8 7.5-5 7.5-9.5V6Z"/><path d="m8.5 12 2.2 2.2 4.8-5"/></svg> }
export function ArrowIcon({ size = 20 }: IconProps) { return <svg {...base(size)}><path d="M5 12h14M14 7l5 5-5 5"/></svg> }
export function SparkIcon({ size = 24 }: IconProps) { return <svg {...base(size)}><path d="m12 3 1.2 4.3L17 9l-3.8 1.7L12 15l-1.2-4.3L7 9l3.8-1.7ZM5 15l.8 2.2L8 18l-2.2.8L5 21l-.8-2.2L2 18l2.2-.8Z"/></svg> }
