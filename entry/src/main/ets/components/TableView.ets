/**
 * TableView - 数据表格组件
 * 使用LazyForEach + IDataSource实现懒加载
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { COLORS } from '../utils/Constants';
import { QueryResult, TableRow, TableRowImpl, getCellValue } from '../models/QueryResult';

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
  @State private dataSource: TableDataSource = new TableDataSource();
  @State private sortColumn: string = '';
  @State private sortOrder: 'asc' | 'desc' = 'asc';
  @State private currentPage: number = 1;
  @State private pageSize: number = 100;
  @State private totalCount: number = 0;
  @State private selectedRowIndex: number = -1;

  private onRowClick?: (row: TableRow, index: number) => void;
  private allData: TableRow[] = [];
  private scroller: Scroller = new Scroller();

  build() {
    Column() {
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
          Text(this.formatCellValue(getCellValue(row, col)))
            .fontSize(13)
            .fontColor(this.formatCellColor(getCellValue(row, col)))
            .fontStyle(getCellValue(row, col) === null ? FontStyle.Italic : FontStyle.Normal)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width(this.getColumnWidth(col))
        .padding(10)
        .alignItems(HorizontalAlign.Start)
      })
    }
    .width('100%')
    .backgroundColor(index === this.selectedRowIndex ? COLORS.BG_ACTIVE :
      (index % 2 === 0 ? COLORS.BG_ELEVATED : COLORS.BG_BASE))
    .height(40)
    .onClick(() => {
      this.selectedRowIndex = index;
      if (this.onRowClick) {
        this.onRowClick(row, index);
      }
    })
  }

  @Builder
  buildPagination() {
    Row() {
      Text(`共 ${this.totalCount} 条`)
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)

      Blank()

      Text(`第 ${this.currentPage} / ${this.getTotalPages()} 页`)
        .fontSize(12)
        .fontColor(COLORS.TEXT_SECONDARY)
        .margin({ left: 16, right: 16 })

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
      this.allData = result.rows;
      this.totalCount = result.rows.length;
      this.currentPage = 1;
      this.loadCurrentPage();
    } else {
      this.allData = [];
      this.totalCount = 0;
      this.columns = [];
    }
  }

  /**
   * 加载当前页数据
   */
  private loadCurrentPage() {
    this.dataSource.loadPage(this.currentPage, this.pageSize, this.allData);
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
    for (let i = 0; i < this.allData.length; i++) {
      sorted.push(this.allData[i]);
    }
    sorted.sort((a: TableRow, b: TableRow) => {
      const aVal = getCellValue(a, column) || '';
      const bVal = getCellValue(b, column) || '';
      const cmp = String(aVal).localeCompare(String(bVal));
      return this.sortOrder === 'asc' ? cmp : -cmp;
    });

    this.allData = sorted;
    this.loadCurrentPage();
  }

  /**
   * 跳转到指定页
   */
  goToPage(page: number) {
    const totalPages = this.getTotalPages();
    if (page >= 1 && page <= totalPages) {
      this.currentPage = page;
      this.loadCurrentPage();
    }
  }

  /**
   * 格式化单元格值
   */
  formatCellValue(value: string | null): string {
    if (value === null || value === undefined) {
      return 'NULL';
    }
    if (typeof value !== 'string') {
      return String(value);
    }
    // 限制最大长度
    if (value.length > 200) {
      return value.substring(0, 200) + '...';
    }
    return value;
  }

  /**
   * 格式化单元格颜色
   */
  formatCellColor(value: string | null): string {
    if (value === null || value === undefined) {
      return COLORS.TEXT_MUTED;
    }
    return COLORS.TEXT_PRIMARY;
  }

  /**
   * 获取列宽度
   */
  getColumnWidth(column: string): Length {
    return 'auto';
  }

  /**
   * 注册行点击回调
   */
  setOnRowClick(callback: (row: TableRow, index: number) => void) {
    this.onRowClick = callback;
  }
}
