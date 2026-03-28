/**
 * ExportDialog - 导出对话框组件
 * 支持导出为JSON/CSV/SQL格式
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import QueryService from '../services/QueryService';
import { QueryResult, getCellValue } from '../models/QueryResult';
import { COLORS } from '../utils/Constants';

const DOMAIN = 0xFF14;

// 导出格式枚举
export enum ExportFormat {
  JSON = 'json',
  CSV = 'csv',
  SQL = 'sql'
}

// 保存文件结果类
class SaveFileResult {
  success: boolean = false;
  path?: string = '';
  error?: string = '';
}

@Component
export struct ExportDialog {
  @Link isVisible: boolean;
  @Link queryResult: QueryResult | null;
  @State private selectedFormat: ExportFormat = ExportFormat.JSON;
  @State private tableName: string = 'export_table';
  @State private fileName: string = 'export_data';
  @State private isExporting: boolean = false;
  @State private exportMessage: string = '';

  build() {
    if (this.isVisible) {
      Stack() {
        // 遮罩层
        Column() {
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => this.close())

        // 对话框内容
        Column() {
          this.buildDialogContent()
        }
        .width(400)
        .padding(24)
        .backgroundColor(COLORS.BG_ELEVATED)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildDialogContent() {
    Column() {
      // 标题
      Text('导出数据')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.TEXT_PRIMARY)
        .margin({ bottom: 20 })

      // 格式选择
      Text('导出格式')
        .fontSize(14)
        .fontColor(COLORS.TEXT_SECONDARY)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Row() {
        Radio({ value: 'json', group: 'format' })
          .checked(this.selectedFormat === ExportFormat.JSON)
          .radioStyle({ checkedBackgroundColor: COLORS.COLOR_PRIMARY })
          .onChange((isChecked: boolean) => {
            if (isChecked) {
              this.selectedFormat = ExportFormat.JSON;
            }
          })

        Text('JSON')
          .fontSize(13)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ left: 4, right: 16 })

        Radio({ value: 'csv', group: 'format' })
          .checked(this.selectedFormat === ExportFormat.CSV)
          .radioStyle({ checkedBackgroundColor: COLORS.COLOR_PRIMARY })
          .onChange((isChecked: boolean) => {
            if (isChecked) {
              this.selectedFormat = ExportFormat.CSV;
            }
          })

        Text('CSV')
          .fontSize(13)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ left: 4, right: 16 })

        Radio({ value: 'sql', group: 'format' })
          .checked(this.selectedFormat === ExportFormat.SQL)
          .radioStyle({ checkedBackgroundColor: COLORS.COLOR_PRIMARY })
          .onChange((isChecked: boolean) => {
            if (isChecked) {
              this.selectedFormat = ExportFormat.SQL;
            }
          })

        Text('SQL')
          .fontSize(13)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ left: 4 })
      }
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 16 })

      // SQL格式需要表名
      if (this.selectedFormat === ExportFormat.SQL) {
        Text('表名')
          .fontSize(14)
          .fontColor(COLORS.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        TextInput({ text: this.tableName, placeholder: '输入表名' })
          .fontSize(13)
          .fontColor(COLORS.TEXT_PRIMARY)
          .placeholderColor(COLORS.TEXT_MUTED)
          .backgroundColor(COLORS.BG_BASE)
          .borderRadius(6)
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .padding(10)
          .width('100%')
          .margin({ bottom: 16 })
          .onChange((value: string) => {
            this.tableName = value;
          })
      }

      // 预览信息
      if (this.queryResult && this.queryResult.success) {
        Column() {
          Text('预览')
            .fontSize(14)
            .fontColor(COLORS.TEXT_SECONDARY)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          Text(`列数: ${this.queryResult.columns.length} | 行数: ${this.queryResult.rows.length}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
            .alignSelf(ItemAlign.Start)
        }
        .width('100%')
        .margin({ bottom: 16 })
        .padding(12)
        .backgroundColor(COLORS.BG_BASE)
        .borderRadius(6)
      }

      // 导出消息
      if (this.exportMessage) {
        Text(this.exportMessage)
          .fontSize(12)
          .fontColor(this.exportMessage.includes('成功') ? COLORS.COLOR_SUCCESS : COLORS.COLOR_ERROR)
          .margin({ bottom: 12 })
      }

      // 按钮行
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
          .onClick(() => this.close())

        Button(this.isExporting ? '导出中...' : '导出')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(COLORS.COLOR_PRIMARY)
          .borderRadius(6)
          .width(100)
          .height(40)
          .margin({ left: 12 })
          .enabled(!this.isExporting && this.queryResult !== null)
          .onClick(() => this.doExport())
      }
      .margin({ top: 8 })
    }
    .width('100%')
  }

  /**
   * 执行导出
   */
  async doExport() {
    if (!this.queryResult || !this.queryResult.success) {
      this.exportMessage = '没有可导出的数据';
      return;
    }

    this.isExporting = true;
    this.exportMessage = '';

    try {
      hilog.info(DOMAIN, 'ExportDialog', 'Exporting as %{public}s', this.selectedFormat);

      // 根据格式生成内容
      let content: string;
      let fileExtension: string;

      switch (this.selectedFormat) {
        case ExportFormat.JSON:
          content = QueryService.exportAsJson(this.queryResult);
          fileExtension = 'json';
          break;
        case ExportFormat.CSV:
          content = QueryService.exportAsCsv(this.queryResult);
          fileExtension = 'csv';
          break;
        case ExportFormat.SQL:
          content = QueryService.exportAsSql(this.queryResult, this.tableName || 'export_table');
          fileExtension = 'sql';
          break;
        default:
          content = '';
          fileExtension = 'txt';
      }

      // 使用DocumentViewPicker保存文件
      const result = await this.saveFile(content, fileExtension);

      if (result.success) {
        this.exportMessage = `导出成功: ${result.path}`;
        hilog.info(DOMAIN, 'ExportDialog', 'Export succeeded: %{public}s', result.path);
      } else {
        this.exportMessage = `导出失败: ${result.error}`;
        hilog.error(DOMAIN, 'ExportDialog', 'Export failed: %{public}s', result.error);
      }
    } catch (error) {
      this.exportMessage = `导出异常: ${JSON.stringify(error)}`;
      hilog.error(DOMAIN, 'ExportDialog', 'Export error: %{public}s', JSON.stringify(error));
    } finally {
      this.isExporting = false;
    }
  }

  /**
   * 保存文件到外部存储
   */
  private async saveFile(content: string, extension: string): Promise<SaveFileResult> {
    const result = new SaveFileResult();
    try {
      // 打开保存对话框
      const documentSaver = new picker.DocumentViewPicker();
      const saveResult = await documentSaver.save();

      if (!saveResult || saveResult.length === 0) {
        result.success = false;
        result.error = '用户取消了保存';
        return result;
      }

      // 构建目标路径
      const targetPath = saveResult[0];

      // 如果路径没有正确的扩展名，添加它
      const finalPath = targetPath.endsWith(`.${extension}`) ? targetPath : `${targetPath}.${extension}`;

      // 写入文件
      const file = fileIo.openSync(finalPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);

      result.success = true;
      result.path = finalPath;
      return result;
    } catch (error) {
      result.success = false;
      result.error = JSON.stringify(error);
      return result;
    }
  }

  /**
   * 关闭对话框
   */
  close() {
    this.isVisible = false;
    this.exportMessage = '';
    this.selectedFormat = ExportFormat.JSON;
    this.tableName = 'export_table';
  }
}
