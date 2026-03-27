/**
 * EntryAbility - 应用入口Ability
 * 管理应用生命周期和窗口配置
 * PanoDB Project
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import FileTransferService from '../services/FileTransferService';
import PreferencesService from '../services/PreferencesService';
import { AppConfig } from '../utils/Constants';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageCreate');

    // 配置窗口
    this.configureWindow(windowStage);

    // 初始化服务
    this.initServices();

    // 加载首页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading the content.');
    });
  }

  /**
   * 配置窗口属性
   */
  private async configureWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      // 获取窗口
      const windowClass = windowStage.getMainWindowSync();

      // 设置窗口大小
      const windowSize = await PreferencesService.getWindowSize();
      windowClass.setWindowLayoutFullScreen(false);
      windowClass.resetSize(windowSize.width, windowSize.height);

      // 设置最小窗口大小（如果支持）
      // 注意：OpenHarmony PC版本可能支持设置最小窗口大小

      hilog.info(DOMAIN, 'EntryAbility', 'Window configured: %{public}d x %{public}d',
        windowSize.width, windowSize.height);
    } catch (error) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to configure window: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 初始化应用服务
   */
  private async initServices(): Promise<void> {
    try {
      // 初始化FileTransferService
      await FileTransferService.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', 'FileTransferService initialized');

      // 初始化PreferencesService
      await PreferencesService.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', 'PreferencesService initialized');
    } catch (error) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to init services: %{public}s',
        JSON.stringify(error));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageDestroy');

    // 保存窗口大小
    this.saveWindowSize();
  }

  /**
   * 保存窗口大小
   */
  private async saveWindowSize(): Promise<void> {
    try {
      // 注意：这里可能需要通过WindowStage获取当前窗口大小
      // 简化实现
      hilog.info(DOMAIN, 'EntryAbility', 'Saving window size');
    } catch (error) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to save window size: %{public}s',
        JSON.stringify(error));
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onBackground');
  }
}
