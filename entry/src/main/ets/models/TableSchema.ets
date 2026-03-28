/**
 * TableSchema - 表结构模型
 * PanoDB Project
 */

/**
 * 列信息
 */
export class ColumnInfo {
  name: string = '';
  type: string = 'TEXT';
  isPrimaryKey: boolean = false;
  isNotNull: boolean = false;
  isUnique: boolean = false;
  defaultValue: string = '';
  autoIncrement: boolean = false;

  constructor(name: string = '', type: string = 'TEXT') {
    this.name = name;
    this.type = type;
  }

  /**
   * 复制列信息
   */
  clone(): ColumnInfo {
    const col = new ColumnInfo(this.name, this.type);
    col.isPrimaryKey = this.isPrimaryKey;
    col.isNotNull = this.isNotNull;
    col.isUnique = this.isUnique;
    col.defaultValue = this.defaultValue;
    col.autoIncrement = this.autoIncrement;
    return col;
  }
}

/**
 * 索引信息
 */
export class IndexInfo {
  name: string = '';
  columns: string[] = [];
  isUnique: boolean = false;

  constructor(name: string = '') {
    this.name = name;
  }
}

/**
 * 表结构定义
 */
export class TableSchema {
  name: string = '';
  columns: ColumnInfo[] = [];
  indexes: IndexInfo[] = [];
  ifNotExists: boolean = true;
  temporary: boolean = false;

  /**
   * 生成 CREATE TABLE SQL
   */
  generateCreateSql(): string {
    if (!this.name || this.columns.length === 0) {
      return '';
    }

    const parts: string[] = [];
    const colDefs: string[] = [];
    const primaryKeys: string[] = [];

    // 列定义
    for (let i = 0; i < this.columns.length; i++) {
      const col = this.columns[i];
      if (!col.name) continue;

      const colParts: string[] = [col.name, col.type];

      if (col.isPrimaryKey) {
        primaryKeys.push(col.name);
      }

      if (col.isNotNull) {
        colParts.push('NOT NULL');
      }

      if (col.isUnique && !col.isPrimaryKey) {
        colParts.push('UNIQUE');
      }

      if (col.defaultValue) {
        colParts.push('DEFAULT', col.defaultValue);
      }

      if (col.autoIncrement) {
        colParts.push('AUTOINCREMENT');
      }

      colDefs.push(colParts.join(' '));
    }

    // 主键
    if (primaryKeys.length > 0) {
      colDefs.push(`PRIMARY KEY (${primaryKeys.join(', ')})`);
    }

    let sql = 'CREATE TABLE';
    if (this.ifNotExists) {
      sql += ' IF NOT EXISTS';
    }
    if (this.temporary) {
      sql += ' TEMPORARY';
    }
    sql += ` ${this.name} (${colDefs.join(', ')})`;

    return sql;
  }

  /**
   * 生成 CREATE INDEX SQL
   */
  generateIndexSql(): string[] {
    const sqls: string[] = [];
    for (let i = 0; i < this.indexes.length; i++) {
      const idx = this.indexes[i];
      if (!idx.name || idx.columns.length === 0) continue;

      let sql = 'CREATE INDEX';
      if (idx.isUnique) {
        sql = 'CREATE UNIQUE INDEX';
      }
      sql += ` IF NOT EXISTS ${idx.name} ON ${this.name} (${idx.columns.join(', ')})`;
      sqls.push(sql);
    }
    return sqls;
  }
}

/**
 * SQLite 支持的数据类型
 */
export const SQLITE_TYPES: string[] = [
  'TEXT',
  'INTEGER',
  'REAL',
  'BLOB',
  'NUMERIC',
  'VARCHAR',
  'CHAR',
  'BOOLEAN',
  'DATE',
  'DATETIME',
  'TIMESTAMP'
];

/**
 * 列类型默认约束
 */
export class ColumnTypeDefault {
  notNull: boolean = false;
  primaryKey: boolean = false;

  constructor(notNull: boolean, primaryKey: boolean) {
    this.notNull = notNull;
    this.primaryKey = primaryKey;
  }
}

/**
 * 常用列类型及其默认约束
 */
export const COLUMN_TYPE_DEFAULTS: Record<string, ColumnTypeDefault> = {
  'INTEGER': new ColumnTypeDefault(false, false),
  'TEXT': new ColumnTypeDefault(false, false),
  'REAL': new ColumnTypeDefault(false, false),
  'BLOB': new ColumnTypeDefault(false, false)
};