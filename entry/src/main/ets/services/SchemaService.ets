/**
 * SchemaService - Schema服务
 * 提供数据库Schema信息的查询和管理
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import DatabaseService from './DatabaseService';
import { TableInfo, TableBasicInfo } from '../models/TableInfo';
import { ColumnInfo } from '../models/ColumnInfo';
import { IndexInfo } from '../models/IndexInfo';
import { TableRow, TableRowImpl } from '../models/QueryResult';

const DOMAIN = 0xFF03;

/**
 * 从TableRow获取SQL列的值
 */
function getSqlFromRow(row: TableRow): string | null {
  if (row instanceof TableRowImpl) {
    const value = row.getValue('sql');
    return typeof value === 'string' ? value : null;
  }
  return null;
}

export class DatabaseSchema {
  databaseName: string = '';
  tables: TableInfo[] = [];
  views: TableInfo[] = [];
  indexes: IndexInfo[] = [];
  lastUpdated: number = 0;
}

class SchemaService {
  private cachedSchema: DatabaseSchema | null = null;
  private schemaListeners: Array<(schema: DatabaseSchema) => void> = [];

  /**
   * 获取完整数据库Schema
   */
  async getDatabaseSchema(): Promise<DatabaseSchema> {
    const dbPath = DatabaseService.getCurrentDatabase();
    if (!dbPath) {
      hilog.error(DOMAIN, 'SchemaService', 'No database is currently open');
      const schema = new DatabaseSchema();
      schema.databaseName = '';
      return schema;
    }

    // 获取所有表和视图
    const allTables = await DatabaseService.getTables();

    // 分类表和视图
    const tables: TableInfo[] = [];
    const views: TableInfo[] = [];
    for (let i = 0; i < allTables.length; i++) {
      const t = allTables[i];
      if (t.type === 'table') {
        tables.push(t);
      } else if (t.type === 'view') {
        views.push(t);
      }
    }

    // 获取所有索引
    const indexes = await DatabaseService.getIndexes();

    const schema = new DatabaseSchema();
    schema.databaseName = this.extractDbName(dbPath);
    schema.tables = tables;
    schema.views = views;
    schema.indexes = indexes;
    schema.lastUpdated = Date.now();

    this.cachedSchema = schema;
    hilog.info(DOMAIN, 'SchemaService', 'Schema loaded: %{public}d tables, %{public}d views',
      tables.length, views.length);

    return schema;
  }

  /**
   * 从路径提取数据库名称
   */
  private extractDbName(path: string): string {
    const parts = path.split('/');
    const fileName = parts[parts.length - 1];
    return fileName.replace(/\.(db|sqlite|sqlite3)$/i, '') || 'database';
  }

  /**
   * 获取缓存的Schema
   */
  getCachedSchema(): DatabaseSchema | null {
    return this.cachedSchema;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.cachedSchema = null;
    hilog.info(DOMAIN, 'SchemaService', 'Schema cache cleared');
  }

  /**
   * 获取表的建表语句
   */
  async getTableDDL(tableName: string): Promise<string> {
    const result = await DatabaseService.executeSql(
      `SELECT sql FROM sqlite_master WHERE type='table' AND name='${tableName}'`
    );

    if (result.success && result.rows.length > 0) {
      const firstRow = result.rows[0];
      const sql = getSqlFromRow(firstRow);
      if (typeof sql === 'string' && sql.length > 0) {
        return sql;
      }
    }

    // 如果没有DDL，尝试构建
    const columns = await DatabaseService.getColumns(tableName);
    let ddl = `CREATE TABLE ${tableName} (\n`;

    const columnDefs: string[] = [];
    for (let i = 0; i < columns.length; i++) {
      const col = columns[i];
      let def = `  ${col.name} ${col.dataType}`;
      if (col.notNull) {
        def += ' NOT NULL';
      }
      if (col.primaryKey) {
        def += ' PRIMARY KEY';
      }
      if (col.defaultValue) {
        def += ` DEFAULT ${col.defaultValue}`;
      }
      columnDefs.push(def);
    }

    ddl += columnDefs.join(',\n');
    ddl += '\n)';

    return ddl;
  }

  /**
   * 获取视图的创建语句
   */
  async getViewDDL(viewName: string): Promise<string> {
    const result = await DatabaseService.executeSql(
      `SELECT sql FROM sqlite_master WHERE type='view' AND name='${viewName}'`
    );

    if (result.success && result.rows.length > 0) {
      const firstRow = result.rows[0];
      const sql = getSqlFromRow(firstRow);
      if (typeof sql === 'string') {
        return sql;
      }
    }

    return '';
  }

  /**
   * 获取表的基本信息（不含列详情）
   */
  async getTableBasicInfo(): Promise<TableBasicInfo[]> {
    const tables = await DatabaseService.getTables();
    const result: TableBasicInfo[] = [];
    for (let i = 0; i < tables.length; i++) {
      const t = tables[i];
      const basic = new TableBasicInfo();
      basic.name = t.name;
      basic.type = t.type;
      basic.rowCount = t.rowCount;
      result.push(basic);
    }
    return result;
  }

  /**
   * 刷新Schema缓存
   */
  async refresh(): Promise<DatabaseSchema> {
    this.clearCache();
    return await this.getDatabaseSchema();
  }

  /**
   * 注册Schema变化监听器
   */
  onSchemaChange(listener: (schema: DatabaseSchema) => void): () => void {
    this.schemaListeners.push(listener);
    return () => {
      const index = this.schemaListeners.indexOf(listener);
      if (index > -1) {
        this.schemaListeners.splice(index, 1);
      }
    };
  }

  /**
   * 通知Schema变化
   */
  private notifySchemaChange(): void {
    if (this.cachedSchema) {
      const len = this.schemaListeners.length;
      for (let i = 0; i < len; i++) {
        this.schemaListeners[i](this.cachedSchema);
      }
    }
  }
}

export default new SchemaService();
