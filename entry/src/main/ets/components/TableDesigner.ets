/**
 * TableDesigner - 表设计器组件
 * 支持创建表、编辑表结构、管理索引
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ColumnEditor } from './ColumnEditor';
import { ColumnInfo, IndexInfo, TableSchema, SQLITE_TYPES } from '../models/TableSchema';
import { COLORS } from '../utils/Constants';
import QueryService from '../services/QueryService';

const DOMAIN = 0xFF15;

@Component
export struct TableDesigner {
  @Prop editMode: boolean = false; // true=编辑现有表, false=新建表
  @Prop originalTableName: string = ''; // 编辑模式下的原表名
  @State private tableName: string = '';
  @State private columns: ColumnInfo[] = [];
  @State private indexes: IndexInfo[] = [];
  @State private showIndexPanel: boolean = false;
  @State private newIndexName: string = '';
  @State private newIndexColumns: string[] = [];
  @State private newIndexUnique: boolean = false;
  @State private ddlPreview: string = '';
  @State private isExecuting: boolean = false;
  @State private message: string = '';
  @State private messageType: 'success' | 'error' = 'success';

  onClose?: () => void;
  private onSuccessCb?: () => void;

  aboutToAppear() {
    if (this.editMode && this.originalTableName) {
      this.tableName = this.originalTableName;
      // TODO: 加载现有表结构
    } else {
      this.resetForm();
    }
    this.updatePreview();
  }

  build() {
    Stack() {
      // 遮罩层
      Column() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0, 0, 0, 0.5)')
      .onClick(() => this.close())

      // 主内容
      Column() {
        this.buildContent()
      }
      .width(700)
      .height('80%')
      .padding(24)
      .backgroundColor(COLORS.BG_ELEVATED)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildContent() {
    Column() {
      // 标题栏
      Row() {
        Text(this.editMode ? '编辑表结构' : '创建新表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.TEXT_PRIMARY)

        Blank()

        Button('×')
          .fontSize(20)
          .fontColor(COLORS.TEXT_MUTED)
          .backgroundColor('transparent')
          .width(32)
          .height(32)
          .onClick(() => this.close())
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 表名输入
      Row() {
        Text('表名:')
          .fontSize(14)
          .fontColor(COLORS.TEXT_SECONDARY)
          .width(60)

        TextInput({ text: this.tableName, placeholder: '输入表名' })
          .fontSize(14)
          .fontColor(COLORS.TEXT_PRIMARY)
          .placeholderColor(COLORS.TEXT_MUTED)
          .backgroundColor(COLORS.BG_BASE)
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .borderRadius(6)
          .padding(10)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.tableName = value;
            this.updatePreview();
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 列定义区域
      Column() {
        Row() {
          Text('列定义')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.TEXT_PRIMARY)

          Blank()

          Button('+ 添加列')
            .fontSize(12)
            .fontColor(COLORS.COLOR_PRIMARY)
            .backgroundColor('transparent')
            .onClick(() => this.addColumn())
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 列列表
        Scroll() {
          Column() {
            ForEach(this.columns, (col: ColumnInfo, index: number) => {
              ColumnEditor({
                column: col,
                index: index,
                isEditMode: true,
                onDeleteFn: (idx: number) => this.removeColumn(idx),
                onColumnChangeFn: (idx: number, column: ColumnInfo) => {
                  this.updateColumn(idx, column);
                }
              })
            }, (col: ColumnInfo, index: number) => `${index}-${col.name}`)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ bottom: 16 })

      // 索引管理按钮
      Row() {
        Button(this.showIndexPanel ? '隐藏索引' : '管理索引')
          .fontSize(12)
          .fontColor(COLORS.TEXT_SECONDARY)
          .backgroundColor('transparent')
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .borderRadius(6)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.showIndexPanel = !this.showIndexPanel
          })

        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 索引面板
      if (this.showIndexPanel) {
        this.buildIndexPanel()
      }

      // DDL预览
      Column() {
        Row() {
          Text('DDL 预览')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.TEXT_PRIMARY)
        }
        .width('100%')
        .margin({ bottom: 8 })

        Scroll() {
          Text(this.ddlPreview)
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor(COLORS.COLOR_PRIMARY)
            .width('100%')
            .padding(12)
            .backgroundColor(COLORS.BG_DEEP)
            .borderRadius(6)
        }
        .width('100%')
        .height(80)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 消息
      if (this.message) {
        Text(this.message)
          .fontSize(12)
          .fontColor(this.messageType === 'success' ? COLORS.COLOR_SUCCESS : COLORS.COLOR_ERROR)
          .margin({ bottom: 12 })
      }

      // 按钮行
      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor(COLORS.TEXT_SECONDARY)
          .backgroundColor('transparent')
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .borderRadius(6)
          .width(100)
          .height(40)
          .onClick(() => this.close())

        Button(this.isExecuting ? '执行中...' : (this.editMode ? '保存' : '创建'))
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isExecuting ? COLORS.TEXT_MUTED : COLORS.COLOR_PRIMARY)
          .borderRadius(6)
          .width(100)
          .height(40)
          .margin({ left: 12 })
          .enabled(!this.isExecuting && this.tableName.length > 0 && this.columns.length > 0)
          .onClick(() => this.executeDDL())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildIndexPanel() {
    Column() {
      // 已有索引列表
      Row() {
        Text('索引列表')
          .fontSize(13)
          .fontColor(COLORS.TEXT_SECONDARY)
      }
      .width('100%')
      .margin({ bottom: 8 })

      ForEach(this.indexes, (idx: IndexInfo, index: number) => {
        Row() {
          Text(idx.name)
            .fontSize(12)
            .fontColor(COLORS.TEXT_PRIMARY)
            .layoutWeight(1)

          Text(`(${idx.columns.join(', ')})`)
            .fontSize(11)
            .fontColor(COLORS.TEXT_MUTED)

          Button('×')
            .fontSize(12)
            .fontColor(COLORS.COLOR_ERROR)
            .backgroundColor('transparent')
            .width(24)
            .height(24)
            .onClick(() => this.removeIndex(index))
        }
        .width('100%')
        .padding(8)
        .backgroundColor(COLORS.BG_BASE)
        .borderRadius(4)
        .margin({ bottom: 4 })
      }, (idx: IndexInfo, index: number) => `${index}`)

      // 新建索引
      Column() {
        Row() {
          TextInput({ text: this.newIndexName, placeholder: '索引名' })
            .fontSize(12)
            .fontColor(COLORS.TEXT_PRIMARY)
            .placeholderColor(COLORS.TEXT_MUTED)
            .backgroundColor(COLORS.BG_BASE)
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .borderRadius(4)
            .padding(6)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.newIndexName = value;
            })

          Checkbox()
            .select(this.newIndexUnique)
            .selectedColor(COLORS.COLOR_PRIMARY)
            .onChange((isSelected: boolean) => {
              this.newIndexUnique = isSelected;
            })

          Text('唯一')
            .fontSize(11)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ left: 4 })

          Button('添加')
            .fontSize(11)
            .fontColor(COLORS.COLOR_PRIMARY)
            .backgroundColor('transparent')
            .margin({ left: 8 })
            .onClick(() => this.addIndex())
        }
        .width('100%')
        .margin({ bottom: 8 })

        // 选择列
        Text('选择列 (点击添加):')
          .fontSize(11)
          .fontColor(COLORS.TEXT_MUTED)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })

        Row() {
          ForEach(this.columns, (col: ColumnInfo, index: number) => {
            if (col.name) {
              Button(col.name)
                .fontSize(10)
                .fontColor(this.newIndexColumns.includes(col.name) ? '#FFFFFF' : COLORS.COLOR_PRIMARY)
                .backgroundColor(this.newIndexColumns.includes(col.name) ? COLORS.COLOR_PRIMARY : 'transparent')
                .borderWidth(1)
                .borderColor(COLORS.COLOR_PRIMARY)
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .margin({ right: 4 })
                .onClick(() => this.toggleIndexColumn(col.name))
            }
          }, (col: ColumnInfo) => col.name)
        }
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(COLORS.BG_BASE)
      .borderRadius(8)
      .margin({ bottom: 12 })
    }
    .width('100%')
  }

  /**
   * 添加新列
   */
  private addColumn(): void {
    const newCol = new ColumnInfo();
    this.columns.push(newCol);
    this.updatePreview();
  }

  /**
   * 移除列
   */
  private removeColumn(index: number): void {
    if (index >= 0 && index < this.columns.length) {
      this.columns.splice(index, 1);
      this.updatePreview();
    }
  }

  /**
   * 更新列
   */
  private updateColumn(index: number, column: ColumnInfo): void {
    if (index >= 0 && index < this.columns.length) {
      this.columns[index] = column;
      this.updatePreview();
    }
  }

  /**
   * 添加索引
   */
  private addIndex(): void {
    if (!this.newIndexName || this.newIndexColumns.length === 0) {
      this.showMessage('请输入索引名并选择至少一列', 'error');
      return;
    }

    const idx = new IndexInfo(this.newIndexName);
    idx.columns = this.newIndexColumns.slice();
    idx.isUnique = this.newIndexUnique;
    this.indexes.push(idx);

    this.newIndexName = '';
    this.newIndexColumns = [];
    this.newIndexUnique = false;
    this.updatePreview();
  }

  /**
   * 移除索引
   */
  private removeIndex(index: number): void {
    if (index >= 0 && index < this.indexes.length) {
      this.indexes.splice(index, 1);
      this.updatePreview();
    }
  }

  /**
   * 切换索引列
   */
  private toggleIndexColumn(colName: string): void {
    const idx = this.newIndexColumns.indexOf(colName);
    if (idx >= 0) {
      this.newIndexColumns.splice(idx, 1);
    } else {
      this.newIndexColumns.push(colName);
    }
  }

  /**
   * 更新DDL预览
   */
  private updatePreview(): void {
    const schema = this.buildSchema();
    this.ddlPreview = schema.generateCreateSql();
    const indexSqls = schema.generateIndexSql();
    if (indexSqls.length > 0) {
      this.ddlPreview += ';\n\n' + indexSqls.join(';\n');
    }
  }

  /**
   * 构建表结构对象
   */
  private buildSchema(): TableSchema {
    const schema = new TableSchema();
    schema.name = this.tableName;
    schema.columns = this.columns.filter(col => col.name.length > 0);
    schema.indexes = this.indexes.filter(idx => idx.name.length > 0 && idx.columns.length > 0);
    return schema;
  }

  /**
   * 执行DDL
   */
  private async executeDDL(): Promise<void> {
    if (!this.tableName || this.columns.length === 0) {
      this.showMessage('请输入表名并添加至少一列', 'error');
      return;
    }

    this.isExecuting = true;
    this.message = '';

    try {
      hilog.info(DOMAIN, 'TableDesigner', 'Executing DDL for table: %{public}s', this.tableName);

      const schema = this.buildSchema();
      const createSql = schema.generateCreateSql();

      if (!createSql) {
        this.showMessage('无法生成有效的DDL语句', 'error');
        this.isExecuting = false;
        return;
      }

      // 执行CREATE TABLE
      const result = await QueryService.execute(createSql);

      if (!result.success) {
        this.showMessage(`创建失败: ${result.error}`, 'error');
        this.isExecuting = false;
        return;
      }

      // 执行CREATE INDEX
      const indexSqls = schema.generateIndexSql();
      for (let i = 0; i < indexSqls.length; i++) {
        const idxResult = await QueryService.execute(indexSqls[i]);
        if (!idxResult.success) {
          hilog.warn(DOMAIN, 'TableDesigner', 'Index creation warning: %{public}s', idxResult.error);
        }
      }

      this.showMessage(this.editMode ? '表结构已更新' : '表创建成功', 'success');
      hilog.info(DOMAIN, 'TableDesigner', 'Table created successfully');

      // 延迟关闭
      setTimeout(() => {
        if (this.onSuccessCb) {
          this.onSuccessCb();
        }
        this.close();
      }, 1000);

    } catch (error) {
      this.showMessage(`执行异常: ${JSON.stringify(error)}`, 'error');
      hilog.error(DOMAIN, 'TableDesigner', 'DDL execution error: %{public}s', JSON.stringify(error));
    } finally {
      this.isExecuting = false;
    }
  }

  /**
   * 显示消息
   */
  private showMessage(msg: string, type: 'success' | 'error'): void {
    this.message = msg;
    this.messageType = type;
    // 3秒后清除消息
    setTimeout(() => {
      this.message = '';
    }, 3000);
  }

  /**
   * 重置表单
   */
  private resetForm(): void {
    this.tableName = '';
    this.columns = [];
    this.indexes = [];
    this.showIndexPanel = false;
    this.newIndexName = '';
    this.newIndexColumns = [];
    this.newIndexUnique = false;
    this.ddlPreview = '';
    this.message = '';
  }

  /**
   * 关闭对话框
   */
  private close(): void {
    this.resetForm();
    if (this.onClose) {
      this.onClose();
    }
  }
}