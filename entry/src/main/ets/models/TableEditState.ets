/**
 * TableEditState - 表格编辑状态模型
 * PanoDB Project
 */

/**
 * 单元格值变更
 */
export class CellChange {
  oldValue: string | null = null;
  newValue: string | null = null;

  constructor(oldValue: string | null, newValue: string | null) {
    this.oldValue = oldValue;
    this.newValue = newValue;
  }
}

/**
 * 单元格编辑信息
 */
export class CellEditInfo {
  rowIndex: number = -1;
  column: string = '';
  originalValue: string | null = '';
  editValue: string = '';
  isNull: boolean = false;

  constructor(rowIndex: number, column: string, originalValue: string | null) {
    this.rowIndex = rowIndex;
    this.column = column;
    this.originalValue = originalValue;
    this.editValue = originalValue ?? '';
    this.isNull = originalValue === null;
  }
}

/**
 * 行变更信息
 */
export class RowChangeInfo {
  rowIndex: number = -1;
  type: 'insert' | 'update' | 'delete' = 'update';
  changes: Map<string, CellChange> = new Map();
  originalRowData: Map<string, string | null> = new Map();

  constructor(rowIndex: number, type: 'insert' | 'update' | 'delete') {
    this.rowIndex = rowIndex;
    this.type = type;
  }
}

/**
 * 编辑状态追踪器
 */
export class TableEditState {
  // 是否处于编辑模式
  isEditing: boolean = false;
  // 当前编辑的单元格
  currentEdit: CellEditInfo | null = null;
  // 所有变更的行
  changedRows: Map<number, RowChangeInfo> = new Map();
  // 新增的行（还未插入数据库）
  newRows: RowChangeInfo[] = [];
  // 待删除的行索引
  deletedRowIndices: number[] = [];

  /**
   * 开始编辑单元格
   */
  startEdit(rowIndex: number, column: string, originalValue: string | null): void {
    this.currentEdit = new CellEditInfo(rowIndex, column, originalValue);
    this.isEditing = true;
  }

  /**
   * 更新编辑值
   */
  updateEditValue(value: string): void {
    if (this.currentEdit) {
      this.currentEdit.editValue = value;
      this.currentEdit.isNull = false;
    }
  }

  /**
   * 切换NULL值
   */
  toggleNull(): void {
    if (this.currentEdit) {
      this.currentEdit.isNull = !this.currentEdit.isNull;
    }
  }

  /**
   * 保存编辑
   */
  saveEdit(): void {
    if (!this.currentEdit) return;

    const rowIndex = this.currentEdit.rowIndex;
    const column = this.currentEdit.column;
    const originalValue = this.currentEdit.originalValue;
    const editValue = this.currentEdit.editValue;
    const isNull = this.currentEdit.isNull;
    const newValue = isNull ? null : editValue;

    // 跳过没有变化的值
    if (originalValue === newValue) {
      this.cancelEdit();
      return;
    }

    // 获取或创建行变更信息
    let changeInfo = this.changedRows.get(rowIndex);
    if (!changeInfo) {
      changeInfo = new RowChangeInfo(rowIndex, 'update');
      this.changedRows.set(rowIndex, changeInfo);
    }

    // 记录变更
    const cellChange = new CellChange(originalValue, newValue);
    changeInfo.changes.set(column, cellChange);

    this.cancelEdit();
  }

  /**
   * 取消编辑
   */
  cancelEdit(): void {
    this.currentEdit = null;
    this.isEditing = false;
  }

  /**
   * 准备插入新行
   */
  prepareInsert(columns: string[]): RowChangeInfo {
    const newRow = new RowChangeInfo(-1, 'insert');
    // 初始化所有列为空值
    for (let i = 0; i < columns.length; i++) {
      const col = columns[i];
      const cellChange = new CellChange(null, '');
      newRow.changes.set(col, cellChange);
    }
    this.newRows.push(newRow);
    return newRow;
  }

  /**
   * 删除行
   */
  markDelete(rowIndex: number): void {
    if (!this.deletedRowIndices.includes(rowIndex)) {
      this.deletedRowIndices.push(rowIndex);
    }
  }

  /**
   * 取消删除标记
   */
  unmarkDelete(rowIndex: number): void {
    const idx = this.deletedRowIndices.indexOf(rowIndex);
    if (idx >= 0) {
      this.deletedRowIndices.splice(idx, 1);
    }
  }

  /**
   * 检查是否有未保存的更改
   */
  hasChanges(): boolean {
    return this.changedRows.size > 0 || this.newRows.length > 0 || this.deletedRowIndices.length > 0;
  }

  /**
   * 获取变更数量
   */
  getChangeCount(): number {
    return this.changedRows.size + this.newRows.length + this.deletedRowIndices.length;
  }

  /**
   * 清除所有更改
   */
  clearAll(): void {
    this.changedRows.clear();
    this.newRows = [];
    this.deletedRowIndices = [];
    this.cancelEdit();
  }

  /**
   * 生成UPDATE SQL
   */
  generateUpdateSql(tableName: string, columns: string[], rowData: Map<string, string | null>, rowIndex: number): string | null {
    const changeInfo = this.changedRows.get(rowIndex);
    if (!changeInfo) return null;

    const sets: string[] = [];
    const changeKeys = Array.from(changeInfo.changes.keys());
    for (const col of changeKeys) {
      const change = changeInfo.changes.get(col);
      if (change && change.newValue === null) {
        sets.push(`${col} = NULL`);
      } else if (change) {
        sets.push(`${col} = '${this.escapeSqlValue(String(change.newValue))}'`);
      }
    }

    if (sets.length === 0) return null;

    // 构建WHERE条件
    const whereParts: string[] = [];
    for (let i = 0; i < columns.length; i++) {
      const col = columns[i];
      const val = rowData.get(col);
      if (val === null) {
        whereParts.push(`${col} IS NULL`);
      } else {
        whereParts.push(`${col} = '${this.escapeSqlValue(String(val))}'`);
      }
    }

    return `UPDATE ${tableName} SET ${sets.join(', ')} WHERE ${whereParts.join(' AND ')}`;
  }

  /**
   * 生成DELETE SQL
   */
  generateDeleteSql(tableName: string, columns: string[], rowData: Map<string, string | null>, rowIndex: number): string {
    const whereParts: string[] = [];
    for (let i = 0; i < columns.length; i++) {
      const col = columns[i];
      const val = rowData.get(col);
      if (val === null) {
        whereParts.push(`${col} IS NULL`);
      } else {
        whereParts.push(`${col} = '${this.escapeSqlValue(String(val))}'`);
      }
    }

    return `DELETE FROM ${tableName} WHERE ${whereParts.join(' AND ')}`;
  }

  /**
   * 生成INSERT SQL
   */
  generateInsertSql(newRow: RowChangeInfo, tableName: string): string | null {
    if (newRow.type !== 'insert') return null;

    const columns: string[] = [];
    const values: string[] = [];

    const changeKeys = Array.from(newRow.changes.keys());
    for (const col of changeKeys) {
      const change = newRow.changes.get(col);
      if (change) {
        if (change.newValue !== '' && change.newValue !== null) {
          columns.push(col);
          values.push(`'${this.escapeSqlValue(String(change.newValue))}'`);
        } else if (change.newValue === null) {
          columns.push(col);
          values.push('NULL');
        }
      }
    }

    if (columns.length === 0) return null;

    return `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${values.join(', ')})`;
  }

  /**
   * 转义SQL值
   */
  private escapeSqlValue(value: string): string {
    return value.replace(/'/g, "''");
  }
}