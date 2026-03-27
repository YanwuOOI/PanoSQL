/**
 * StatusBar - 状态栏组件
 * 显示连接状态、表数量、查询耗时等信息
 * PanoDB Project
 */
import { COLORS, ConnectionState } from '../utils/Constants';

@Component
export struct StatusBar {
  @Prop connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  @Prop tableCount: number = 0;
  @Prop queryTime: number = 0;
  @Prop rowCount: number = 0;
  @Prop currentTable: string = '';

  build() {
    Row() {
      // 连接状态
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getConnectionColor())

        Text(this.getConnectionText())
          .fontSize(12)
          .fontColor(COLORS.TEXT_SECONDARY)
          .margin({ left: 6 })
      }

      Divider()
        .vertical(true)
        .height(14)
        .color(COLORS.BORDER_DEFAULT)
        .margin({ left: 12, right: 12 })

      // 表数量
      if (this.tableCount > 0) {
        Row() {
          Text('表: ')
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)

          Text(`${this.tableCount}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
        }

        Divider()
          .vertical(true)
          .height(14)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 12, right: 12 })
      }

      // 当前表
      if (this.currentTable) {
        Row() {
          Text('当前: ')
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)

          Text(this.currentTable)
            .fontSize(12)
            .fontColor(COLORS.COLOR_PRIMARY)
        }

        Divider()
          .vertical(true)
          .height(14)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 12, right: 12 })
      }

      // 查询耗时
      if (this.queryTime > 0) {
        Row() {
          Text('耗时: ')
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)

          Text(`${this.queryTime}ms`)
            .fontSize(12)
            .fontColor(this.queryTime > 1000 ? COLORS.COLOR_WARNING : COLORS.TEXT_SECONDARY)
        }

        Divider()
          .vertical(true)
          .height(14)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 12, right: 12 })
      }

      // 行数
      if (this.rowCount > 0) {
        Row() {
          Text('行数: ')
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)

          Text(`${this.rowCount}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
        }
      }

      Blank()

      // 版本信息
      Text('PanoDB v1.0.0')
        .fontSize(11)
        .fontColor(COLORS.TEXT_MUTED)
    }
    .width('100%')
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor(COLORS.BG_BASE)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 获取连接状态颜色
   */
  private getConnectionColor(): string {
    switch (this.connectionState) {
      case ConnectionState.CONNECTED:
        return COLORS.COLOR_SUCCESS;
      case ConnectionState.CONNECTING:
        return COLORS.COLOR_WARNING;
      case ConnectionState.ERROR:
        return COLORS.COLOR_ERROR;
      default:
        return COLORS.TEXT_MUTED;
    }
  }

  /**
   * 获取连接状态文本
   */
  private getConnectionText(): string {
    switch (this.connectionState) {
      case ConnectionState.CONNECTED:
        return '已连接';
      case ConnectionState.CONNECTING:
        return '连接中...';
      case ConnectionState.ERROR:
        return '连接错误';
      default:
        return '未连接';
    }
  }
}
