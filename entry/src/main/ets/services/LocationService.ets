import { common } from '@kit.AbilityKit';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import geoLocationManager from '@ohos.geoLocationManager';

export interface CurrentLocationResult {
  success: boolean;
  latitude: number;
  longitude: number;
  message: string;
}

const LOCATION_PERMISSION = 'ohos.permission.APPROXIMATELY_LOCATION';

export class LocationService {
  static async getCurrentLocation(context: common.UIAbilityContext): Promise<CurrentLocationResult> {
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const permissionResult = await manager.requestPermissionsFromUser(context, [LOCATION_PERMISSION]);
      const granted = permissionResult.authResults && permissionResult.authResults.length > 0 && permissionResult.authResults[0] === 0;
      if (!granted) return LocationService.failure('未获得定位权限，仍可保存无坐标记录');
      const location = await geoLocationManager.getCurrentLocation();
      if (!LocationService.valid(location.latitude, location.longitude)) return LocationService.failure('系统返回的位置无效');
      return { success: true, latitude: location.latitude, longitude: location.longitude, message: '已获取当前位置' };
    } catch (error) {
      const code = error && (error as BusinessError).code !== undefined ? (error as BusinessError).code : 0;
      if (code === 201) return LocationService.failure('未获得定位权限，仍可保存无坐标记录');
      if (code === 3301100) return LocationService.failure('系统定位服务未开启，请在系统设置中打开');
      if (code === 3301000 || code === 801) return LocationService.failure('当前设备不支持定位，仍可保存无坐标记录');
      return LocationService.failure('获取当前位置失败，仍可保存无坐标记录');
    }
  }

  private static valid(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) && Number.isFinite(longitude) && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  private static failure(message: string): CurrentLocationResult {
    return { success: false, latitude: 0, longitude: 0, message: message };
  }
}

interface BusinessError {
  code?: number;
  message?: string;
}
