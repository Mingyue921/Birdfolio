import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';

export class JournalWebBridge {
  private saveHandler: (payload: string, pageIndex: number, revision: number, requestId: string) => void;
  private closeHandler: (requestId: string) => void;
  private deleteHandler: (id: string) => void;
  private pickImageHandler: () => Promise<string>;
  private readImageHandler: (uri: string) => Promise<string>;
  private exportChunkHandler: (exportId: string, chunk: string, reset: boolean) => void;
  private finishExportHandler: (exportId: string, title: string, page: number, requestId: string) => void;
  private eventHandler: (message: string) => void;

  constructor(
    saveHandler: (payload: string, pageIndex: number, revision: number, requestId: string) => void,
    closeHandler: (requestId: string) => void,
    deleteHandler: (id: string) => void,
    pickImageHandler: () => Promise<string>,
    readImageHandler: (uri: string) => Promise<string>,
    exportChunkHandler: (exportId: string, chunk: string, reset: boolean) => void,
    finishExportHandler: (exportId: string, title: string, page: number, requestId: string) => void,
    eventHandler: (message: string) => void
  ) {
    this.saveHandler = saveHandler;
    this.closeHandler = closeHandler;
    this.deleteHandler = deleteHandler;
    this.pickImageHandler = pickImageHandler;
    this.readImageHandler = readImageHandler;
    this.exportChunkHandler = exportChunkHandler;
    this.finishExportHandler = finishExportHandler;
    this.eventHandler = eventHandler;
  }

  saveBook(payload: string, pageIndex: number, revision: number, requestId: string): void { this.saveHandler(payload, pageIndex, revision, requestId); }
  requestCloseEditor(requestId: string): void { this.closeHandler(requestId); }
  deleteBook(id: string): void { this.deleteHandler(id); }
  async pickImage(): Promise<string> { return this.pickImageHandler(); }
  async readImage(uri: string): Promise<string> { return this.readImageHandler(uri); }
  exportImageChunk(exportId: string, chunk: string, reset: boolean): void { this.exportChunkHandler(exportId, chunk, reset); }
  finishExportImage(exportId: string, title: string, page: number, requestId: string): void { this.finishExportHandler(exportId, title, page, requestId); }
  reportEditorEvent(message: string): void { this.eventHandler(message); }
}

@Component
export struct JournalEditorWebView {
  controller: webview.WebviewController = new webview.WebviewController();
  bridge: JournalWebBridge = new JournalWebBridge(
    (_payload: string, _pageIndex: number, _revision: number, _requestId: string) => {},
    (_requestId: string) => {},
    (_id: string) => {},
    async () => '',
    async (_uri: string) => '',
    (_exportId: string, _chunk: string, _reset: boolean) => {},
    (_exportId: string, _title: string, _page: number, _requestId: string) => {},
    (_message: string) => {}
  );
  @Link needsProxyReload: boolean;
  @BuilderParam onSelectFile: (result: FileSelectorResult) => void;
  @BuilderParam onReady: () => void;
  @BuilderParam onError: (error: BusinessError) => void;

  build() {
    Web({ src: $rawfile('journal_editor/index.html'), controller: this.controller })
      .width('100%')
      .height('100%')
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .onShowFileSelector((event) => { this.onSelectFile(event.result); return true; })
      .onControllerAttached(() => {
        try { this.controller.deleteJavaScriptRegister('BirdfolioNative'); } catch (_error) {}
        try {
          this.controller.registerJavaScriptProxy(
            this.bridge,
            'BirdfolioNative',
            ['requestCloseEditor', 'deleteBook', 'saveBook', 'exportImageChunk', 'finishExportImage', 'reportEditorEvent'],
            ['pickImage', 'readImage']
          );
          this.needsProxyReload = true;
        } catch (error) {
          this.onError(error as BusinessError);
        }
      })
      .onPageEnd((event) => {
        if (event.url.indexOf('journal_editor/index.html') < 0) return;
        if (this.needsProxyReload) { this.needsProxyReload = false; this.controller.refresh(); }
        else this.onReady();
      })
  }
}
