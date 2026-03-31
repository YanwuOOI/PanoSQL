/**
 * WebSqlEditor - 基于 Web 组件的 SQL 编辑器
 * 使用内嵌 HTML + CSS 实现 SQL 语法高亮
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { COLORS } from '../utils/Constants';

const DOMAIN = 0xFF15;

// 消息类型
interface WebMessage {
  type: string;
  text?: string;
  html?: string;
}

@Component
export struct WebSqlEditor {
  @Link sqlText: string;
  @State private isLoading: boolean = true;
  @State private lineNumbers: number[] = [1];
  @State private cursorLine: number = 1;
  @State private cursorColumn: number = 1;
  @State private isExecuting: boolean = false;

  private webController: webview.WebviewController = new webview.WebviewController();
  private isWebReady: boolean = false;

  onExecute?: (sql: string) => void;

  build() {
    Column() {
      // 工具栏
      this.buildToolbar()

      // SQL快捷工具栏
      this.buildSqlToolbar()

      // Web编辑器区域
      Stack() {
        if (this.isLoading) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(COLORS.COLOR_PRIMARY)
        }

        Web({ src: $rawfile('sql_editor.html'), controller: this.webController })
          .width('100%')
          .height('100%')
          .backgroundColor(COLORS.BG_ELEVATED)
          .onPageBegin(() => {
            hilog.info(DOMAIN, 'WebSqlEditor', 'Web page begin loading');
          })
          .onPageEnd(() => {
            hilog.info(DOMAIN, 'WebSqlEditor', 'Web page loaded');
            this.isLoading = false;
          })
          .onErrorReceive((event) => {
            hilog.error(DOMAIN, 'WebSqlEditor', 'Web error');
            this.isLoading = false;
          })
          .onControllerAttached(() => {
            hilog.info(DOMAIN, 'WebSqlEditor', 'Web controller attached');
            this.initWebMessage();
          })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.BG_ELEVATED)
  }

  @Builder
  buildToolbar() {
    Row() {
      // 执行按钮
      Button('执行')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .backgroundColor(COLORS.COLOR_PRIMARY)
        .borderRadius(6)
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .enabled(!this.isExecuting && this.sqlText.trim().length > 0)
        .onClick(() => this.execute())

      // 格式化按钮
      Button('格式化')
        .fontSize(13)
        .fontColor(COLORS.TEXT_PRIMARY)
        .backgroundColor('transparent')
        .borderRadius(6)
        .borderWidth(1)
        .borderColor(COLORS.BORDER_DEFAULT)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .margin({ left: 8 })
        .onClick(() => this.format())

      // 清空按钮
      Button('清空')
        .fontSize(13)
        .fontColor(COLORS.TEXT_SECONDARY)
        .backgroundColor('transparent')
        .borderRadius(6)
        .borderWidth(1)
        .borderColor(COLORS.BORDER_DEFAULT)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .margin({ left: 8 })
        .onClick(() => this.clear())

      Blank()

      // 光标位置
      Text(`${this.cursorLine}:${this.cursorColumn}`)
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ right: 8 })

      // 执行状态
      if (this.isExecuting) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(COLORS.COLOR_PRIMARY)
      }
    }
    .width('100%')
    .padding(8)
    .backgroundColor(COLORS.BG_BASE)
  }

  @Builder
  buildSqlToolbar() {
    Scroll() {
      Row() {
        this.buildSqlButton('SELECT', 'SELECT ')
        this.buildSqlButton('FROM', 'FROM ')
        this.buildSqlButton('WHERE', 'WHERE ')
        this.buildSqlButton('AND', ' AND ')
        this.buildSqlButton('OR', ' OR ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        this.buildSqlButton('INSERT', 'INSERT ')
        this.buildSqlButton('UPDATE', 'UPDATE ')
        this.buildSqlButton('DELETE', 'DELETE ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        this.buildSqlButton('JOIN', 'JOIN ')
        this.buildSqlButton('LEFT JOIN', 'LEFT JOIN ')
        this.buildSqlButton('ORDER BY', 'ORDER BY ')
        this.buildSqlButton('GROUP BY', 'GROUP BY ')
        this.buildSqlButton('LIMIT', 'LIMIT ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        this.buildSqlButton('ON', ' ON ')
        this.buildSqlButton('AS', ' AS ')
        this.buildSqlButton('INTO', 'INTO ')
        this.buildSqlButton('VALUES', 'VALUES ')
        this.buildSqlButton('SET', 'SET ')
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .backgroundColor(COLORS.BG_BASE)
    .borderWidth({ top: 1, bottom: 1 })
    .borderColor(COLORS.BORDER_DEFAULT)
  }

  @Builder
  buildSqlButton(label: string, insertText: string) {
    Button(label)
      .fontSize(11)
      .fontColor(COLORS.SQL_KEYWORD)
      .backgroundColor('transparent')
      .borderRadius(4)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .onClick(() => this.insertText(insertText))
  }

  /**
   * 初始化 Web 消息处理
   */
  private initWebMessage(): void {
    try {
      // Web 组件初始化完成
      this.isWebReady = true;
      hilog.info(DOMAIN, 'WebSqlEditor', 'Web controller ready');

      // 如果有初始文本，设置到 Web
      if (this.sqlText) {
        this.setWebText(this.sqlText);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'WebSqlEditor', 'Failed to init web message: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 设置文本到 Web 编辑器
   */
  private setWebText(text: string): void {
    if (!this.isWebReady) {
      return;
    }

    try {
      const script = `window.postMessage({ type: 'setText', text: ${JSON.stringify(text) }, '*')`;
      this.webController.runJavaScript(script);
    } catch (error) {
      hilog.error(DOMAIN, 'WebSqlEditor', 'Failed to set web text: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 从 Web 编辑器获取文本
   */
  private getWebText(): void {
    if (!this.isWebReady) {
      return;
    }

    try {
      const script = `window.postMessage({ type: 'getText' }, '*')`;
      this.webController.runJavaScript(script);
    } catch (error) {
      hilog.error(DOMAIN, 'WebSqlEditor', 'Failed to get web text: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 更新行号
   */
  private updateLineNumbers(text: string): void {
    const lines = text.split('\n');
    this.lineNumbers = [];
    for (let i = 1; i <= Math.max(lines.length, 1); i++) {
      this.lineNumbers.push(i);
    }
    this.cursorLine = lines.length;
    this.cursorColumn = 1;
  }

  /**
   * 执行 SQL
   */
  private execute(): void {
    if (!this.sqlText.trim() || this.isExecuting) {
      return;
    }

    this.isExecuting = true;

    try {
      hilog.info(DOMAIN, 'WebSqlEditor', 'Executing SQL');
      if (this.onExecute) {
        this.onExecute(this.sqlText);
      }
    } finally {
      this.isExecuting = false;
    }
  }

  /**
   * 格式化 SQL
   */
  private format(): void {
    // 简单的格式化：转大写关键字
    let formatted = this.sqlText.toUpperCase().trim();

    const keywords = ['SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'ORDER BY', 'GROUP BY',
      'HAVING', 'LIMIT', 'OFFSET', 'INSERT INTO', 'VALUES', 'UPDATE', 'SET',
      'DELETE FROM', 'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'ON'];

    for (const kw of keywords) {
      const regex = new RegExp(`\\s+${kw}\\s+`, 'gi');
      formatted = formatted.replace(regex, `\n${kw} `);
    }

    // 添加缩进
    const lines = formatted.split('\n');
    formatted = lines.map((line, index) => {
      if (index === 0) return line;
      if (line.includes('WHERE') || line.includes('ORDER BY') || line.includes('GROUP BY')) {
        return '  ' + line;
      }
      return line;
    }).join('\n');

    this.sqlText = formatted;
    this.setWebText(formatted);
    this.updateLineNumbers(formatted);
  }

  /**
   * 清空编辑器
   */
  private clear(): void {
    this.sqlText = '';
    this.lineNumbers = [1];
    this.cursorLine = 1;
    this.cursorColumn = 1;

    if (this.isWebReady) {
      try {
        const script = `window.postMessage({ type: 'clear' }, '*')`;
        this.webController.runJavaScript(script);
      } catch (error) {
        hilog.error(DOMAIN, 'WebSqlEditor', 'Failed to clear web text: %{public}s',
          JSON.stringify(error));
      }
    }
  }

  /**
   * 插入文本
   */
  private insertText(text: string): void {
    this.sqlText += text;
    this.setWebText(this.sqlText);
    this.updateLineNumbers(this.sqlText);
  }

  /**
   * 设置执行回调
   */
  setOnExecute(callback: (sql: string) => void): void {
    this.onExecute = callback;
  }

  /**
   * 设置编辑器内容
   */
  setValue(sql: string): void {
    this.sqlText = sql;
    this.setWebText(sql);
    this.updateLineNumbers(sql);
  }
}
