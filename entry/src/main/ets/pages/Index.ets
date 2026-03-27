/**
 * Index - 首页/欢迎页面
 * 提供新建数据库、打开数据库入口
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import FileTransferService from '../services/FileTransferService';
import PreferencesService, { RecentDatabase } from '../services/PreferencesService';
import { COLORS } from '../utils/Constants';

const DOMAIN = 0xFF00;

@Entry
@Component
struct Index {
  @State private recentDatabases: RecentDatabase[] = [];
  @State private isCreating: boolean = false;
  @State private isOpening: boolean = false;
  @State private showCreateDialog: boolean = false;
  @State private newDbName: string = '';

  aboutToAppear() {
    // 加载最近使用的数据库
    this.loadRecentDatabases();
  }

  /**
   * 加载最近数据库列表
   */
  async loadRecentDatabases() {
    try {
      this.recentDatabases = await PreferencesService.getRecentDatabases();
      hilog.info(DOMAIN, 'Index', 'Loaded %{public}d recent databases', this.recentDatabases.length);
    } catch (error) {
      hilog.error(DOMAIN, 'Index', 'Failed to load recent databases: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 打开文件选择器并选择数据库
   */
  async openFilePicker() {
    this.isOpening = true;

    try {
      hilog.info(DOMAIN, 'Index', 'Opening file picker...');

      const result = await FileTransferService.selectAndCopyToSandbox();

      if (result.success && result.path) {
        // 添加到最近使用列表
        const fileName = result.path.split('/').pop() || 'database';
        const recentDb = new RecentDatabase();
        recentDb.id = `${Date.now()}_${result.path}`;
        recentDb.name = fileName.replace(/\.(db|sqlite|sqlite3)$/i, '');
        recentDb.sandboxPath = result.path;
        recentDb.originalPath = '';
        recentDb.size = 0;
        recentDb.lastOpenedAt = Date.now();
        recentDb.createdAt = Date.now();

        await PreferencesService.addRecentDatabase(recentDb);

        // 跳转到数据库浏览页面
        router.pushUrl({
          url: 'pages/TableBrowserPage',
          params: { dbPath: result.path }
        });
      } else if (result.error && result.error !== '用户取消了文件选择') {
        hilog.error(DOMAIN, 'Index', 'Open failed: %{public}s', result.error);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'Index', 'Failed to open file picker: %{public}s',
        JSON.stringify(error));
    } finally {
      this.isOpening = false;
    }
  }

  /**
   * 创建新数据库
   */
  async createDatabase() {
    if (!this.newDbName.trim()) {
      hilog.info(DOMAIN, 'Index', 'Please enter database name');
      return;
    }

    this.isCreating = true;
    this.showCreateDialog = false;

    try {
      hilog.info(DOMAIN, 'Index', 'Creating database: %{public}s', this.newDbName);

      // 获取沙箱路径
      const sandboxDir = FileTransferService.getSandboxDatabasePath();
      const dbPath = `${sandboxDir}/${this.newDbName}.db`;

      // 跳转到浏览页面（新数据库会显示为空）
      router.pushUrl({
        url: 'pages/TableBrowserPage',
        params: { dbPath: dbPath }
      });

      this.newDbName = '';
    } catch (error) {
      hilog.error(DOMAIN, 'Index', 'Failed to create database: %{public}s',
        JSON.stringify(error));
    } finally {
      this.isCreating = false;
    }
  }

  /**
   * 打开最近的数据库
   */
  async openRecentDatabase(db: RecentDatabase) {
    hilog.info(DOMAIN, 'Index', 'Opening recent database: %{public}s', db.sandboxPath);

    router.pushUrl({
      url: 'pages/TableBrowserPage',
      params: { dbPath: db.sandboxPath }
    });
  }

  /**
   * 格式化日期
   */
  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    if (diff < 60000) { // 1分钟内
      return '刚刚';
    } else if (diff < 3600000) { // 1小时内
      return `${Math.floor(diff / 60000)} 分钟前`;
    } else if (diff < 86400000) { // 1天内
      return `${Math.floor(diff / 3600000)} 小时前`;
    } else if (diff < 604800000) { // 7天内
      return `${Math.floor(diff / 86400000)} 天前`;
    } else {
      return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
    }
  }

  build() {
    Stack() {
      // 主内容
      Column() {
        // 顶部区域
        Column() {
          // 应用标题
          Text('PanoDB')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLORS.TEXT_PRIMARY)

          Text('HarmonyOS PC 数据库管理工具')
            .fontSize(14)
            .fontColor(COLORS.TEXT_MUTED)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ top: 60, bottom: 40 })
        .alignItems(HorizontalAlign.Center)

        // 操作按钮区
        Row() {
          // 新建数据库按钮
          Button('新建数据库')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(COLORS.COLOR_PRIMARY)
            .borderRadius(8)
            .width(180)
            .height(48)
            .onClick(() => this.showCreateDialog = true)

          // 打开数据库按钮
          Button(this.isOpening ? '加载中...' : '打开数据库')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.TEXT_PRIMARY)
            .backgroundColor('transparent')
            .borderRadius(8)
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .width(180)
            .height(48)
            .enabled(!this.isOpening)
            .onClick(() => this.openFilePicker())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 40 })
        .alignItems(VerticalAlign.Center)

        // 最近使用区域
        if (this.recentDatabases.length > 0) {
          Column() {
            Row() {
              Text('最近使用')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLORS.TEXT_SECONDARY)

              Blank()

              Button('清除')
                .fontSize(12)
                .fontColor(COLORS.TEXT_MUTED)
                .backgroundColor('transparent')
                .onClick(() => {
                  PreferencesService.clearRecentDatabases();
                  this.recentDatabases = [];
                })
            }
            .width('90%')
            .padding({ bottom: 12 })

            List() {
              ForEach(this.recentDatabases, (db: RecentDatabase) => {
                ListItem() {
                  this.buildRecentItem(db)
                }
              })
            }
            .width('90%')
            .backgroundColor(COLORS.BG_ELEVATED)
            .borderRadius(8)
            .padding({ top: 8, bottom: 8 })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }

        Blank()

        // 底部版本信息
        Text('v1.0.0')
          .fontSize(12)
          .fontColor(COLORS.TEXT_MUTED)
          .padding({ bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLORS.BG_DEEP)

      // 创建数据库对话框
      if (this.showCreateDialog) {
        this.buildCreateDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildRecentItem(db: RecentDatabase) {
    Row() {
      // 数据库图标
      Text('DB')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.NODE_TABLE)
        .width(24)
        .height(24)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLORS.BG_BASE)
        .borderRadius(4)
        .margin({ right: 12 })

      // 数据库信息
      Column() {
        Text(db.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLORS.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatDate(db.lastOpenedAt))
          .fontSize(11)
          .fontColor(COLORS.TEXT_MUTED)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .flexGrow(1)

      // 打开按钮
      Button('打开')
        .fontSize(12)
        .fontColor(COLORS.COLOR_PRIMARY)
        .backgroundColor('transparent')
        .onClick(() => this.openRecentDatabase(db))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .borderRadius(4)
    .onClick(() => this.openRecentDatabase(db))
  }

  @Builder
  buildCreateDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => this.showCreateDialog = false)

      // 对话框内容
      Column() {
        Text('新建数据库')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ bottom: 20 })

        TextInput({
          placeholder: '输入数据库名称',
          text: this.newDbName
        })
          .fontSize(14)
          .fontColor(COLORS.TEXT_PRIMARY)
          .placeholderColor(COLORS.TEXT_MUTED)
          .backgroundColor(COLORS.BG_BASE)
          .borderRadius(6)
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .padding(12)
          .width('100%')
          .onChange((value: string) => {
            this.newDbName = value;
          })

        Row() {
          Button('取消')
            .fontSize(14)
            .fontColor(COLORS.TEXT_SECONDARY)
            .backgroundColor('transparent')
            .borderRadius(6)
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .width(100)
            .height(40)
            .onClick(() => {
              this.showCreateDialog = false;
              this.newDbName = '';
            })

          Button('创建')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(COLORS.COLOR_PRIMARY)
            .borderRadius(6)
            .width(100)
            .height(40)
            .margin({ left: 12 })
            .onClick(() => this.createDatabase())
        }
        .margin({ top: 24 })
        .justifyContent(FlexAlign.Center)
      }
      .width(320)
      .padding(24)
      .backgroundColor(COLORS.BG_ELEVATED)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
