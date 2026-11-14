import { BusinessError } from '@kit.BasicServicesKit';
import { ImageSourceType, LatLng, MapComponent, MapController, Marker } from '@tencentmap/map';
import { Observation, PlaceObservationStat } from '../../models/BirdModels';
import { MapService } from '../../services/MapService';
import { ObservationService } from '../../services/ObservationService';
import { SafeLogger } from '../../services/SafeLogger';
import { PageHeaderView } from './PageHeaderView';
import { AppColors, AppFontSize, AppRadius, AppSpacing } from '../../theme/AppTheme';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';
const GREEN_SOFT = '#EBF3EE';

@Component
export struct MapView {
  @Prop records: Observation[];
  @Prop privacyLoaded: boolean;
  @Prop privacyAgreed: boolean;
  @State authFailed: boolean = false;
  @State mapReady: boolean = false;
  @State errorMessage: string = '';
  @State selectedPlaceName: string = '';
  @State selectedPlaceCount: number = 0;
  @State selectedSpeciesSummary: string = '';
  @State selectedLatest: string = '';
  @BuilderParam birdName: (id: string) => string;
  @BuilderParam onBack: () => void;
  @BuilderParam onRequestPrivacy: () => void;
  @BuilderParam onOpenObservations: (placeName: string) => void;
  @BuilderParam onNewObservation: () => void;
  @BuilderParam onNotice: (message: string) => void;
  private controller?: MapController;
  private markers: Marker[] = [];
  private markerPlaceNames: string[] = [];

  private places(): PlaceObservationStat[] { return ObservationService.placeStats(this.records); }
  private validPlaces(): PlaceObservationStat[] { return ObservationService.validPlaces(this.records); }
  private placePrivacy(placeName: string): string {
    const records = this.records.filter((item: Observation) => item.placeName === placeName);
    if (records.length === 0 || records.findIndex((item: Observation) => item.latitude !== 0 || item.longitude !== 0) < 0) return '无坐标';
    if (records.findIndex((item: Observation) => item.fuzzyLocation) >= 0) return '模糊位置';
    return '精确位置 · 仅自己可见';
  }
  private callbackError(error: Object): string { if (!error) return ''; const businessError = error as BusinessError; const code = businessError.code !== undefined ? businessError.code.toString() : 'unknown'; return 'code=' + code + ', message=' + (businessError.message ? businessError.message : 'unknown error'); }
  private onReady(error: Object, controller: MapController): void { if (error) { const detail = this.callbackError(error); SafeLogger.error('BirdfolioMap', 'map_ready_failed'); this.authFailed = true; this.mapReady = false; this.errorMessage = '腾讯地图初始化失败：' + detail; return; } this.mapReady = true; this.errorMessage = ''; this.controller = controller; this.refreshMarkers(); }
  private onAuth(error: Object, success: boolean): void { const detail = this.callbackError(error); this.authFailed = !!error || !success; if (this.authFailed) { this.mapReady = false; this.errorMessage = '腾讯地图鉴权失败：' + (detail.length > 0 ? detail : '服务器未返回错误详情'); } }
  private refreshMarkers(): void { if (!this.controller) return; const places = this.validPlaces(); if (this.markers.length > 0) this.controller.removeMarkers(this.markers); this.markers = []; this.markerPlaceNames = []; places.forEach((item: PlaceObservationStat) => { const marker = new Marker({ position: new LatLng(item.latitude, item.longitude), icon: { uri: 'tencentmap_locator.png', type: ImageSourceType.RawFile }, width: 42, height: 52, anchorX: 0.5, anchorY: 1, clickable: true, zIndex: 10 }); marker.setOnClickListener((): void => { this.focusPlace(item); }); if (this.controller!.addMarker(marker)) { this.markers.push(marker); this.markerPlaceNames.push(item.placeName); } }); if (places.length > 0) this.controller.moveCamera(places.map((item: PlaceObservationStat): LatLng => new LatLng(item.latitude, item.longitude)), 60, false); }
  private focusPlace(item: PlaceObservationStat): void { this.selectedPlaceName = item.placeName; this.selectedPlaceCount = item.recordCount; const placeRecords = this.records.filter((record: Observation) => record.placeName === item.placeName); const names: string[] = []; placeRecords.forEach((record: Observation) => { const name = this.birdName(record.speciesId); if (names.indexOf(name) < 0) names.push(name); }); this.selectedSpeciesSummary = names.slice(0, 3).join('、') + (names.length > 3 ? ' 等 ' + names.length + ' 种' : ''); placeRecords.sort((a: Observation, b: Observation) => b.observedAt.localeCompare(a.observedAt)); this.selectedLatest = placeRecords.length > 0 ? '最近记录 ' + placeRecords[0].observedAt : ''; if (!this.controller || !this.mapReady) { this.onNotice(item.placeName + ' · ' + item.recordCount.toString() + ' 次观察'); return; } this.controller.setCenter(item.latitude, item.longitude, true); this.controller.setScaleLevel(16, true); this.markers.forEach((marker: Marker, index: number) => { const selected = this.markerPlaceNames[index] === item.placeName; marker.options.scaleX = selected ? 1.45 : 1; marker.options.scaleY = selected ? 1.45 : 1; marker.options.zIndex = selected ? 30 : 10; this.controller!.updateMarker(marker); }); }

  build() {
    Column() {
      PageHeaderView({ title: '地图足迹', onBack: () => this.onBack() })
      if (this.places().length === 0) {
        Column({ space: 12 }) { Text('还没有观察地点').fontFamily('serif').fontSize(22).fontColor(INK); Text('完成一次观察记录后，地点会显示在这里。').fontSize(14).fontColor(MUTED); Button('＋ 新建观察').height(46).backgroundColor(GREEN).borderRadius(8).onClick(() => this.onNewObservation()) }.justifyContent(FlexAlign.Center).layoutWeight(1).width('100%')
      } else {
        Stack({ alignContent: Alignment.BottomStart }) {
          if (MapService.isConfigured() && this.privacyLoaded && this.privacyAgreed && !this.authFailed) { MapComponent({ onReady: (error: Object, controller: MapController) => this.onReady(error, controller), onAuthCallback: (error: Object, success: boolean) => this.onAuth(error, success) }).width('100%').height('100%') }
          else { Image($r('app.media.editor_map')).width('100%').height('100%').objectFit(ImageFit.Cover); if (!this.privacyLoaded) { Text('正在读取地图设置…').fontSize(12).fontColor(INK).padding(10).backgroundColor('#EEFFFFFF').borderRadius(8).position({ x: 12, y: 12 }).zIndex(10) } else if (!this.privacyAgreed) { Button('启用腾讯在线地图').height(40).fontColor(WHITE).backgroundColor(GREEN).borderRadius(8).position({ x: 12, y: 12 }).zIndex(10).onClick(() => this.onRequestPrivacy()) } else { Text(!MapService.isConfigured() ? '未配置腾讯地图 Key，当前为静态地图' : this.errorMessage).fontSize(12).fontColor(INK).padding(10).backgroundColor('#EEFFFFFF').borderRadius(8).position({ x: 12, y: 12 }).zIndex(10) } }
          if (MapService.isConfigured() && this.privacyAgreed && !this.authFailed && !this.mapReady) { Text('腾讯地图加载中…').fontSize(12).fontColor(INK).padding(10).backgroundColor('#EEFFFFFF').borderRadius(8).position({ x: 12, y: 12 }).zIndex(10) }
          if (this.selectedPlaceName.length > 0) { Row({ space: 9 }) { Text('●').fontSize(18).fontColor(GREEN); Column({ space: 2 }) { Text(this.selectedPlaceName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(this.selectedPlaceCount.toString() + ' 次观察 · ' + this.selectedSpeciesSummary).fontSize(11).fontColor(MUTED).maxLines(1); Text(this.placePrivacy(this.selectedPlaceName) + (this.selectedLatest.length > 0 ? ' · ' + this.selectedLatest : '')).fontSize(10).fontColor(this.placePrivacy(this.selectedPlaceName) === '模糊位置' ? AppColors.warning : MUTED).maxLines(1) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('查看记录 ›').fontSize(11).fontColor(GREEN) }.padding({ left: 12, right: 14, top: 9, bottom: 9 }).backgroundColor('#F5FFFFFF').borderRadius(8).shadow({ radius: 8, color: '#22000000', offsetY: 3 }).position({ x: 12, y: 12 }).zIndex(12).onClick(() => this.onOpenObservations(this.selectedPlaceName)) }
          if (!this.mapReady || this.authFailed) { ForEach(this.validPlaces(), (item: PlaceObservationStat, index: number) => { Text(item.recordCount.toString()).fontSize(12).fontWeight(FontWeight.Bold).fontColor(WHITE).width(38).height(38).textAlign(TextAlign.Center).backgroundColor(GREEN).borderRadius(19).position({ x: 30 + (index * 67) % 250, y: 70 + (index * 83) % 210 }).onClick(() => this.focusPlace(item)) }, (item: PlaceObservationStat) => item.placeName) }
          if (this.validPlaces().length === 0) { Text('暂无有效坐标，以下显示地点列表').fontSize(12).fontColor(INK).padding(10).margin(12).backgroundColor('#EEFFFFFF').borderRadius(8) }
          Column({ space: 10 }) {
            if (this.authFailed || (this.privacyAgreed && !this.mapReady && this.errorMessage.length > 0)) {
              Row({ space: AppSpacing.xs }) {
                Text('!').fontWeight(FontWeight.Bold).fontColor(AppColors.error)
                Text('地图加载失败，仍可从地点列表查看观察。').fontSize(AppFontSize.caption).fontColor(AppColors.error).layoutWeight(1)
                Text('全部记录 ›').fontSize(AppFontSize.caption).fontColor(AppColors.primary).onClick(() => this.onOpenObservations(''))
              }.padding(AppSpacing.sm).backgroundColor(AppColors.errorSoft).borderRadius(AppRadius.card)
            }
            Row() {
              Text(this.places().length.toString() + ' 处观察地点').fontFamily('serif').fontSize(18).fontColor(INK).layoutWeight(1)
              Text('全部记录  ›').fontSize(12).fontColor(GREEN).onClick(() => this.onOpenObservations(''))
            }
            ForEach(this.places().slice(0, 4), (item: PlaceObservationStat) => {
              Row() {
                Column({ space: 3 }) {
                  Text(item.placeName).fontSize(15).fontWeight(this.selectedPlaceName === item.placeName ? FontWeight.Medium : FontWeight.Regular).fontColor(this.selectedPlaceName === item.placeName ? GREEN : INK).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.recordCount.toString() + ' 次观察 · ' + item.birdCount.toString() + ' 只 · ' + this.placePrivacy(item.placeName)).fontSize(12).fontColor(this.placePrivacy(item.placeName) === '模糊位置' ? AppColors.warning : MUTED).maxLines(1)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.selectedPlaceName === item.placeName ? '已选择' : '›').fontSize(this.selectedPlaceName === item.placeName ? 11 : 20).fontColor(GREEN)
              }.padding(11).backgroundColor(this.selectedPlaceName === item.placeName ? GREEN_SOFT : WHITE).border({ width: 1, color: this.selectedPlaceName === item.placeName ? GREEN : BORDER }).borderRadius(8).onClick(() => this.focusPlace(item))
            }, (item: PlaceObservationStat) => item.placeName)
          }.padding(16).width('100%').backgroundColor(WHITE).borderRadius({ topLeft: 16, topRight: 16 })
        }.layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
