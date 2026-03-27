/**
 * PreferencesService - 用户偏好服务
 * 使用Preferences API存储用户偏好和最近使用的数据库
 * PanoDB Project
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF05;
const PREFERENCES_NAME = 'panodb_prefs';

export class RecentDatabase {
  id: string = '';
  name: string = '';
  sandboxPath: string = '';
  originalPath: string = '';
  size: number = 0;
  lastOpenedAt: number = 0;
  createdAt: number = 0;
}

class AppPreferences {
  editorFontSize: number = 14;
  windowWidth: number = 1200;
  windowHeight: number = 800;
  lastOpenedDb: string = '';
}

class WindowSize {
  width: number = 1200;
  height: number = 800;
}

class PreferencesService {
  private context: common.UIAbilityContext | null = null;
  private prefs: preferences.Preferences | null = null;
  private recentDatabases: RecentDatabase[] = [];

  /**
   * 初始化服务
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, PREFERENCES_NAME);
      hilog.info(DOMAIN, 'PreferencesService', 'Preferences initialized');

      // 加载最近数据库列表
      await this.loadRecentDatabases();
    } catch (error) {
      hilog.error(DOMAIN, 'PreferencesService', 'Failed to init preferences: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 确保prefs已初始化
   */
  private async ensureInitialized(): Promise<void> {
    if (!this.prefs && this.context) {
      await this.init(this.context);
    }
  }

  /**
   * 加载最近数据库列表
   */
  private async loadRecentDatabases(): Promise<void> {
    await this.ensureInitialized();
    if (!this.prefs) return;

    try {
      const json = await this.prefs.get('recent_databases', '[]');
      this.recentDatabases = JSON.parse(json as string) as RecentDatabase[];
      hilog.info(DOMAIN, 'PreferencesService', 'Loaded %{public}d recent databases',
        this.recentDatabases.length);
    } catch (error) {
      hilog.error(DOMAIN, 'PreferencesService', 'Failed to load recent databases: %{public}s',
        JSON.stringify(error));
      this.recentDatabases = [];
    }
  }

  /**
   * 保存最近数据库列表
   */
  private async saveRecentDatabases(): Promise<void> {
    await this.ensureInitialized();
    if (!this.prefs) return;

    try {
      await this.prefs.put('recent_databases', JSON.stringify(this.recentDatabases));
      await this.prefs.flush();
      hilog.info(DOMAIN, 'PreferencesService', 'Saved %{public}d recent databases',
        this.recentDatabases.length);
    } catch (error) {
      hilog.error(DOMAIN, 'PreferencesService', 'Failed to save recent databases: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 获取最近使用的数据库列表
   */
  async getRecentDatabases(): Promise<RecentDatabase[]> {
    await this.loadRecentDatabases();
    return this.recentDatabases;
  }

  /**
   * 添加到最近使用列表
   */
  async addRecentDatabase(db: RecentDatabase): Promise<void> {
    await this.loadRecentDatabases();

    // 移除已存在的同名记录
    const filtered: RecentDatabase[] = [];
    for (let i = 0; i < this.recentDatabases.length; i++) {
      if (this.recentDatabases[i].sandboxPath !== db.sandboxPath) {
        filtered.push(this.recentDatabases[i]);
      }
    }
    this.recentDatabases = filtered;

    // 添加到列表头部
    const newDb = new RecentDatabase();
    newDb.id = db.id;
    newDb.name = db.name;
    newDb.sandboxPath = db.sandboxPath;
    newDb.originalPath = db.originalPath;
    newDb.size = db.size;
    newDb.lastOpenedAt = Date.now();
    newDb.createdAt = db.createdAt;
    this.recentDatabases.unshift(newDb);

    // 只保留最近10条
    if (this.recentDatabases.length > 10) {
      this.recentDatabases = this.recentDatabases.slice(0, 10);
    }

    await this.saveRecentDatabases();
  }

  /**
   * 从最近列表中移除
   */
  async removeRecentDatabase(sandboxPath: string): Promise<void> {
    await this.loadRecentDatabases();

    const filtered: RecentDatabase[] = [];
    for (let i = 0; i < this.recentDatabases.length; i++) {
      if (this.recentDatabases[i].sandboxPath !== sandboxPath) {
        filtered.push(this.recentDatabases[i]);
      }
    }
    this.recentDatabases = filtered;
    await this.saveRecentDatabases();
  }

  /**
   * 清除最近使用列表
   */
  async clearRecentDatabases(): Promise<void> {
    this.recentDatabases = [];
    await this.ensureInitialized();
    if (this.prefs) {
      try {
        await this.prefs.delete('recent_databases');
        await this.prefs.flush();
        hilog.info(DOMAIN, 'PreferencesService', 'Recent databases cleared');
      } catch (error) {
        hilog.error(DOMAIN, 'PreferencesService', 'Failed to clear recent databases: %{public}s',
          JSON.stringify(error));
      }
    }
  }

  /**
   * 获取用户偏好设置
   */
  async getPreference(key: string, defaultValue: string | number): Promise<string | number> {
    await this.ensureInitialized();
    if (!this.prefs) {
      return defaultValue;
    }

    try {
      const value = await this.prefs.get(key, defaultValue);
      return value as string | number;
    } catch (error) {
      hilog.error(DOMAIN, 'PreferencesService', 'Failed to get preference %{public}s: %{public}s',
        key, JSON.stringify(error));
      return defaultValue;
    }
  }

  /**
   * 设置用户偏好
   */
  async setPreference(key: string, value: string | number): Promise<void> {
    await this.ensureInitialized();
    if (!this.prefs) return;

    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
      hilog.info(DOMAIN, 'PreferencesService', 'Preference %{public}s set to %{public}s',
        key, String(value));
    } catch (error) {
      hilog.error(DOMAIN, 'PreferencesService', 'Failed to set preference %{public}s: %{public}s',
        key, JSON.stringify(error));
    }
  }

  /**
   * 获取编辑器字体大小
   */
  async getEditorFontSize(): Promise<number> {
    const size = await this.getPreference('editorFontSize', 14);
    return typeof size === 'number' ? size : 14;
  }

  /**
   * 设置编辑器字体大小
   */
  async setEditorFontSize(size: number): Promise<void> {
    await this.setPreference('editorFontSize', size);
  }

  /**
   * 获取窗口大小
   */
  async getWindowSize(): Promise<WindowSize> {
    const width = await this.getPreference('windowWidth', 1200);
    const height = await this.getPreference('windowHeight', 800);
    const result = new WindowSize();
    result.width = typeof width === 'number' ? width : 1200;
    result.height = typeof height === 'number' ? height : 800;
    return result;
  }

  /**
   * 保存窗口大小
   */
  async setWindowSize(width: number, height: number): Promise<void> {
    await this.setPreference('windowWidth', width);
    await this.setPreference('windowHeight', height);
  }
}

export default new PreferencesService();
