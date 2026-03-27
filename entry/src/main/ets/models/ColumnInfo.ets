/**
 * ColumnInfo - 列信息模型
 * PanoDB Project
 */

export class ColumnInfo {
  name: string = '';
  dataType: string = '';
  notNull: boolean = false;
  primaryKey: boolean = false;
  defaultValue?: string = '';
}

export class ColumnDetail extends ColumnInfo {
  tableName: string = '';
  ordinalPosition?: number = 0;
}

/**
 * SQLite数据类型
 */
export class SqliteDataTypes {
  static readonly INTEGER: string = 'INTEGER';
  static readonly TEXT: string = 'TEXT';
  static readonly REAL: string = 'REAL';
  static readonly BLOB: string = 'BLOB';
  static readonly NUMERIC: string = 'NUMERIC';
  static readonly VARCHAR: string = 'VARCHAR';
  static readonly CHAR: string = 'CHAR';
  static readonly DATE: string = 'DATE';
  static readonly DATETIME: string = 'DATETIME';
}
