/**
 * ColumnEditor - 列编辑器组件
 * 用于编辑列的名称、类型和约束
 * PanoDB Project
 */
import { COLORS } from '../utils/Constants';
import { ColumnInfo, SQLITE_TYPES } from '../models/TableSchema';

@Component
export struct ColumnEditor {
  @Prop column: ColumnInfo = new ColumnInfo();
  @Prop index: number = 0;
  @Prop isEditMode: boolean = false;
  @State private localColumn: ColumnInfo = new ColumnInfo();
  onColumnChangeFn?: (index: number, column: ColumnInfo) => void;
  onDeleteFn?: (index: number) => void;

  aboutToAppear() {
    this.localColumn = this.column.clone();
  }

  build() {
    Column() {
      // 列名和类型行
      Row() {
        // 列名
        TextInput({ text: this.localColumn.name, placeholder: '列名' })
          .fontSize(13)
          .fontColor(COLORS.TEXT_PRIMARY)
          .placeholderColor(COLORS.TEXT_MUTED)
          .backgroundColor(COLORS.BG_BASE)
          .borderWidth(1)
          .borderColor(COLORS.BORDER_DEFAULT)
          .borderRadius(4)
          .padding(8)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.localColumn.name = value;
            this.notifyChange();
          })

        Text(':')
          .fontSize(13)
          .fontColor(COLORS.TEXT_MUTED)
          .margin({ left: 4, right: 4 })

        // 类型选择
        Column() {
          Select([{ value: 'TEXT' }, { value: 'INTEGER' }, { value: 'REAL' }, { value: 'BLOB' }, { value: 'NUMERIC' }])
            .selected(this.getTypeIndex())
            .fontColor(COLORS.TEXT_PRIMARY)
            .backgroundColor(COLORS.BG_BASE)
            .borderWidth(1)
            .borderColor(COLORS.BORDER_DEFAULT)
            .borderRadius(4)
            .padding(6)
            .width(100)
            .onSelect((index: number) => {
              this.localColumn.type = SQLITE_TYPES[index] || 'TEXT';
              this.notifyChange();
            })
        }

        // 删除按钮
        if (this.isEditMode && this.onDeleteFn) {
          Button('×')
            .fontSize(16)
            .fontColor(COLORS.COLOR_ERROR)
            .backgroundColor('transparent')
            .width(28)
            .height(28)
            .borderRadius(4)
            .margin({ left: 8 })
            .onClick(() => {
              if (this.onDeleteFn) {
                this.onDeleteFn(this.index);
              }
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 约束行
      Row() {
        // 主键
        Row() {
          Checkbox()
            .select(this.localColumn.isPrimaryKey)
            .selectedColor(COLORS.COLOR_PRIMARY)
            .onChange((isSelected: boolean) => {
              this.localColumn.isPrimaryKey = isSelected;
              if (isSelected) {
                this.localColumn.isNotNull = true;
              }
              this.notifyChange();
            })
          Text('主键')
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ left: 4 })
        }
        .margin({ right: 12 })

        // 非空
        Row() {
          Checkbox()
            .select(this.localColumn.isNotNull)
            .selectedColor(COLORS.COLOR_PRIMARY)
            .onChange((isSelected: boolean) => {
              this.localColumn.isNotNull = isSelected;
              this.notifyChange();
            })
          Text('非空')
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ left: 4 })
        }
        .margin({ right: 12 })

        // 唯一
        Row() {
          Checkbox()
            .select(this.localColumn.isUnique)
            .selectedColor(COLORS.COLOR_PRIMARY)
            .onChange((isSelected: boolean) => {
              this.localColumn.isUnique = isSelected;
              this.notifyChange();
            })
          Text('唯一')
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ left: 4 })
        }
        .margin({ right: 12 })

        // 自增
        Row() {
          Checkbox()
            .select(this.localColumn.autoIncrement)
            .selectedColor(COLORS.COLOR_PRIMARY)
            .onChange((isSelected: boolean) => {
              this.localColumn.autoIncrement = isSelected;
              this.notifyChange();
            })
          Text('自增')
            .fontSize(12)
            .fontColor(COLORS.TEXT_SECONDARY)
            .margin({ left: 4 })
        }
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Center)

      // 默认值行
      Row() {
        Text('默认值:')
          .fontSize(12)
          .fontColor(COLORS.TEXT_MUTED)
          .width(50)

        TextInput({ text: this.localColumn.defaultValue, placeholder: 'NULL 或具体值' })
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
            this.localColumn.defaultValue = value;
            this.notifyChange();
          })
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(COLORS.BG_BASE)
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  private getTypeIndex(): number {
    const idx = SQLITE_TYPES.indexOf(this.localColumn.type);
    return idx >= 0 ? idx : 0;
  }

  private notifyChange() {
    if (this.onColumnChangeFn) {
      this.onColumnChangeFn(this.index, this.localColumn);
    }
  }

  /**
   * 注册列变更回调
   */
  setOnColumnChange(callback: (index: number, column: ColumnInfo) => void): void {
    this.onColumnChangeFn = callback;
  }

  /**
   * 注册删除回调
   */
  setOnDelete(callback: (index: number) => void): void {
    this.onDeleteFn = callback;
  }
}