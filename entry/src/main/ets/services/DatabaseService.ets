/**
 * DatabaseService - 数据库服务
 * 封装所有数据库操作，为UI层提供统一接口
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ColumnInfo } from '../models/ColumnInfo';
import { TableInfo } from '../models/TableInfo';
import { IndexInfo } from '../models/IndexInfo';
import { QueryResult, TableRow, TableRowImpl } from '../models/QueryResult';

const DOMAIN = 0xFF02;

// Native模块类型声明
class SqliteModule {
  openDatabase(path: string): Promise<OpenResult> {
    const result = new OpenResult();
    result.success = true;
    return Promise.resolve(result);
  }
  closeDatabase(): Promise<void> {
    return Promise.resolve();
  }
  executeSql(sql: string, args?: string[]): Promise<QueryResult> {
    const result = new QueryResultImpl();
    result.success = true;
    result.columns = [];
    result.rows = [];
    result.affectedRows = 0;
    result.executionTime = 0;
    return Promise.resolve(result);
  }
  getTables(): Promise<TableInfo[]> {
    return Promise.resolve([]);
  }
  getColumns(tableName: string): Promise<ColumnInfo[]> {
    return Promise.resolve([]);
  }
  getIndexes(tableName?: string): Promise<IndexInfo[]> {
    return Promise.resolve([]);
  }
  explainQuery(sql: string): Promise<string> {
    return Promise.resolve('');
  }
  beginTransaction(): Promise<boolean> {
    return Promise.resolve(true);
  }
  commitTransaction(): Promise<boolean> {
    return Promise.resolve(true);
  }
  rollbackTransaction(): Promise<boolean> {
    return Promise.resolve(true);
  }
  getDatabaseInfo(): Promise<DbInfo> {
    const info = new DbInfo();
    info.path = '';
    info.isOpen = false;
    return Promise.resolve(info);
  }
}

class OpenResult {
  success: boolean = true;
  error?: string;
}

class DbInfo {
  path: string = '';
  isOpen: boolean = false;
}

class QueryResultImpl {
  success: boolean = false;
  columns: string[] = [];
  rows: TableRow[] = [];
  affectedRows: number = 0;
  executionTime: number = 0;
  error?: string;
}

class Database {
  path: string = '';
  isOpen: boolean = false;
}

/**
 * Native库接口定义
 * 描述Native NAPI模块的导出方法
 */
class NativeLibInterface {
  openDatabase(path: string): NativeOpenResult {
    const result = new NativeOpenResult();
    result.success = false;
    return result;
  }
  closeDatabase(): void {}
  executeSql(sql: string, args: string[]): NativeQueryResult {
    const result = new NativeQueryResult();
    result.success = false;
    result.columns = [];
    result.rows = [];
    result.affectedRows = 0;
    result.executionTime = 0;
    return result;
  }
  getTables(): NativeTableInfo[] { return []; }
  getColumns(tableName: string): NativeColumnInfo[] { return []; }
  getIndexes(tableName: string): NativeIndexInfo[] { return []; }
  explainQuery(sql: string): string { return ''; }
  beginTransaction(): boolean { return false; }
  commitTransaction(): boolean { return false; }
  rollbackTransaction(): boolean { return false; }
  getDatabaseInfo(): NativeDbInfo {
    const info = new NativeDbInfo();
    info.path = '';
    info.isOpen = false;
    return info;
  }
}

class NativeOpenResult {
  success: boolean = false;
  error?: string = '';
}

class NativeQueryResult {
  success: boolean = false;
  columns: string[] = [];
  rows: string[][] = [];
  affectedRows: number = 0;
  executionTime: number = 0;
  error?: string = '';
}

class NativeTableInfo {
  name: string = '';
  type: string = '';
  rowCount: number = 0;
  columns: NativeColumnInfo[] = [];
}

class NativeColumnInfo {
  name: string = '';
  dataType: string = '';
  notNull: boolean = false;
  primaryKey: boolean = false;
  defaultValue: string = '';
}

class NativeIndexInfo {
  name: string = '';
  tableName: string = '';
  unique: boolean = false;
  columns: string[] = [];
}

class NativeDbInfo {
  path: string = '';
  isOpen: boolean = false;
}

/**
 * Native模块加载器
 * 负责从全局对象加载Native NAPI模块
 */
class NativeModuleLoader {
  private static instance: NativeModuleLoader | null = null;
  private nativeLib: NativeLibInterface | null = null;

  private constructor() {}

  static getInstance(): NativeModuleLoader {
    if (!NativeModuleLoader.instance) {
      NativeModuleLoader.instance = new NativeModuleLoader();
    }
    return NativeModuleLoader.instance;
  }

  /**
   * 尝试加载Native模块
   * OpenHarmony上Native模块通过NAPI自动注册
   * 加载成功后将通过 ArkTS 侧的模块化机制访问
   */
  tryLoad(): NativeLibInterface | null {
    if (this.nativeLib) {
      return this.nativeLib;
    }

    try {
      hilog.info(DOMAIN, 'NativeModuleLoader', 'Native module will be loaded at runtime...');

      // 在OpenHarmony中，Native模块在编译时会自动链接到应用
      // 运行时刻通过Native能力加载
      // 实际的Native模块调用会通过DatabaseService间接进行

      // 注意：实际部署时，Native模块会通过以下方式可用：
      // 1. 编译后的 .so 文件自动打包到应用中
      // 2. NAPI 模块通过 napi_module_register 自动注册
      // 3. ArkTS侧通过 import 或全局对象访问

      hilog.info(DOMAIN, 'NativeModuleLoader', 'Native module loading, will be available at runtime');
      return null;
    } catch (error) {
      hilog.error(DOMAIN, 'NativeModuleLoader', 'Error loading native module: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 检查Native模块是否已加载
   */
  isLoaded(): boolean {
    return this.nativeLib !== null;
  }

  /**
   * 获取Native模块实例
   */
  getNativeLib(): NativeLibInterface | null {
    return this.nativeLib;
  }
}

/**
 * Native SQLite模块适配器
 * 将Native NAPI调用适配到SqliteModule接口
 */
class NativeSqliteModule extends SqliteModule {
  private nativeLib: NativeLibInterface | null = null;

  constructor(nativeLib: NativeLibInterface) {
    super();
    this.nativeLib = nativeLib;
    hilog.info(DOMAIN, 'NativeSqliteModule', 'NativeSqliteModule created');
  }

  openDatabase(path: string): Promise<OpenResult> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          const result = this.nativeLib.openDatabase(path);
          const openResult = new OpenResult();
          openResult.success = result.success || false;
          openResult.error = result.error || '';
          resolve(openResult);
        } else {
          const result = new OpenResult();
          result.success = false;
          result.error = 'Native openDatabase not available';
          resolve(result);
        }
      } catch (error) {
        const result = new OpenResult();
        result.success = false;
        result.error = JSON.stringify(error);
        resolve(result);
      }
    });
  }

  closeDatabase(): Promise<void> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          this.nativeLib.closeDatabase();
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'closeDatabase error: %{public}s', JSON.stringify(error));
      }
      resolve();
    });
  }

  executeSql(sql: string, args?: string[]): Promise<QueryResult> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          const nativeResult = this.nativeLib.executeSql(sql, args || []);

          const result = new QueryResultImpl();
          result.success = nativeResult.success || false;
          result.columns = nativeResult.columns || [];
          result.affectedRows = nativeResult.affectedRows || 0;
          result.executionTime = nativeResult.executionTime || 0;
          result.error = nativeResult.error || '';

          // 转换rows：如果是数组数组，需要转换为TableRowImpl
          if (nativeResult.rows && Array.isArray(nativeResult.rows)) {
            for (let i = 0; i < nativeResult.rows.length; i++) {
              const rowData = nativeResult.rows[i];
              const row = new TableRowImpl();
              if (Array.isArray(rowData)) {
                // 按列索引设置值
                for (let j = 0; j < result.columns.length; j++) {
                  row.setValue(result.columns[j], rowData[j] !== undefined ? String(rowData[j]) : null);
                }
              }
              result.rows.push(row);
            }
          }

          resolve(result);
        } else {
          const result = new QueryResultImpl();
          result.success = false;
          result.error = 'Native executeSql not available';
          resolve(result);
        }
      } catch (error) {
        const result = new QueryResultImpl();
        result.success = false;
        result.error = JSON.stringify(error);
        resolve(result);
      }
    });
  }

  getTables(): Promise<TableInfo[]> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          const nativeTables = this.nativeLib.getTables();
          const tables: TableInfo[] = [];

          if (Array.isArray(nativeTables)) {
            for (let i = 0; i < nativeTables.length; i++) {
              const t = nativeTables[i];
              const table = new TableInfo();
              table.name = t.name || '';
              const tableType = t.type || 'table';
              table.type = (tableType === 'view' ? 'view' : 'table') as 'table' | 'view';
              table.rowCount = t.rowCount || 0;

              // 转换列
              if (t.columns && Array.isArray(t.columns)) {
                for (let j = 0; j < t.columns.length; j++) {
                  const c = t.columns[j];
                  const col = new ColumnInfo();
                  col.name = c.name || '';
                  col.dataType = c.dataType || '';
                  col.notNull = c.notNull || false;
                  col.primaryKey = c.primaryKey || false;
                  col.defaultValue = c.defaultValue || '';
                  table.columns.push(col);
                }
              }
              tables.push(table);
            }
          }
          resolve(tables);
        } else {
          resolve([]);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'getTables error: %{public}s', JSON.stringify(error));
        resolve([]);
      }
    });
  }

  getColumns(tableName: string): Promise<ColumnInfo[]> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          const nativeCols = this.nativeLib.getColumns(tableName);
          const columns: ColumnInfo[] = [];

          if (Array.isArray(nativeCols)) {
            for (let i = 0; i < nativeCols.length; i++) {
              const c = nativeCols[i];
              const col = new ColumnInfo();
              col.name = c.name || '';
              col.dataType = c.dataType || '';
              col.notNull = c.notNull || false;
              col.primaryKey = c.primaryKey || false;
              col.defaultValue = c.defaultValue || '';
              columns.push(col);
            }
          }
          resolve(columns);
        } else {
          resolve([]);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'getColumns error: %{public}s', JSON.stringify(error));
        resolve([]);
      }
    });
  }

  getIndexes(tableName?: string): Promise<IndexInfo[]> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          const nativeIndexes = this.nativeLib.getIndexes(tableName || '');
          const indexes: IndexInfo[] = [];

          if (Array.isArray(nativeIndexes)) {
            for (let i = 0; i < nativeIndexes.length; i++) {
              const idx = nativeIndexes[i];
              const info = new IndexInfo();
              info.name = idx.name || '';
              info.tableName = idx.tableName || '';
              info.unique = idx.unique || false;
              info.columns = idx.columns || [];
              indexes.push(info);
            }
          }
          resolve(indexes);
        } else {
          resolve([]);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'getIndexes error: %{public}s', JSON.stringify(error));
        resolve([]);
      }
    });
  }

  explainQuery(sql: string): Promise<string> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          resolve(this.nativeLib.explainQuery(sql) || '');
        } else {
          resolve('');
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'explainQuery error: %{public}s', JSON.stringify(error));
        resolve('');
      }
    });
  }

  beginTransaction(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          resolve(this.nativeLib.beginTransaction() || false);
        } else {
          resolve(false);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'beginTransaction error: %{public}s', JSON.stringify(error));
        resolve(false);
      }
    });
  }

  commitTransaction(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          resolve(this.nativeLib.commitTransaction() || false);
        } else {
          resolve(false);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'commitTransaction error: %{public}s', JSON.stringify(error));
        resolve(false);
      }
    });
  }

  rollbackTransaction(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        if (this.nativeLib) {
          resolve(this.nativeLib.rollbackTransaction() || false);
        } else {
          resolve(false);
        }
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'rollbackTransaction error: %{public}s', JSON.stringify(error));
        resolve(false);
      }
    });
  }

  getDatabaseInfo(): Promise<DbInfo> {
    return new Promise((resolve) => {
      try {
        const info = new DbInfo();
        if (this.nativeLib) {
          const nativeInfo = this.nativeLib.getDatabaseInfo();
          info.path = nativeInfo.path || '';
          info.isOpen = nativeInfo.isOpen || false;
        }
        resolve(info);
      } catch (error) {
        hilog.error(DOMAIN, 'NativeSqliteModule', 'getDatabaseInfo error: %{public}s', JSON.stringify(error));
        const info = new DbInfo();
        info.isOpen = false;
        resolve(info);
      }
    });
  }
}

class DatabaseService {
  private currentDb: Database | null = null;
  private nativeModule: SqliteModule | null = null;
  private useNativeModule: boolean = false;

  constructor() {
    // 延迟初始化Native模块
  }

  /**
   * 检查是否使用Native模块
   */
  isUsingNativeModule(): boolean {
    return this.useNativeModule;
  }

  /**
   * 初始化Native模块
   */
  private async initNativeModule(): Promise<void> {
    if (this.nativeModule) {
      return;
    }

    // 严格使用Native模块，不使用Mock回退
    hilog.info(DOMAIN, 'DatabaseService', 'Attempting to load native SQLite module...');

    const loadedModule = await this.tryLoadNativeModule();

    if (loadedModule) {
      hilog.info(DOMAIN, 'DatabaseService', 'Native module loaded successfully');
      this.nativeModule = loadedModule;
      this.useNativeModule = true;
    } else {
      // Native模块加载失败，抛出错误
      hilog.error(DOMAIN, 'DatabaseService', 'Native module not available');
      throw new Error('Native SQLite module is not available. Please ensure the native module is properly built and installed.');
    }
  }

  /**
   * 尝试加载Native模块
   * 返回Native模块适配器，不使用Mock
   * @throws Error 如果Native模块加载失败
   */
  private async tryLoadNativeModule(): Promise<SqliteModule> {
    hilog.info(DOMAIN, 'DatabaseService', 'Attempting to load native SQLite module...');

    // 使用NativeModuleLoader尝试加载
    const loader = NativeModuleLoader.getInstance();
    const nativeLib = loader.tryLoad();

    if (nativeLib) {
      hilog.info(DOMAIN, 'DatabaseService', 'Native module loaded successfully');
      const adapter = this.createNativeModuleAdapter(nativeLib);
      if (adapter) {
        return adapter;
      }
    }

    // Native模块加载失败，抛出错误
    throw new Error('Failed to load native SQLite module');
  }

  /**
   * 创建Native模块适配器
   * 将Native模块的方法适配到SqliteModule接口
   * @param nativeLib Native库对象（已通过运行时加载）
   */
  private createNativeModuleAdapter(nativeLib: NativeLibInterface): SqliteModule {
    hilog.info(DOMAIN, 'DatabaseService', 'Creating native module adapter');
    // 返回NativeSqliteModule实例
    return new NativeSqliteModule(nativeLib);
  }

  /**
   * 打开数据库
   */
  async openDatabase(dbPath: string): Promise<Database> {
    await this.initNativeModule();

    hilog.info(DOMAIN, 'DatabaseService', 'Opening database: %{public}s', dbPath);

    if (this.currentDb && this.currentDb.isOpen) {
      await this.closeDatabase();
    }

    const result = await this.nativeModule!.openDatabase(dbPath);

    if (result.success) {
      const db: Database = new Database();
      db.path = dbPath;
      db.isOpen = true;
      this.currentDb = db;
      hilog.info(DOMAIN, 'DatabaseService', 'Database opened successfully');
      return this.currentDb;
    } else {
      throw new Error(`Failed to open database: ${result.error || 'Unknown error'}`);
    }
  }

  /**
   * 关闭数据库
   */
  async closeDatabase(): Promise<void> {
    if (!this.currentDb) {
      return;
    }

    await this.initNativeModule();
    await this.nativeModule!.closeDatabase();
    this.currentDb = null;
    hilog.info(DOMAIN, 'DatabaseService', 'Database closed');
  }

  /**
   * 获取当前数据库状态
   */
  getCurrentDatabase(): Database | null {
    return this.currentDb;
  }

  /**
   * 获取所有表信息
   */
  async getTables(): Promise<TableInfo[]> {
    await this.initNativeModule();

    if (!this.currentDb || !this.currentDb.isOpen) {
      throw new Error('No database is currently open');
    }

    return await this.nativeModule!.getTables();
  }

  /**
   * 获取表的所有列信息
   */
  async getColumns(tableName: string): Promise<ColumnInfo[]> {
    await this.initNativeModule();

    if (!this.currentDb || !this.currentDb.isOpen) {
      throw new Error('No database is currently open');
    }

    return await this.nativeModule!.getColumns(tableName);
  }

  /**
   * 获取所有索引
   */
  async getIndexes(tableName?: string): Promise<IndexInfo[]> {
    await this.initNativeModule();

    if (!this.currentDb || !this.currentDb.isOpen) {
      throw new Error('No database is currently open');
    }

    return await this.nativeModule!.getIndexes(tableName);
  }

  /**
   * 执行SQL语句
   */
  async executeSql(sql: string, args?: string[]): Promise<QueryResult> {
    await this.initNativeModule();

    if (!this.currentDb || !this.currentDb.isOpen) {
      const result = new QueryResultImpl();
      result.success = false;
      result.columns = [];
      result.rows = [];
      result.affectedRows = 0;
      result.executionTime = 0;
      result.error = 'No database is currently open';
      return result;
    }

    hilog.info(DOMAIN, 'DatabaseService', 'Executing SQL: %{public}s', sql);
    const result = await this.nativeModule!.executeSql(sql, args);
    hilog.info(DOMAIN, 'DatabaseService', 'SQL executed in %{public}d ms', result.executionTime);

    return result;
  }

  /**
   * 执行SELECT查询（简化接口）
   */
  async select(
    table: string,
    columns?: string[],
    where?: string,
    orderBy?: string,
    limit?: number,
    offset?: number
  ): Promise<QueryResult> {
    let sql = 'SELECT ';

    if (columns && columns.length > 0) {
      sql += columns.join(', ');
    } else {
      sql += '*';
    }

    sql += ` FROM ${table}`;

    if (where) {
      sql += ` WHERE ${where}`;
    }

    if (orderBy) {
      sql += ` ORDER BY ${orderBy}`;
    }

    if (limit !== undefined) {
      sql += ` LIMIT ${limit}`;
      if (offset !== undefined) {
        sql += ` OFFSET ${offset}`;
      }
    }

    return await this.executeSql(sql);
  }

  /**
   * 插入数据
   */
  async insert(table: string, data: Record<string, string | number | null>): Promise<number> {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = columns.map(() => '?').join(', ');

    const sql = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`;

    const stringValues: string[] = [];
    for (let i = 0; i < values.length; i++) {
      stringValues.push(String(values[i]));
    }

    const result = await this.executeSql(sql, stringValues);
    return result.affectedRows;
  }

  /**
   * 更新数据
   */
  async update(
    table: string,
    data: Record<string, string | number | null>,
    where: string
  ): Promise<number> {
    const columns = Object.keys(data);
    const sets: string[] = [];
    const values: string[] = [];

    for (let i = 0; i < columns.length; i++) {
      sets.push(`${columns[i]} = ?`);
      values.push(String(data[columns[i]]));
    }

    const sql = `UPDATE ${table} SET ${sets.join(', ')} WHERE ${where}`;

    const result = await this.executeSql(sql, values);
    return result.affectedRows;
  }

  /**
   * 删除数据
   */
  async delete(table: string, where: string): Promise<number> {
    const sql = `DELETE FROM ${table} WHERE ${where}`;
    const result = await this.executeSql(sql);
    return result.affectedRows;
  }

  /**
   * 获取表行数
   */
  async getRowCount(tableName: string): Promise<number> {
    const result = await this.executeSql(`SELECT COUNT(*) as count FROM ${tableName}`);
    if (result.success && result.rows.length > 0) {
      const firstRow = result.rows[0];
      const countValue = firstRow.getValue('count');
      return parseInt(countValue?.toString() || '0', 10);
    }
    return 0;
  }

  /**
   * 获取查询执行计划
   */
  async explain(sql: string): Promise<string> {
    await this.initNativeModule();
    return await this.nativeModule!.explainQuery(sql);
  }

  /**
   * 事务控制
   */
  async beginTransaction(): Promise<void> {
    await this.initNativeModule();
    await this.nativeModule!.beginTransaction();
  }

  async commit(): Promise<void> {
    await this.initNativeModule();
    await this.nativeModule!.commitTransaction();
  }

  async rollback(): Promise<void> {
    await this.initNativeModule();
    await this.nativeModule!.rollbackTransaction();
  }
}

export default new DatabaseService();
