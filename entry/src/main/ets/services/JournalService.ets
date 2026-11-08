import { BirdSpecies, JournalBook, JournalElement, JournalElementStyle, JournalPage, Observation } from '../models/BirdModels';

const CANVAS_WIDTH = 720;
const CANVAS_HEIGHT = 960;
const MIN_VISIBLE = 24;

export class JournalService {
  static createBook(observations: Observation[], species: BirdSpecies[], title: string = '自然观察手账'): JournalBook {
    const now = Date.now().toString();
    const pages = observations.length > 0 ? observations.map((item: Observation, index: number) => JournalService.pageFromObservation(item, species, index)) : [JournalService.emptyPage('page-' + now)];
    return { id: 'journal-' + now, title: title, observationIds: observations.map((item: Observation) => item.id), templateId: 'wetland', pages: pages, status: 'draft', createdAt: now, updatedAt: now, editorVersion: 3 };
  }

  static renameBook(book: JournalBook, title: string): JournalBook { const result = JournalService.cloneBook(book); result.title = title; result.updatedAt = Date.now().toString(); return result; }

  static pageFromObservation(observation: Observation, species: BirdSpecies[], index: number): JournalPage {
    const bird = species.find((item: BirdSpecies) => item.id === observation.speciesId); const base = Date.now().toString() + '-' + index.toString();
    const titleStyle: JournalElementStyle = { fontSize: 54, fontFamily: 'Birdfolio XiaoWei', color: '#1C241F', lineHeight: 1.15 };
    const metaStyle: JournalElementStyle = { fontSize: 25, color: '#4F8396', lineHeight: 1.2 };
    const noteStyle: JournalElementStyle = { fontSize: 29, color: '#1C241F', lineHeight: 1.35 };
    const elements: JournalElement[] = [
      JournalService.element(base + '-title', 'text', 70, 65, 580, 80, bird ? bird.name : '观察记录', 1, titleStyle, 'title', '鸟种标题'),
      JournalService.element(base + '-meta', 'text', 70, 145, 580, 50, observation.observedAt + ' · ' + observation.placeName, 2, metaStyle, 'meta', '日期与地点'),
      JournalService.element(base + '-obs', 'observation', 70, 700, 580, 190, observation.id, 4, noteStyle, 'observation', '观察信息')
    ];
    if (observation.photos.length > 0) elements.push(JournalService.element(base + '-photo', 'image', 70, 210, 580, 450, observation.photos[0], 3, { opacity: 1, borderRadius: 12, imageFit: 'contain' }, 'photo', '观察照片'));
    return { id: 'page-' + base, elements: JournalService.normalizeLayers(elements), backgroundColor: '#FFFEFA', updatedAt: Date.now().toString() };
  }

  static emptyPage(id: string): JournalPage { return { id: id, elements: [], backgroundColor: '#FFFEFA', updatedAt: Date.now().toString() }; }

  static applyTemplate(book: JournalBook, templateId: string): JournalBook {
    const result = JournalService.cloneBook(book); result.templateId = templateId;
    result.pages.forEach((page: JournalPage) => {
      page.backgroundColor = templateId === 'forest' ? '#F1F5EE' : (templateId === 'minimal' ? '#FFFFFF' : '#FFFEFA');
      page.elements.forEach((item: JournalElement) => JournalService.layoutManagedElement(item, templateId)); page.updatedAt = Date.now().toString();
    });
    result.updatedAt = Date.now().toString(); return result;
  }

  static addPage(book: JournalBook): JournalBook { const result = JournalService.cloneBook(book); result.pages.push(JournalService.emptyPage('page-' + Date.now().toString())); result.updatedAt = Date.now().toString(); return result; }

  static duplicatePage(book: JournalBook, index: number): JournalBook {
    if (index < 0 || index >= book.pages.length) return book; const result = JournalService.cloneBook(book); const source = result.pages[index];
    const elements = source.elements.map((item: JournalElement) => { const clone = JournalService.cloneElement(item); clone.id += '-copy-' + Date.now().toString(); clone.role = 'user'; return clone; });
    result.pages.splice(index + 1, 0, { id: 'page-' + Date.now().toString(), elements: elements, backgroundColor: source.backgroundColor, updatedAt: Date.now().toString() }); result.updatedAt = Date.now().toString(); return result;
  }

  static deletePage(book: JournalBook, index: number): JournalBook { const result = JournalService.cloneBook(book); result.pages = result.pages.filter((_item: JournalPage, i: number) => i !== index); if (result.pages.length === 0) result.pages.push(JournalService.emptyPage('page-' + Date.now().toString())); result.updatedAt = Date.now().toString(); return result; }

  static reorderPage(book: JournalBook, from: number, to: number): JournalBook {
    if (from < 0 || to < 0 || from >= book.pages.length || to >= book.pages.length || from === to) return book;
    const result = JournalService.cloneBook(book); const moved = result.pages.splice(from, 1)[0]; result.pages.splice(to, 0, moved); result.updatedAt = Date.now().toString(); return result;
  }

  static addElement(book: JournalBook, pageIndex: number, element: JournalElement): JournalBook { const result = JournalService.cloneBook(book); if (result.pages[pageIndex]) result.pages[pageIndex].elements = JournalService.normalizeLayers(result.pages[pageIndex].elements.concat([JournalService.cloneElement(element)])); result.updatedAt = Date.now().toString(); return result; }

  static updateElement(book: JournalBook, pageIndex: number, element: JournalElement): JournalBook {
    const result = JournalService.cloneBook(book); const page = result.pages[pageIndex]; if (!page) return book; const safe = JournalService.cloneElement(element);
    safe.scale = JournalService.clamp(safe.scale, 0.4, 3); safe.x = JournalService.clamp(safe.x, MIN_VISIBLE - safe.width * safe.scale, CANVAS_WIDTH - MIN_VISIBLE); safe.y = JournalService.clamp(safe.y, MIN_VISIBLE - safe.height * safe.scale, CANVAS_HEIGHT - MIN_VISIBLE); safe.rotation = ((safe.rotation % 360) + 360) % 360;
    page.elements = page.elements.map((item: JournalElement) => item.id === safe.id ? safe : item); page.updatedAt = Date.now().toString(); result.updatedAt = page.updatedAt; return result;
  }

  static updateElementContent(book: JournalBook, pageIndex: number, id: string, content: string): JournalBook { return JournalService.mutateElement(book, pageIndex, id, (element: JournalElement) => element.content = content); }
  static updateElementStyle(book: JournalBook, pageIndex: number, id: string, style: JournalElementStyle): JournalBook {
    return JournalService.mutateElement(book, pageIndex, id, (element: JournalElement) => {
      element.style = JournalService.mergeStyle(element.style, style);
    });
  }
  static renameElement(book: JournalBook, pageIndex: number, id: string, name: string): JournalBook { return JournalService.mutateElement(book, pageIndex, id, (element: JournalElement) => element.name = name.trim() || JournalService.defaultName(element)); }
  static setElementLocked(book: JournalBook, pageIndex: number, id: string, locked: boolean): JournalBook { return JournalService.mutateElement(book, pageIndex, id, (element: JournalElement) => element.locked = locked); }
  static setElementVisible(book: JournalBook, pageIndex: number, id: string, visible: boolean): JournalBook { return JournalService.mutateElement(book, pageIndex, id, (element: JournalElement) => element.visible = visible); }

  static deleteElement(book: JournalBook, pageIndex: number, id: string): JournalBook { const result = JournalService.cloneBook(book); if (result.pages[pageIndex]) result.pages[pageIndex].elements = JournalService.normalizeLayers(result.pages[pageIndex].elements.filter((item: JournalElement) => item.id !== id)); result.updatedAt = Date.now().toString(); return result; }

  static duplicateElement(book: JournalBook, pageIndex: number, id: string): JournalBook { const page = book.pages[pageIndex]; const source = page ? page.elements.find((item: JournalElement) => item.id === id) : undefined; if (!source) return book; const clone = JournalService.cloneElement(source); clone.id += '-copy-' + Date.now().toString(); clone.x += 24; clone.y += 24; clone.role = 'user'; return JournalService.addElement(book, pageIndex, clone); }

  static moveLayer(book: JournalBook, pageIndex: number, id: string, direction: number): JournalBook {
    const result = JournalService.cloneBook(book); const page = result.pages[pageIndex]; if (!page) return book; const ordered = page.elements.slice().sort((a, b) => a.zIndex - b.zIndex); const from = ordered.findIndex((item: JournalElement) => item.id === id); if (from < 0) return book; const to = JournalService.clamp(from + direction, 0, ordered.length - 1); const moved = ordered.splice(from, 1)[0]; ordered.splice(to, 0, moved); page.elements = JournalService.normalizeLayers(ordered); page.updatedAt = Date.now().toString(); result.updatedAt = page.updatedAt; return result;
  }

  static transformElement(book: JournalBook, pageIndex: number, id: string, dx: number, dy: number, scaleFactor: number, angle: number): JournalBook { const page = book.pages[pageIndex]; const source = page ? page.elements.find((item: JournalElement) => item.id === id) : undefined; if (!source || source.locked) return book; const clone = JournalService.cloneElement(source); clone.x += dx; clone.y += dy; clone.scale *= scaleFactor; clone.rotation += angle; return JournalService.updateElement(book, pageIndex, clone); }

  static undoLastDrawing(book: JournalBook, pageIndex: number): JournalBook { const page = book.pages[pageIndex]; if (!page) return book; let id = ''; page.elements.forEach((item: JournalElement) => { if (item.type === 'drawing') id = item.id; }); return id.length > 0 ? JournalService.deleteElement(book, pageIndex, id) : book; }
  static clearDrawings(book: JournalBook, pageIndex: number): JournalBook { const result = JournalService.cloneBook(book); if (result.pages[pageIndex]) result.pages[pageIndex].elements = JournalService.normalizeLayers(result.pages[pageIndex].elements.filter((item: JournalElement) => item.type !== 'drawing')); result.updatedAt = Date.now().toString(); return result; }

  static normalizeBook(book: JournalBook): JournalBook {
    const now = Date.now().toString(); const pages = book.pages && book.pages.length > 0 ? book.pages.map((page: JournalPage) => JournalService.normalizePage(page)) : [JournalService.emptyPage('page-' + now)];
    return { id: book.id || 'journal-' + now, title: book.title || '自然观察手账', observationIds: book.observationIds || [], templateId: book.templateId || 'wetland', pages: pages, status: book.status === 'completed' ? 'completed' : 'draft', createdAt: book.createdAt || now, updatedAt: book.updatedAt || now, coverImageUri: book.coverImageUri, editorVersion: 3 };
  }

  static parse(raw: string): JournalBook[] { if (!raw) return []; try { const parsed = JSON.parse(raw) as JournalBook[]; return Array.isArray(parsed) ? parsed.map((book: JournalBook) => JournalService.normalizeBook(book)) : []; } catch (_error) { return []; } }

  static element(id: string, type: 'text' | 'image' | 'sticker' | 'drawing' | 'observation', x: number, y: number, width: number, height: number, content: string, zIndex: number, style?: JournalElementStyle, role: 'title' | 'meta' | 'photo' | 'observation' | 'decoration' | 'user' = 'user', name?: string): JournalElement {
    return { id: id, type: type, x: x, y: y, width: width, height: height, rotation: 0, scale: 1, zIndex: zIndex, locked: false, visible: true, name: name || JournalService.typeName(type), role: role, content: content, style: style };
  }

  private static mutateElement(book: JournalBook, pageIndex: number, id: string, mutate: (element: JournalElement) => void): JournalBook { const page = book.pages[pageIndex]; const source = page ? page.elements.find((item: JournalElement) => item.id === id) : undefined; if (!source) return book; const clone = JournalService.cloneElement(source); mutate(clone); return JournalService.updateElement(book, pageIndex, clone); }
  private static normalizePage(page: JournalPage): JournalPage { const elements = (page.elements || []).map((item: JournalElement) => JournalService.normalizeElement(item)); return { id: page.id || 'page-' + Date.now().toString(), elements: JournalService.normalizeLayers(elements), backgroundColor: page.backgroundColor || '#FFFEFA', updatedAt: page.updatedAt || Date.now().toString() }; }
  private static normalizeElement(item: JournalElement): JournalElement { const clone = JournalService.cloneElement(item); clone.visible = item.visible !== false; clone.locked = item.locked === true; clone.role = item.role || JournalService.inferRole(item); clone.name = item.name || JournalService.defaultName(clone); clone.style = JournalService.copyStyle(item.style); if (clone.type === 'image') { clone.style.opacity = clone.style.opacity === undefined ? 1 : JournalService.clamp(clone.style.opacity, 0.2, 1); clone.style.borderRadius = clone.style.borderRadius || 0; clone.style.imageFit = 'contain'; } return clone; }
  private static inferRole(item: JournalElement): 'title' | 'meta' | 'photo' | 'observation' | 'decoration' | 'user' { if (item.id.endsWith('-title')) return 'title'; if (item.id.endsWith('-meta')) return 'meta'; if (item.id.endsWith('-photo')) return 'photo'; if (item.id.endsWith('-obs') || item.type === 'observation') return 'observation'; return 'user'; }
  private static defaultName(item: JournalElement): string { if (item.role === 'title') return '鸟种标题'; if (item.role === 'meta') return '日期与地点'; if (item.role === 'photo') return '观察照片'; if (item.role === 'observation') return '观察信息'; return JournalService.typeName(item.type); }
  private static typeName(type: string): string { if (type === 'text') return '文字'; if (type === 'image') return '图片'; if (type === 'sticker') return '贴纸'; if (type === 'drawing') return '笔画'; return '观察信息'; }

  private static layoutManagedElement(item: JournalElement, templateId: string): void {
    if (!item.role || item.role === 'user' || item.role === 'decoration') return; item.rotation = 0;
    let layout: number[] = [];
    if (templateId === 'forest') {
      if (item.role === 'title') layout = [65, 580, 590];
      else if (item.role === 'meta') layout = [65, 650, 590];
      else if (item.role === 'photo') layout = [50, 50, 620, 500];
      else if (item.role === 'observation') layout = [65, 720, 590];
    } else if (templateId === 'minimal') {
      if (item.role === 'title') layout = [70, 100, 270];
      else if (item.role === 'meta') layout = [70, 180, 270];
      else if (item.role === 'photo') layout = [390, 130, 260, 420];
      else if (item.role === 'observation') layout = [70, 280, 270];
    } else {
      if (item.role === 'title') layout = [70, 65, 580];
      else if (item.role === 'meta') layout = [70, 145, 580];
      else if (item.role === 'photo') layout = [70, 210, 580, 450];
      else if (item.role === 'observation') layout = [70, 700, 580];
    }
    if (layout.length === 0) return; item.x = layout[0]; item.y = layout[1]; if (item.type === 'image') item.scale = Math.min(layout[2] / Math.max(1, item.width), layout[3] / Math.max(1, item.height)); else { item.width = layout[2]; item.scale = 1; }
  }

  private static normalizeLayers(elements: JournalElement[]): JournalElement[] { return elements.slice().sort((a, b) => a.zIndex - b.zIndex).map((item: JournalElement, index: number) => { const clone = JournalService.cloneElement(item); clone.zIndex = index; return clone; }); }
  private static cloneBook(book: JournalBook): JournalBook { return { id: book.id, title: book.title, observationIds: (book.observationIds || []).slice(), templateId: book.templateId, pages: (book.pages || []).map((page: JournalPage) => JournalService.clonePage(page)), status: book.status, createdAt: book.createdAt, updatedAt: book.updatedAt, coverImageUri: book.coverImageUri, editorVersion: book.editorVersion }; }
  private static clonePage(page: JournalPage): JournalPage { return { id: page.id, elements: (page.elements || []).map((item: JournalElement) => JournalService.cloneElement(item)), backgroundColor: page.backgroundColor, updatedAt: page.updatedAt }; }
  private static cloneElement(item: JournalElement): JournalElement { return { id: item.id, type: item.type, x: item.x, y: item.y, width: item.width, height: item.height, rotation: item.rotation, scale: item.scale, zIndex: item.zIndex, locked: item.locked, visible: item.visible, name: item.name, role: item.role, content: item.content, style: item.style ? JournalService.copyStyle(item.style) : undefined }; }
  private static copyStyle(source?: JournalElementStyle): JournalElementStyle {
    if (!source) return {};
    return { fontSize: source.fontSize, fontFamily: source.fontFamily, color: source.color, backgroundColor: source.backgroundColor, strokeColor: source.strokeColor, strokeWidth: source.strokeWidth, opacity: source.opacity, fontWeight: source.fontWeight, fontStyle: source.fontStyle, textAlign: source.textAlign, lineHeight: source.lineHeight, borderRadius: source.borderRadius, imageFit: source.imageFit };
  }
  private static mergeStyle(current: JournalElementStyle | undefined, update: JournalElementStyle): JournalElementStyle {
    const result = JournalService.copyStyle(current);
    if (update.fontSize !== undefined) result.fontSize = update.fontSize;
    if (update.fontFamily !== undefined) result.fontFamily = update.fontFamily;
    if (update.color !== undefined) result.color = update.color;
    if (update.backgroundColor !== undefined) result.backgroundColor = update.backgroundColor;
    if (update.strokeColor !== undefined) result.strokeColor = update.strokeColor;
    if (update.strokeWidth !== undefined) result.strokeWidth = update.strokeWidth;
    if (update.opacity !== undefined) result.opacity = update.opacity;
    if (update.fontWeight !== undefined) result.fontWeight = update.fontWeight;
    if (update.fontStyle !== undefined) result.fontStyle = update.fontStyle;
    if (update.textAlign !== undefined) result.textAlign = update.textAlign;
    if (update.lineHeight !== undefined) result.lineHeight = update.lineHeight;
    if (update.borderRadius !== undefined) result.borderRadius = update.borderRadius;
    if (update.imageFit !== undefined) result.imageFit = update.imageFit;
    return result;
  }
  private static clamp(value: number, min: number, max: number): number { return Math.max(min, Math.min(max, value)); }
}
