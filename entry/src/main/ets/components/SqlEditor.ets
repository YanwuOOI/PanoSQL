/**
 * SqlEditor - SQL编辑器组件
 * MVP方案：使用TextArea + 行号显示 + SQL快捷工具栏
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import QueryService from '../services/QueryService';
import { COLORS } from '../utils/Constants';

const DOMAIN = 0xFF11;

/**
 * 简单的撤销/重做管理器
 */
class UndoManager {
  private history: string[] = [];
  private currentIndex: number = -1;
  private maxSize: number = 50;

  /**
   * 添加历史记录
   */
  push(text: string): void {
    // 如果当前不在历史末尾，先截断
    if (this.currentIndex < this.history.length - 1) {
      this.history = this.history.slice(0, this.currentIndex + 1);
    }

    // 避免重复
    if (this.history.length > 0 && this.history[this.history.length - 1] === text) {
      return;
    }

    this.history.push(text);
    this.currentIndex = this.history.length - 1;

    // 限制历史大小
    if (this.history.length > this.maxSize) {
      this.history.shift();
      this.currentIndex--;
    }
  }

  /**
   * 是否可撤销
   */
  canUndo(): boolean {
    return this.currentIndex > 0;
  }

  /**
   * 是否可重做
   */
  canRedo(): boolean {
    return this.currentIndex < this.history.length - 1;
  }

  /**
   * 撤销
   */
  undo(): string | null {
    if (!this.canUndo()) {
      return null;
    }
    this.currentIndex--;
    return this.history[this.currentIndex];
  }

  /**
   * 重做
   */
  redo(): string | null {
    if (!this.canRedo()) {
      return null;
    }
    this.currentIndex++;
    return this.history[this.currentIndex];
  }

  /**
   * 清空历史
   */
  clear(): void {
    this.history = [];
    this.currentIndex = -1;
  }
}

@Component
export struct SqlEditor {
  @Link sqlText: string;
  @State private lineNumbers: number[] = [1];
  @State private cursorLine: number = 1;
  @State private cursorColumn: number = 1;
  @State private isExecuting: boolean = false;

  onExecute?: (sql: string) => void;
  private textAreaController: TextAreaController = new TextAreaController();
  private undoManager: UndoManager = new UndoManager();

  build() {
    Column() {
      // 编辑器工具栏
      this.buildToolbar()

      // SQL快捷工具栏
      this.buildSqlToolbar()

      // 编辑器区域（行号 + TextArea）
      this.buildEditorArea()
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

      Divider()
        .vertical(true)
        .height(20)
        .color(COLORS.BORDER_DEFAULT)
        .margin({ left: 8, right: 8 })

      // 撤销按钮
      Button('↩')
        .fontSize(14)
        .fontColor(COLORS.TEXT_SECONDARY)
        .backgroundColor('transparent')
        .borderRadius(4)
        .width(32)
        .height(32)
        .onClick(() => this.undo())

      // 重做按钮
      Button('↪')
        .fontSize(14)
        .fontColor(COLORS.TEXT_SECONDARY)
        .backgroundColor('transparent')
        .borderRadius(4)
        .width(32)
        .height(32)
        .onClick(() => this.redo())

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

  /**
   * SQL快捷工具栏
   * 提供常用SQL关键字的快捷按钮
   */
  @Builder
  buildSqlToolbar() {
    Scroll() {
      Row() {
        // SELECT组
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

        // DML组
        this.buildSqlButton('INSERT', 'INSERT ')
        this.buildSqlButton('UPDATE', 'UPDATE ')
        this.buildSqlButton('DELETE', 'DELETE ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        // JOIN组
        this.buildSqlButton('JOIN', 'JOIN ')
        this.buildSqlButton('LEFT', 'LEFT ')
        this.buildSqlButton('RIGHT', 'RIGHT ')
        this.buildSqlButton('INNER', 'INNER ')
        this.buildSqlButton('OUTER', 'OUTER ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        // ORDER组
        this.buildSqlButton('ORDER BY', 'ORDER BY ')
        this.buildSqlButton('GROUP BY', 'GROUP BY ')
        this.buildSqlButton('HAVING', 'HAVING ')
        this.buildSqlButton('LIMIT', 'LIMIT ')

        Divider()
          .vertical(true)
          .height(16)
          .color(COLORS.BORDER_DEFAULT)
          .margin({ left: 8, right: 8 })

        // 其他
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

  /**
   * 构建SQL快捷按钮
   */
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

  @Builder
  buildEditorArea() {
    Row() {
      // 行号列
      Column() {
        ForEach(this.lineNumbers, (num: number) => {
          Text(num.toString())
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor(COLORS.TEXT_MUTED)
            .width('100%')
            .textAlign(TextAlign.End)
            .padding({ right: 8, top: 8, bottom: 0 })
        })
      }
      .width(48)
      .backgroundColor(COLORS.BG_BASE)
      .padding({ top: 8 })
      .alignItems(HorizontalAlign.End)

      // TextArea编辑器
      TextArea({
        text: this.sqlText,
        placeholder: '输入 SQL 语句...',
        controller: this.textAreaController
      })
        .fontSize(14)
        .fontFamily('monospace')
        .fontColor(COLORS.TEXT_PRIMARY)
        .caretColor(COLORS.COLOR_PRIMARY)
        .placeholderColor(COLORS.TEXT_MUTED)
        .backgroundColor(COLORS.BG_ELEVATED)
        .borderWidth(0)
        .padding(8)
        .width('100%')
        .height('100%')
        .textAlign(TextAlign.Start)
        .maxLines(10000)
        .constraintSize({ minHeight: 100 })
        .onChange((value: string) => {
          this.sqlText = value;
          this.updateLineNumbers(value);
          this.undoManager.push(value);
        })
    }
    .width('100%')
    .layoutWeight(1)
  }

  /**
   * 更新行号
   */
  updateLineNumbers(text: string) {
    const lines = text.split('\n');
    this.lineNumbers = [];
    for (let i = 1; i <= Math.max(lines.length, 1); i++) {
      this.lineNumbers.push(i);
    }
    // 更新光标位置（简化：假设在最后一行）
    this.cursorLine = lines.length;
    this.cursorColumn = 1;
  }

  /**
   * 执行SQL
   */
  async execute() {
    if (!this.sqlText.trim() || this.isExecuting) {
      return;
    }

    this.isExecuting = true;

    try {
      hilog.info(DOMAIN, 'SqlEditor', 'Executing SQL: %{public}s',
        this.sqlText.substring(0, 100));

      if (this.onExecute) {
        this.onExecute(this.sqlText);
      }
    } finally {
      this.isExecuting = false;
    }
  }

  /**
   * 格式化SQL
   */
  format() {
    const formatted = QueryService.formatSql(this.sqlText);
    this.sqlText = formatted;
    this.updateLineNumbers(formatted);
    this.undoManager.clear();
  }

  /**
   * 清空编辑器
   */
  clear() {
    this.sqlText = '';
    this.lineNumbers = [1];
    this.cursorLine = 1;
    this.cursorColumn = 1;
    this.undoManager.clear();
  }

  /**
   * 撤销
   */
  undo() {
    try {
      const prevText = this.undoManager.undo();
      if (prevText !== null) {
        this.sqlText = prevText;
        this.updateLineNumbers(prevText);
        hilog.info(DOMAIN, 'SqlEditor', 'Undo performed');
      }
    } catch (error) {
      hilog.warn(DOMAIN, 'SqlEditor', 'Undo failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 重做
   */
  redo() {
    try {
      const nextText = this.undoManager.redo();
      if (nextText !== null) {
        this.sqlText = nextText;
        this.updateLineNumbers(nextText);
        hilog.info(DOMAIN, 'SqlEditor', 'Redo performed');
      }
    } catch (error) {
      hilog.warn(DOMAIN, 'SqlEditor', 'Redo failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置执行回调
   */
  setOnExecute(callback: (sql: string) => void) {
    this.onExecute = callback;
  }

  /**
   * 插入文本到编辑器末尾
   */
  insertText(text: string) {
    this.sqlText += text;
    this.updateLineNumbers(this.sqlText);
  }

  /**
   * 设置编辑器内容
   */
  setValue(sql: string) {
    this.sqlText = sql;
    this.updateLineNumbers(sql);
  }
}
