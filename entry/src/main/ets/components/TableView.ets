/**
 * TableView - 数据表格组件
 * 支持数据编辑功能：单元格编辑、INSERT、DELETE
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { COLORS } from '../utils/Constants';
import { QueryResult, TableRow, TableRowImpl, getCellValue } from '../models/QueryResult';
import { TableEditState } from '../models/TableEditState';

const DOMAIN = 0xFF12;

// 懒加载数据源
class TableDataSource implements IDataSource {
  private data: TableRow[] = [];
  private listener: DataChangeListener | null = null;

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): TableRow {
    if (index >= 0 && index < this.data.length) {
      return this.data[index];
    }
    const emptyRow: TableRow = new TableRowImpl();
    return emptyRow;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listener = listener;
  }

  unregisterDataChangeListener(): void {
    this.listener = null;
  }

  loadPage(page: number, pageSize: number, totalData: TableRow[]): void {
    const start = (page - 1) * pageSize;
    const end = Math.min(start + pageSize, totalData.length);
    this.data = totalData.slice(start, end);
    if (this.listener) {
      this.listener.onDataReloaded();
    }
  }

  reload(newData: TableRow[]): void {
    this.data = newData;
    if (this.listener) {
      this.listener.onDataReloaded();
    }
  }
}

@Component
export struct TableView {
  @Prop columns: string[] = [];
  @Prop isLoading: boolean = false;
  @Link rows: TableRow[];
  @Prop tableName: string = '';
  @State private dataSource: TableDataSource = new TableDataSource();
  @State private sortColumn: string = '';
  @State private sortOrder: 'asc' | 'desc' = 'asc';
  @State private currentPage: number = 1;
  @State private pageSize: number = 100;
  @State private totalCount: number = 0;
  @State private selectedRowIndex: number = -1;
  @State private editState: TableEditState = new TableEditState();
  @State private showDeleteConfirm: boolean = false;
  @State private deleteTargetRowIndex: number = -1;

  private onRowClick?: (row: TableRow, index: number) => void;
  private onDataChange?: (hasChanges: boolean) => void;
  onSaveRequestFn?: (sqls: string[]) => void;
  private scroller: Scroller = new Scroller();
  private editInputController: TextInputController = new TextInputController();

  // 本地数据副本（用于排序等本地操作）
  private localData: TableRow[] = [];

  build() {
    Stack() {
      Column() {
        // 编辑工具栏
        this.buildEditToolbar()

        // 表格内容
        if (this.isLoading) {
          this.buildLoading()
        } else if (this.columns.length === 0) {
          this.buildEmpty('暂无数据', '请执行SQL查询')
        } else if (this.totalCount === 0) {
          this.buildEmpty('无结果', '查询结果为空')
        } else {
          this.buildTable()
          this.buildPagination()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLORS.BG_ELEVATED)

      // 编辑输入框遮罩
      if (this.editState.isEditing && this.editState.currentEdit) {
        this.buildEditOverlay()
      }

      // 删除确认对话框
      if (this.showDeleteConfirm) {
        this.buildDeleteConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildEditToolbar() {
    Row() {
      Text(`共 ${this.totalCount} 条`)
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)

      if (this.editState.hasChanges()) {
        Text(` (${this.editState.getChangeCount()} 项待保存)`)
          .fontSize(12)
          .fontColor(COLORS.COLOR_WARNING)
      }

      Blank()

      Button('新增行')
        .fontSize(12)
        .fontColor(COLORS.COLOR_PRIMARY)
        .backgroundColor('transparent')
        .enabled(this.columns.length > 0)
        .onClick(() => this.insertRow())

      Button('删除行')
        .fontSize(12)
        .fontColor(this.selectedRowIndex >= 0 ? COLORS.COLOR_ERROR : COLORS.TEXT_MUTED)
        .backgroundColor('transparent')
        .enabled(this.selectedRowIndex >= 0 && !this.isRowDeleted(this.selectedRowIndex))
        .margin({ left: 8 })
        .onClick(() => this.confirmDelete())

      Button('保存更改')
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor(this.editState.hasChanges() ? COLORS.COLOR_PRIMARY : COLORS.TEXT_MUTED)
        .enabled(this.editState.hasChanges())
        .margin({ left: 8 })
        .onClick(() => this.saveChanges())

      Button('放弃更改')
        .fontSize(12)
        .fontColor(COLORS.TEXT_SECONDARY)
        .backgroundColor('transparent')
        .enabled(this.editState.hasChanges())
        .margin({ left: 8 })
        .onClick(() => this.discardChanges())
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 12 })
    .backgroundColor(COLORS.BG_BASE)
    .borderWidth({ bottom: 1 })
    .borderColor(COLORS.BORDER_DEFAULT)
  }

  @Builder
  buildLoading() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color(COLORS.COLOR_PRIMARY)
      Text('加载中...')
        .fontSize(13)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildEmpty(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontColor(COLORS.TEXT_SECONDARY)
      Text(subtitle)
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildTable() {
    Column() {
      // 表头
      Scroll(this.scroller) {
        Row() {
          ForEach(this.columns, (col: string) => {
            Column() {
              Row() {
                Text(col)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.sortColumn === col ? COLORS.COLOR_PRIMARY : COLORS.TEXT_SECONDARY)

                if (this.sortColumn === col) {
                  Text(this.sortOrder === 'asc' ? '↑' : '↓')
                    .fontSize(12)
                    .fontColor(COLORS.COLOR_PRIMARY)
                    .margin({ left: 4 })
                }
              }
            }
            .width(this.getColumnWidth(col))
            .padding(10)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => this.sort(col))
          })
        }
        .width('100%')
        .backgroundColor(COLORS.BG_BASE)
        .height(40)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)

      // 表体 - 使用LazyForEach
      List() {
        LazyForEach(this.dataSource, (row: TableRow, index: number) => {
          ListItem() {
            this.buildRow(row, index)
          }
        }, (row: TableRow, index: number) => `${index}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildRow(row: TableRow, index: number) {
    Row() {
      ForEach(this.columns, (col: string) => {
        Column() {
          if (this.isCellEditing(index, col)) {
            TextInput({ controller: this.editInputController, text: this.editState.currentEdit?.editValue ?? '' })
              .fontSize(13)
              .fontColor(COLORS.TEXT_PRIMARY)
              .backgroundColor(COLORS.BG_BASE)
              .borderWidth(1)
              .borderColor(COLORS.COLOR_PRIMARY)
              .borderRadius(4)
              .padding(4)
              .width('100%')
              .height(30)
              .onChange((value: string) => {
                this.editState.updateEditValue(value);
              })
              .onSubmit(() => {
                this.editState.saveEdit();
              })
          } else {
            Text(this.getDisplayValue(row, col, index))
              .fontSize(13)
              .fontColor(this.getCellTextColor(row, col, index))
              .fontStyle(getCellValue(row, col) === null ? FontStyle.Italic : FontStyle.Normal)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .backgroundColor(this.getCellBgColor(row, col, index))
              .borderRadius(4)
              .padding(4)
              .width('100%')
          }
        }
        .width(this.getColumnWidth(col))
        .padding(8)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          if (!this.editState.isEditing) {
            this.startCellEdit(row, index, col);
          }
        })
      })
    }
    .width('100%')
    .backgroundColor(index === this.selectedRowIndex ? COLORS.BG_ACTIVE :
      (this.isRowDeleted(index) ? 'rgba(255, 0, 0, 0.1)' :
        (index % 2 === 0 ? COLORS.BG_ELEVATED : COLORS.BG_BASE)))
    .height(44)
    .onClick(() => {
      this.selectedRowIndex = index;
      if (this.onRowClick) {
        this.onRowClick(row, index);
      }
    })
  }

  @Builder
  buildEditOverlay() {
    Column() {
      Column() {
        Text('编辑单元格')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ bottom: 12 })

        if (this.editState.currentEdit) {
          Text(`列: ${this.editState.currentEdit.column}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ bottom: 4 })

          Text(`原值: ${this.formatCellValue(this.editState.currentEdit.originalValue)}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
            .margin({ bottom: 12 })

          TextInput({ controller: this.editInputController, text: this.editState.currentEdit.editValue })
            .fontSize(13)
            .fontColor(COLORS.TEXT_PRIMARY)
            .placeholderColor(COLORS.TEXT_MUTED)
            .backgroundColor(COLORS.BG_BASE)
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .borderRadius(6)
            .padding(10)
            .width('100%')
            .margin({ bottom: 12 })
            .onChange((value: string) => {
              this.editState.updateEditValue(value);
            })

          Row() {
            Checkbox()
              .select(this.editState.currentEdit.isNull)
              .selectedColor(COLORS.COLOR_PRIMARY)
              .onChange((isSelected: boolean) => {
                if (isSelected) {
                  this.editState.toggleNull();
                }
              })

            Text('设为 NULL')
              .fontSize(13)
              .fontColor(COLORS.TEXT_PRIMARY)
              .margin({ left: 8 })
          }
          .margin({ bottom: 16 })

          Row() {
            Button('取消')
              .fontSize(13)
              .fontColor(COLORS.TEXT_SECONDARY)
              .backgroundColor('transparent')
              .borderWidth(1)
              .borderColor(COLORS.BORDER_DEFAULT)
              .borderRadius(6)
              .width(80)
              .height(36)
              .onClick(() => this.editState.cancelEdit())

            Button('保存')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor(COLORS.COLOR_PRIMARY)
              .borderRadius(6)
              .width(80)
              .height(36)
              .margin({ left: 12 })
              .onClick(() => {
                this.editState.saveEdit();
                this.notifyDataChange();
              })
          }
        }
      }
      .width(320)
      .padding(20)
      .backgroundColor(COLORS.BG_ELEVATED)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildDeleteConfirmDialog() {
    Column() {
      Column() {
        Text('确认删除')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.TEXT_PRIMARY)
          .margin({ bottom: 12 })

        Text('确定要删除这一行吗？此操作不可撤销。')
          .fontSize(14)
          .fontColor(COLORS.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        Row() {
          Button('取消')
            .fontSize(13)
            .fontColor(COLORS.TEXT_SECONDARY)
            .backgroundColor('transparent')
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .borderRadius(6)
            .width(100)
            .height(36)
            .onClick(() => {
              this.showDeleteConfirm = false;
              this.deleteTargetRowIndex = -1;
            })

          Button('删除')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(COLORS.COLOR_ERROR)
            .borderRadius(6)
            .width(100)
            .height(36)
            .margin({ left: 12 })
            .onClick(() => {
              this.deleteRow();
              this.showDeleteConfirm = false;
            })
        }
      }
      .width(300)
      .padding(20)
      .backgroundColor(COLORS.BG_ELEVATED)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildPagination() {
    Row() {
      Text(`第 ${this.currentPage} / ${this.getTotalPages()} 页`)
        .fontSize(12)
        .fontColor(COLORS.TEXT_SECONDARY)
        .margin({ left: 16, right: 16 })

      Blank()

      Button('首页')
        .fontSize(12)
        .fontColor(this.currentPage > 1 ? COLORS.COLOR_PRIMARY : COLORS.TEXT_MUTED)
        .backgroundColor('transparent')
        .enabled(this.currentPage > 1)
        .onClick(() => this.goToPage(1))

      Button('上一页')
        .fontSize(12)
        .fontColor(this.currentPage > 1 ? COLORS.COLOR_PRIMARY : COLORS.TEXT_MUTED)
        .backgroundColor('transparent')
        .enabled(this.currentPage > 1)
        .margin({ left: 4 })
        .onClick(() => this.goToPage(this.currentPage - 1))

      Button('下一页')
        .fontSize(12)
        .fontColor(this.currentPage < this.getTotalPages() ? COLORS.COLOR_PRIMARY : COLORS.TEXT_MUTED)
        .backgroundColor('transparent')
        .enabled(this.currentPage < this.getTotalPages())
        .margin({ left: 4 })
        .onClick(() => this.goToPage(this.currentPage + 1))

      Button('末页')
        .fontSize(12)
        .fontColor(this.currentPage < this.getTotalPages() ? COLORS.COLOR_PRIMARY : COLORS.TEXT_MUTED)
        .backgroundColor('transparent')
        .enabled(this.currentPage < this.getTotalPages())
        .margin({ left: 4 })
        .onClick(() => this.goToPage(this.getTotalPages()))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(COLORS.BG_BASE)
  }

  /**
   * 加载数据
   */
  loadData(result: QueryResult) {
    if (result.success) {
      this.rows = result.rows;
      this.localData = result.rows.slice();
      this.totalCount = result.rows.length;
      this.currentPage = 1;
      this.loadCurrentPageFromLocalData();
      this.editState.clearAll();
    } else {
      this.rows = [];
      this.localData = [];
      this.totalCount = 0;
    }
  }

  /**
   * 同步本地数据（当@Link rows变化时调用）
   */
  syncFromRows() {
    if (this.rows.length > 0 && this.localData.length === 0) {
      this.localData = this.rows.slice();
      this.totalCount = this.rows.length;
      this.loadCurrentPageFromLocalData();
    }
  }

  /**
   * 根据本地数据加载分页数据
   */
  private loadCurrentPageFromLocalData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = Math.min(start + this.pageSize, this.localData.length);
    const pageData = this.localData.slice(start, end);
    this.dataSource.reload(pageData);
  }

  /**
   * 获取总页数
   */
  private getTotalPages(): number {
    return Math.ceil(this.totalCount / this.pageSize) || 1;
  }

  /**
   * 排序
   */
  sort(column: string) {
    if (this.sortColumn === column) {
      this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortColumn = column;
      this.sortOrder = 'asc';
    }

    // 本地排序
    const sorted: TableRow[] = [];
    for (let i = 0; i < this.localData.length; i++) {
      sorted.push(this.localData[i]);
    }
    sorted.sort((a: TableRow, b: TableRow) => {
      const aVal = getCellValue(a, column) || '';
      const bVal = getCellValue(b, column) || '';
      const cmp = String(aVal).localeCompare(String(bVal));
      return this.sortOrder === 'asc' ? cmp : -cmp;
    });

    this.localData = sorted;
    this.loadCurrentPageFromLocalData();
  }

  /**
   * 跳转到指定页
   */
  goToPage(page: number) {
    const totalPages = this.getTotalPages();
    if (page >= 1 && page <= totalPages) {
      this.currentPage = page;
      this.loadCurrentPageFromLocalData();
    }
  }

  /**
   * 开始单元格编辑
   */
  private startCellEdit(row: TableRow, rowIndex: number, column: string): void {
    const value = getCellValue(row, column);
    // 将 string | number | null 转换为 string | null
    const strValue = typeof value === 'string' ? value : (value === null ? null : String(value));
    this.editState.startEdit(rowIndex, column, strValue);
  }

  /**
   * 检查单元格是否正在编辑
   */
  private isCellEditing(rowIndex: number, column: string): boolean {
    if (!this.editState.isEditing || !this.editState.currentEdit) {
      return false;
    }
    return this.editState.currentEdit.rowIndex === rowIndex &&
           this.editState.currentEdit.column === column;
  }

  /**
   * 获取显示值
   */
  private getDisplayValue(row: TableRow, col: string, rowIndex: number): string {
    // 检查是否有变更
    const changeInfo = this.editState.changedRows.get(rowIndex);
    if (changeInfo && changeInfo.changes.has(col)) {
      const change = changeInfo.changes.get(col);
      return this.formatCellValue(change?.newValue ?? null);
    }
    const val = getCellValue(row, col);
    return this.formatCellValue(typeof val === 'string' ? val : (val === null ? null : String(val)));
  }

  /**
   * 获取单元格背景色
   */
  private getCellBgColor(row: TableRow, col: string, rowIndex: number): string {
    const isDeleted = this.isRowDeleted(rowIndex);
    const isModified = this.editState.changedRows.has(rowIndex);
    if (isDeleted) {
      return 'rgba(255, 0, 0, 0.05)';
    }
    if (isModified) {
      return 'rgba(255, 200, 0, 0.1)';
    }
    return 'transparent';
  }

  /**
   * 获取单元格文字颜色
   */
  private getCellTextColor(row: TableRow, col: string, rowIndex: number): string {
    const isDeleted = this.isRowDeleted(rowIndex);
    if (isDeleted) {
      return COLORS.TEXT_MUTED;
    }
    const val = getCellValue(row, col);
    return this.formatCellColor(typeof val === 'string' ? val : (val === null ? null : String(val)));
  }

  /**
   * 检查行是否被标记删除
   */
  private isRowDeleted(rowIndex: number): boolean {
    return this.editState.deletedRowIndices.includes(rowIndex);
  }

  /**
   * 格式化单元格值
   */
  private formatCellValue(value: string | null): string {
    if (value === null || value === undefined) {
      return 'NULL';
    }
    if (typeof value !== 'string') {
      return String(value);
    }
    if (value.length > 200) {
      return value.substring(0, 200) + '...';
    }
    return value;
  }

  /**
   * 格式化单元格颜色
   */
  private formatCellColor(value: string | null): string {
    if (value === null || value === undefined) {
      return COLORS.TEXT_MUTED;
    }
    return COLORS.TEXT_PRIMARY;
  }

  /**
   * 获取列宽度
   */
  private getColumnWidth(column: string): Length {
    return 'auto';
  }

  /**
   * 注册行点击回调
   */
  setOnRowClick(callback: (row: TableRow, index: number) => void): void {
    this.onRowClick = callback;
  }

  /**
   * 注册数据变更回调
   */
  setOnDataChange(callback: (hasChanges: boolean) => void): void {
    this.onDataChange = callback;
  }

  /**
   * 注册保存请求回调
   */
  setOnSaveRequest(callback: (sqls: string[]) => void): void {
    this.onSaveRequestFn = callback;
  }

  /**
   * 通知数据变更
   */
  private notifyDataChange(): void {
    if (this.onDataChange) {
      this.onDataChange(this.editState.hasChanges());
    }
  }

  /**
   * 准备新增行
   */
  private insertRow(): void {
    if (this.columns.length === 0) return;

    const newRowInfo = this.editState.prepareInsert(this.columns);
    hilog.info(DOMAIN, 'TableView', 'Prepared insert new row');
    this.notifyDataChange();
  }

  /**
   * 确认删除
   */
  private confirmDelete(): void {
    if (this.selectedRowIndex >= 0) {
      this.deleteTargetRowIndex = this.selectedRowIndex;
      this.showDeleteConfirm = true;
    }
  }

  /**
   * 执行删除
   */
  private deleteRow(): void {
    if (this.deleteTargetRowIndex >= 0) {
      this.editState.markDelete(this.deleteTargetRowIndex);
      this.deleteTargetRowIndex = -1;
      this.notifyDataChange();
    }
  }

  /**
   * 获取所有变更的SQL
   */
  getChangeSqls(): string[] {
    const sqls: string[] = [];

    // 生成UPDATE SQL
    const changedRowKeys = Array.from(this.editState.changedRows.keys());
    for (const rowIndex of changedRowKeys) {
      const changeInfo = this.editState.changedRows.get(rowIndex);
      if (changeInfo && changeInfo.type === 'update' && rowIndex >= 0) {
        const row = this.localData[rowIndex];
        const rowData = new Map<string, string | null>();
        for (let j = 0; j < this.columns.length; j++) {
          const col = this.columns[j];
          const val = getCellValue(row, col);
          rowData.set(col, typeof val === 'string' ? val : (val === null ? null : String(val)));
        }
        const updateSql = this.editState.generateUpdateSql(this.tableName, this.columns, rowData, rowIndex);
        if (updateSql) {
          sqls.push(updateSql);
        }
      }
    }

    // 生成DELETE SQL
    for (let i = 0; i < this.editState.deletedRowIndices.length; i++) {
      const rowIndex = this.editState.deletedRowIndices[i];
      if (rowIndex >= 0 && rowIndex < this.localData.length) {
        const row = this.localData[rowIndex];
        const rowData = new Map<string, string | null>();
        for (let j = 0; j < this.columns.length; j++) {
          const col = this.columns[j];
          const val = getCellValue(row, col);
          rowData.set(col, typeof val === 'string' ? val : (val === null ? null : String(val)));
        }
        const deleteSql = this.editState.generateDeleteSql(this.tableName, this.columns, rowData, rowIndex);
        sqls.push(deleteSql);
      }
    }

    // 生成INSERT SQL
    for (const newRow of this.editState.newRows) {
      const insertSql = this.editState.generateInsertSql(newRow, this.tableName);
      if (insertSql) {
        sqls.push(insertSql);
      }
    }

    return sqls;
  }

  /**
   * 保存更改（请求父组件执行SQL）
   */
  async saveChanges(): Promise<boolean> {
    if (!this.editState.hasChanges()) {
      return false;
    }

    hilog.info(DOMAIN, 'TableView', 'Requesting save, count: %{public}d', this.editState.getChangeCount());

    const sqls = this.getChangeSqls();
    if (sqls.length === 0) {
      return false;
    }

    // 请求父组件执行SQL
    if (this.onSaveRequestFn) {
      this.onSaveRequestFn(sqls);
    }

    return true;
  }

  /**
   * 放弃更改
   */
  private discardChanges(): void {
    this.editState.clearAll();
    this.notifyDataChange();
  }
}