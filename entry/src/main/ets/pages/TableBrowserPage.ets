/**
 * TableBrowserPage - 表浏览页面
 * 主界面：左侧Schema树、SQL编辑器、数据表格
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import { SchemaTree } from '../components/SchemaTree';
import { SqlEditor } from '../components/SqlEditor';
import { TableView } from '../components/TableView';
import { StatusBar } from '../components/StatusBar';
import { ExportDialog } from '../components/ExportDialog';
import { TableDesigner } from '../components/TableDesigner';
import DatabaseService from '../services/DatabaseService';
import QueryService from '../services/QueryService';
import { COLORS, ConnectionState } from '../utils/Constants';
import { QueryResult, TableRow } from '../models/QueryResult';

const DOMAIN = 0xFF20;

class RouterParams {
  dbPath?: string = '';
}

@Entry
@Component
struct TableBrowserPage {
  @State private currentTableName: string = '';
  @State private sqlText: string = '';
  @State private queryResult: QueryResult | null = null;
  @State private queryResultRows: TableRow[] = [];
  @State private isLoading: boolean = false;
  @State private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  @State private tableCount: number = 0;
  @State private queryTime: number = 0;
  @State private rowCount: number = 0;
  @State private currentDbPath: string = '';
  @State private leftSidebarWidth: number = 240;
  @State private isLeftSidebarCollapsed: boolean = false;
  @State private refreshKey: number = 0;
  @State private showExportDialogFlag: boolean = false;
  @State private showTableDesignerFlag: boolean = false;
  @State private dataReloadKey: number = 0;
  @State private lastSelectSql: string = '';

  aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as RouterParams;
    if (params && params.dbPath) {
      this.currentDbPath = params.dbPath;
      this.openDatabase(params.dbPath);
    }
  }

  /**
   * 打开数据库
   */
  async openDatabase(path: string) {
    this.isLoading = true;
    this.connectionState = ConnectionState.CONNECTING;

    try {
      hilog.info(DOMAIN, 'TableBrowserPage', 'Opening database: %{public}s', path);

      await DatabaseService.openDatabase(path);

      this.connectionState = ConnectionState.CONNECTED;

      // 触发Schema树刷新
      this.refreshKey++;

      // 获取表数量
      const tables = await DatabaseService.getTables();
      this.tableCount = tables.filter(t => t.type === 'table').length;

      hilog.info(DOMAIN, 'TableBrowserPage', 'Database opened successfully');
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'Failed to open database: %{public}s',
        JSON.stringify(error));
      this.connectionState = ConnectionState.ERROR;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新Schema树
   */
  async refreshSchema() {
    this.refreshKey++;
    // 重新加载
    const tables = await DatabaseService.getTables();
    this.tableCount = tables.filter(t => t.type === 'table').length;
  }

  /**
   * 关闭数据库
   */
  async closeDatabase() {
    try {
      await DatabaseService.closeDatabase();
      this.connectionState = ConnectionState.DISCONNECTED;
      this.tableCount = 0;
      this.currentTableName = '';
      hilog.info(DOMAIN, 'TableBrowserPage', 'Database closed');
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'Failed to close database: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 执行SQL
   */
  async executeSql(sql: string) {
    if (!sql.trim()) {
      return;
    }

    this.isLoading = true;

    try {
      hilog.info(DOMAIN, 'TableBrowserPage', 'Executing SQL');

      const result = await QueryService.execute(sql);

      this.queryResult = result;
      this.queryResultRows = result.success ? result.rows : [];
      this.queryTime = result.executionTime;

      if (result.success) {
        this.rowCount = result.rows.length;
      } else {
        this.rowCount = 0;
      }
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'SQL execution failed: %{public}s',
        JSON.stringify(error));
      const errorResult = new QueryResult();
      errorResult.success = false;
      errorResult.columns = [];
      errorResult.rows = [];
      errorResult.affectedRows = 0;
      errorResult.executionTime = 0;
      errorResult.error = JSON.stringify(error);
      this.queryResult = errorResult;
      this.queryResultRows = [];
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载表数据
   */
  async loadTableData(tableName: string) {
    this.isLoading = true;
    this.currentTableName = tableName;
    this.lastSelectSql = `SELECT * FROM ${tableName} LIMIT 100`;

    try {
      const result = await QueryService.execute(this.lastSelectSql);
      this.queryResult = result;
      this.queryResultRows = result.rows;
      this.queryTime = result.executionTime;
      this.rowCount = result.rows.length;
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'Failed to load table data: %{public}s',
        JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新当前表数据
   */
  async refreshCurrentTableData() {
    if (!this.currentTableName) {
      return;
    }
    this.isLoading = true;
    try {
      const result = await QueryService.execute(this.lastSelectSql);
      this.queryResult = result;
      this.queryResultRows = result.rows;
      this.queryTime = result.executionTime;
      this.rowCount = result.rows.length;
      this.dataReloadKey++;
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'Failed to refresh table data: %{public}s',
        JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 执行数据编辑的SQL（由TableView调用）
   */
  async executeEditSqls(sqls: string[]) {
    if (sqls.length === 0) {
      return;
    }

    this.isLoading = true;
    try {
      // 执行所有SQL
      for (const sql of sqls) {
        hilog.info(DOMAIN, 'TableBrowserPage', 'Executing edit SQL: %{public}s', sql);
        await QueryService.execute(sql);
      }
      // 刷新数据
      await this.refreshCurrentTableData();
      hilog.info(DOMAIN, 'TableBrowserPage', 'Edit SQLs executed successfully');
    } catch (error) {
      hilog.error(DOMAIN, 'TableBrowserPage', 'Failed to execute edit SQLs: %{public}s',
        JSON.stringify(error));
      this.isLoading = false;
    }
  }

  /**
   * 切换左侧边栏
   */
  toggleLeftSidebar() {
    this.isLeftSidebarCollapsed = !this.isLeftSidebarCollapsed;
  }

  build() {
    Stack() {
      // 主内容
      Column() {
        // 标题栏
        this.buildTitleBar()

        // 主内容区
        Row() {
          // 左侧边栏 - Schema树
          if (!this.isLeftSidebarCollapsed) {
            Column() {
              SchemaTree({
                currentTableName: $currentTableName,
                onNodeClick: (node) => {
                  // 点击表节点时加载表数据
                  if (node.type === 'table') {
                    this.loadTableData(node.name);
                  }
                }
              })
            }
            .width(this.leftSidebarWidth)
            .height('100%')
            .backgroundColor(COLORS.BG_ELEVATED)
            .borderWidth({ right: 1 })
            .borderColor(COLORS.BORDER_DEFAULT)
          }

          // 折叠按钮
          Column() {
            Button()
              .width(20)
              .height(40)
              .backgroundColor(COLORS.BG_BASE)
              .borderRadius(4)
              .onClick(() => this.toggleLeftSidebar())
          }
          .width(20)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(COLORS.BG_BASE)

          // 右侧主内容区
          Column() {
            // SQL编辑器
            Column() {
              SqlEditor({
                sqlText: $sqlText,
                onExecute: (sql: string) => {
                  this.executeSql(sql);
                }
              })
            }
            .width('100%')
            .height(200)
            .borderWidth({ bottom: 1 })
            .borderColor(COLORS.BORDER_DEFAULT)

            // 结果/数据区
            Row() {
              // 数据表格
              Column() {
                TableView({
                  columns: this.queryResult?.columns || [],
                  isLoading: this.isLoading,
                  rows: $queryResultRows,
                  tableName: this.currentTableName,
                  onSaveRequestFn: (sqls: string[]) => {
                    this.executeEditSqls(sqls);
                  }
                })
              }
              .width('100%')
              .height('100%')
              .layoutWeight(1)
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .layoutWeight(1)

        // 状态栏
        StatusBar({
          connectionState: this.connectionState,
          tableCount: this.tableCount,
          queryTime: this.queryTime,
          rowCount: this.rowCount,
          currentTable: this.currentTableName
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLORS.BG_DEEP)

      // 导出对话框（作为叠加层）
      if (this.showExportDialogFlag) {
        ExportDialog({
          isVisible: $showExportDialogFlag,
          queryResult: $queryResult
        })
      }

      // 表设计器（作为叠加层）
      if (this.showTableDesignerFlag) {
        TableDesigner({
          editMode: false,
          onClose: () => {
            this.showTableDesignerFlag = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildTitleBar() {
    Row() {
      // 返回按钮
      Button()
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .borderRadius(4)
        .onClick(() => {
          this.closeDatabase();
          router.back();
        })

      Text('<')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.TEXT_PRIMARY)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.closeDatabase();
          router.back();
        })

      // 数据库名称
      Text(this.getDbName())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLORS.TEXT_PRIMARY)
        .margin({ left: 12 })

      Blank()

      // 工具按钮
      Row() {
        Button('刷新')
          .fontSize(13)
          .fontColor(COLORS.TEXT_SECONDARY)
          .backgroundColor('transparent')
          .onClick(() => this.refreshSchema())

        Button('新建表')
          .fontSize(13)
          .fontColor(COLORS.COLOR_PRIMARY)
          .backgroundColor('transparent')
          .margin({ left: 8 })
          .onClick(() => this.showTableDesigner())

        Button('导出')
          .fontSize(13)
          .fontColor(COLORS.TEXT_SECONDARY)
          .backgroundColor('transparent')
          .margin({ left: 8 })
          .onClick(() => this.showExportDialog())
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .backgroundColor(COLORS.BG_BASE)
    .borderWidth({ bottom: 1 })
    .borderColor(COLORS.BORDER_DEFAULT)
  }

  private getDbName(): string {
    if (!this.currentDbPath) {
      return '数据库';
    }
    const parts = this.currentDbPath.split('/');
    const fileName = parts[parts.length - 1];
    return fileName.replace(/\.(db|sqlite|sqlite3)$/i, '');
  }

  /**
   * 显示导出对话框
   */
  showExportDialog() {
    if (!this.queryResult || !this.queryResult.success || this.queryResult.rows.length === 0) {
      hilog.info(DOMAIN, 'TableBrowserPage', 'No data to export');
      return;
    }
    this.showExportDialogFlag = true;
  }

  /**
   * 显示表设计器
   */
  showTableDesigner() {
    this.showTableDesignerFlag = true;
  }
}