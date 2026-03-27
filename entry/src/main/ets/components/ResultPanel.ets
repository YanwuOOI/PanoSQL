/**
 * ResultPanel - 结果面板组件
 * 显示查询结果或错误信息
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { QueryResult } from '../models/QueryResult';
import { COLORS } from '../utils/Constants';

const DOMAIN = 0xFF13;

@Component
export struct ResultPanel {
  @Link result: QueryResult | null;
  @State private activeTab: 'table' | 'message' = 'table';

  build() {
    Column() {
      // 结果/消息标签页
      this.buildTabs()

      // 内容区
      if (this.activeTab === 'table') {
        this.buildResultInfo()
      } else {
        this.buildMessage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.BG_ELEVATED)
  }

  @Builder
  buildTabs() {
    Row() {
      // 结果标签
      Row() {
        Text('结果')
          .fontSize(13)
          .fontColor(this.activeTab === 'table' ? COLORS.COLOR_PRIMARY : COLORS.TEXT_SECONDARY)

        if (this.result && this.result.success) {
          Text(` (${this.result.rows.length} 行)`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
        }
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.activeTab === 'table' ? COLORS.BG_ACTIVE : 'transparent')
      .borderRadius(4)
      .onClick(() => this.activeTab = 'table')

      // 消息标签
      Row() {
        Text('消息')
          .fontSize(13)
          .fontColor(this.activeTab === 'message' ? COLORS.COLOR_PRIMARY : COLORS.TEXT_SECONDARY)

        if (this.result && !this.result.success) {
          Circle()
            .width(6)
            .height(6)
            .fill(COLORS.COLOR_ERROR)
            .margin({ left: 6 })
        }
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.activeTab === 'message' ? COLORS.BG_ACTIVE : 'transparent')
      .borderRadius(4)
      .margin({ left: 8 })
      .onClick(() => this.activeTab = 'message')
    }
    .width('100%')
    .padding({ left: 8, top: 4, bottom: 4 })
    .backgroundColor(COLORS.BG_BASE)
  }

  @Builder
  buildResultInfo() {
    Column() {
      if (!this.result) {
        this.buildPlaceholder()
      } else if (!this.result.success) {
        this.buildErrorInfo()
      } else if (this.result.rows.length === 0 && this.result.columns.length === 0) {
        this.buildNoData()
      } else {
        this.buildSuccessInfo()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildPlaceholder() {
    Column() {
      Image($r('sys.media.icon_query'))
        .width(48)
        .height(48)
        .fillColor(COLORS.TEXT_MUTED)
        .opacity(0.5)

      Text('执行SQL查看结果')
        .fontSize(14)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ top: 12 })
    }
  }

  @Builder
  buildSuccessInfo() {
    Column() {
      // 成功图标
      Row() {
        Image($r('sys.media.icon_success'))
          .width(16)
          .height(16)
          .fillColor(COLORS.COLOR_SUCCESS)

        Text('查询成功')
          .fontSize(13)
          .fontColor(COLORS.COLOR_SUCCESS)
          .margin({ left: 6 })
      }

      // 统计信息
      Row() {
        if (this.result!.columns.length > 0) {
          Text(`列数: ${this.result!.columns.length}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
        }

        if (this.result!.rows.length > 0) {
          Text(`行数: ${this.result!.rows.length}`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
            .margin({ left: 16 })
        }

        Text(`耗时: ${this.result!.executionTime}ms`)
          .fontSize(12)
          .fontColor(COLORS.TEXT_MUTED)
          .margin({ left: 16 })
      }
      .margin({ top: 8 })
    }
  }

  @Builder
  buildNoData() {
    Column() {
      Text('查询成功，但没有返回数据')
        .fontSize(14)
        .fontColor(COLORS.TEXT_SECONDARY)

      if (this.result!.affectedRows > 0) {
        Text(`影响行数: ${this.result!.affectedRows}`)
          .fontSize(12)
          .fontColor(COLORS.TEXT_MUTED)
          .margin({ top: 8 })
      }
    }
  }

  @Builder
  buildErrorInfo() {
    Column() {
      // 错误图标和标题
      Row() {
        Image($r('sys.media.icon_error'))
          .width(16)
          .height(16)
          .fillColor(COLORS.COLOR_ERROR)

        Text('执行失败')
          .fontSize(13)
          .fontColor(COLORS.COLOR_ERROR)
          .margin({ left: 6 })
      }

      // 错误信息
      Text(this.result!.error || '未知错误')
        .fontSize(12)
        .fontColor(COLORS.COLOR_ERROR)
        .margin({ top: 8 })
        .padding(12)
        .backgroundColor(COLORS.BG_BASE)
        .borderRadius(4)
        .width('90%')
    }
  }

  @Builder
  buildMessage() {
    Column() {
      if (!this.result) {
        this.buildPlaceholder()
      } else if (this.result.success) {
        // 成功消息
        Column() {
          Row() {
            Image($r('sys.media.icon_success'))
              .width(14)
              .height(14)
              .fillColor(COLORS.COLOR_SUCCESS)

            Text('执行成功')
              .fontSize(13)
              .fontColor(COLORS.COLOR_SUCCESS)
              .margin({ left: 6 })
          }

          if (this.result.affectedRows > 0) {
            Text(`影响 ${this.result.affectedRows} 行`)
              .fontSize(12)
              .fontColor(COLORS.TEXT_SECONDARY)
              .margin({ top: 8 })
          }

          Text(`执行时间: ${this.result.executionTime}ms`)
            .fontSize(12)
            .fontColor(COLORS.TEXT_MUTED)
            .margin({ top: 4 })
        }
      } else {
        // 错误消息
        Scroll() {
          Column() {
            Text(this.result.error || '未知错误')
              .fontSize(13)
              .fontColor(COLORS.COLOR_ERROR)
              .width('100%')
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(COLORS.BG_BASE)
        .borderRadius(4)
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 设置结果
   */
  setResult(result: QueryResult | null) {
    this.result = result;
    // 自动切换到对应标签
    if (result && !result.success) {
      this.activeTab = 'message';
    } else {
      this.activeTab = 'table';
    }
  }
}
