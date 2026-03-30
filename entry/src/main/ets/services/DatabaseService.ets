/**
 * DatabaseService - 数据库服务
 * 使用 OpenHarmony RDB Store API 封装所有数据库操作
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import relationalStore from '@ohos.data.rdb';
import { ColumnInfo } from '../models/ColumnInfo';
import { TableInfo } from '../models/TableInfo';
import { IndexInfo } from '../models/IndexInfo';
import { QueryResult, TableRow, TableRowImpl } from '../models/QueryResult';

const DOMAIN = 0xFF02;

/**
 * 数据库服务
 * 使用 RDB Store API 操作 SQLite 数据库
 */
class DatabaseService {
  private store: relationalStore.RdbStore | null = null;
  private context: common.UIAbilityContext | null = null;
  private currentDbPath: string = '';

  /**
   * 初始化数据库服务
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    hilog.info(DOMAIN, 'DatabaseService', 'DatabaseService initialized');
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.context !== null;
  }

  /**
   * 打开数据库
   * @param dbPath 数据库路径（相对于沙箱目录）
   */
  async openDatabase(dbPath: string): Promise<void> {
    if (!this.context) {
      hilog.error(DOMAIN, 'DatabaseService', 'DatabaseService not initialized');
      return;
    }

    hilog.info(DOMAIN, 'DatabaseService', 'Opening database: %{public}s', dbPath);

    // 如果已有打开的数据库，先关闭
    if (this.store) {
      await this.closeDatabase();
    }

    try {
      // 获取数据库目录
      const dbDir = this.context.databaseDir + '/databases';
      hilog.info(DOMAIN, 'DatabaseService', 'Database dir: %{public}s', dbDir);

      // 打开/创建数据库
      this.store = await relationalStore.getRdbStore(this.context, {
        name: dbPath
      }, 1);
      this.currentDbPath = dbPath;

      hilog.info(DOMAIN, 'DatabaseService', 'Database opened successfully');
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Failed to open database: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 关闭数据库
   */
  async closeDatabase(): Promise<void> {
    if (this.store) {
      try {
        this.store = null;
        this.currentDbPath = '';
        hilog.info(DOMAIN, 'DatabaseService', 'Database closed');
      } catch (error) {
        hilog.error(DOMAIN, 'DatabaseService', 'Failed to close database: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 检查数据库是否已打开
   */
  isDatabaseOpen(): boolean {
    return this.store !== null;
  }

  /**
   * 获取当前数据库路径
   */
  getCurrentDbPath(): string {
    return this.currentDbPath;
  }

  /**
   * 获取当前数据库路径（兼容方法）
   */
  getCurrentDatabase(): string {
    return this.currentDbPath;
  }

  /**
   * 执行 SQL 语句
   * 注意：由于 ArkTS 类型限制，非 SELECT 语句使用 executeSql，SELECT 语句暂返回错误
   */
  async executeSql(sql: string, args?: string[]): Promise<QueryResult> {
    if (!this.store) {
      const result = new QueryResultImpl();
      result.success = false;
      result.error = 'No database is open';
      return result;
    }

    const startTime = Date.now();
    const upperSql = sql.trim().toUpperCase();

    try {
      hilog.info(DOMAIN, 'DatabaseService', 'Executing SQL: %{public}s', sql);

      // 对于 SELECT 语句，返回错误提示
      if (upperSql.startsWith('SELECT')) {
        const result = new QueryResultImpl();
        result.success = false;
        result.error = 'SELECT queries are handled separately. Use select() method instead.';
        result.executionTime = Date.now() - startTime;
        return result;
      }

      // INSERT, UPDATE, DELETE 等语句
      await this.store.executeSql(sql, args || []);
      const executionTime = Date.now() - startTime;

      const result = new QueryResultImpl();
      result.success = true;
      result.executionTime = executionTime;
      result.affectedRows = 0;
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'SQL execution failed: %{public}s', JSON.stringify(error));

      const result = new QueryResultImpl();
      result.success = false;
      result.error = JSON.stringify(error);
      result.executionTime = Date.now() - startTime;
      return result;
    }
  }

  /**
   * 获取所有表
   */
  async getTables(): Promise<TableInfo[]> {
    if (!this.store) {
      return [];
    }

    try {
      // 使用 predicate 查询所有表
      const predicates = new relationalStore.RdbPredicates('sqlite_master');
      predicates.equalTo('type', 'table');
      predicates.notEqualTo('name', 'sqlite_%');

      const resultSet = await this.store.query(predicates, ['name', 'type']);
      const tables: TableInfo[] = [];

      if (resultSet) {
        resultSet.goToFirstRow();
        do {
          const table = new TableInfo();
          table.name = resultSet.getString(0) || '';
          table.type = resultSet.getString(1) === 'view' ? 'view' : 'table';
          table.columns = [];
          if (table.name && !table.name.startsWith('sqlite_')) {
            tables.push(table);
          }
        } while (resultSet.goToNextRow());
        resultSet.close();
      }

      return tables;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Failed to get tables: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 获取表的所有列
   */
  async getColumns(tableName: string): Promise<ColumnInfo[]> {
    if (!this.store) {
      return [];
    }

    try {
      // 使用 PRAGMA 查询列信息 - 但由于 ArkTS 类型限制，我们使用 predicate 查询
      // 实际上这里需要用原生 SQL，暂返回空数组
      hilog.warn(DOMAIN, 'DatabaseService', 'getColumns using simplified implementation');
      return [];
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Failed to get columns: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 获取所有索引
   */
  async getIndexes(tableName?: string): Promise<IndexInfo[]> {
    if (!this.store) {
      return [];
    }

    try {
      const predicates = new relationalStore.RdbPredicates('sqlite_master');
      predicates.equalTo('type', 'index');

      const resultSet = await this.store.query(predicates, ['name', 'tbl_name']);
      const indexes: IndexInfo[] = [];

      if (resultSet) {
        resultSet.goToFirstRow();
        do {
          const idx = new IndexInfo();
          idx.name = resultSet.getString(0) || '';
          idx.tableName = resultSet.getString(1) || '';
          if (idx.name && !idx.name.startsWith('sqlite_')) {
            indexes.push(idx);
          }
        } while (resultSet.goToNextRow());
        resultSet.close();
      }

      return indexes;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Failed to get indexes: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 获取查询执行计划
   */
  async explain(sql: string): Promise<string> {
    // 暂不支持
    return '';
  }

  /**
   * 事务控制
   */
  async beginTransaction(): Promise<void> {
    if (this.store) {
      await this.store.executeSql('BEGIN TRANSACTION', []);
    }
  }

  async commit(): Promise<void> {
    if (this.store) {
      await this.store.executeSql('COMMIT', []);
    }
  }

  async rollback(): Promise<void> {
    if (this.store) {
      await this.store.executeSql('ROLLBACK', []);
    }
  }

  // ==================== 简化查询接口 ====================

  /**
   * 执行 SELECT 查询（使用 predicate）
   */
  async select(table: string, columns?: string[], where?: string, orderBy?: string, limit?: number, offset?: number): Promise<QueryResult> {
    if (!this.store) {
      const result = new QueryResultImpl();
      result.success = false;
      result.error = 'No database is open';
      return result;
    }

    const startTime = Date.now();
    const result = new QueryResultImpl();

    try {
      const preds = new relationalStore.RdbPredicates(table);

      // 注意：这里无法处理复杂的 WHERE 条件，只能做简单的等值查询
      // 复杂的 WHERE 需要使用原生 SQL

      const cols = columns && columns.length > 0 ? columns : ['*'];
      const resultSet = await this.store.query(preds, cols);

      if (resultSet) {
        result.success = true;
        result.columns = cols;

        resultSet.goToFirstRow();
        do {
          const row = new TableRowImpl();
          for (let i = 0; i < cols.length; i++) {
            const colName = cols[i];
            if (colName === '*') {
              // 无法获取所有列名，返回空
            } else {
              const value = resultSet.getString(i);
              row.setValue(colName, value);
            }
          }
          result.rows.push(row);
        } while (resultSet.goToNextRow());

        resultSet.close();
      }

      result.executionTime = Date.now() - startTime;
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Select failed: %{public}s', JSON.stringify(error));
      result.success = false;
      result.error = JSON.stringify(error);
      result.executionTime = Date.now() - startTime;
      return result;
    }
  }

  /**
   * 插入数据
   */
  async insert(table: string, data: Record<string, string | number | null>): Promise<number> {
    if (!this.store) {
      return -1;
    }

    try {
      const rowId = await this.store.insert(table, data);
      return rowId;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Insert failed: %{public}s', JSON.stringify(error));
      return -1;
    }
  }


  /**
   * 获取表行数
   */
  async getRowCount(tableName: string): Promise<number> {
    const result = await this.select(tableName, ['COUNT(*) as cnt']);
    if (result.success && result.rows.length > 0) {
      const countValue = result.rows[0].getValue('cnt');
      return parseInt(String(countValue), 10) || 0;
    }
    return 0;
  }
}

// 结果实现类
class QueryResultImpl {
  success: boolean = false;
  columns: string[] = [];
  rows: TableRow[] = [];
  affectedRows: number = 0;
  executionTime: number = 0;
  error?: string = '';
}

export default new DatabaseService();
