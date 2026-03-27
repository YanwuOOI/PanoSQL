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
interface NativeLibInterface {
  openDatabase(path: string): NativeOpenResult;
  closeDatabase(): void;
  executeSql(sql: string, args: string[]): NativeQueryResult;
  getTables(): NativeTableInfo[];
  getColumns(tableName: string): NativeColumnInfo[];
  getIndexes(tableName: string): NativeIndexInfo[];
  explainQuery(sql: string): string;
  beginTransaction(): boolean;
  commitTransaction(): boolean;
  rollbackTransaction(): boolean;
  getDatabaseInfo(): NativeDbInfo;
}

interface NativeOpenResult {
  success: boolean;
  error?: string;
}

interface NativeQueryResult {
  success: boolean;
  columns: string[];
  rows: string[][];
  affectedRows: number;
  executionTime: number;
  error?: string;
}

interface NativeTableInfo {
  name: string;
  type: string;
  rowCount: number;
  columns: NativeColumnInfo[];
}

interface NativeColumnInfo {
  name: string;
  dataType: string;
  notNull: boolean;
  primaryKey: boolean;
  defaultValue: string;
}

interface NativeIndexInfo {
  name: string;
  tableName: string;
  unique: boolean;
  columns: string[];
}

interface NativeDbInfo {
  path: string;
  isOpen: boolean;
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

    try {
      // 尝试加载Native模块
      hilog.info(DOMAIN, 'DatabaseService', 'Attempting to load native SQLite module...');

      // 尝试动态导入Native模块
      // 注意：在OpenHarmony上，Native模块通过特定机制加载
      const loadedModule = await this.tryLoadNativeModule();

      if (loadedModule) {
        hilog.info(DOMAIN, 'DatabaseService', 'Native module loaded successfully');
        this.nativeModule = loadedModule;
        this.useNativeModule = true;
      } else {
        hilog.info(DOMAIN, 'DatabaseService', 'Using mock module (native not available)');
        this.nativeModule = this.createMockModule();
        this.useNativeModule = false;
      }
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Failed to load native module: %{public}s',
        JSON.stringify(error));
      hilog.info(DOMAIN, 'DatabaseService', 'Falling back to mock module');
      this.nativeModule = this.createMockModule();
      this.useNativeModule = false;
    }
  }

  /**
   * 尝试加载Native模块
   * 返回null表示加载失败，使用mock
   *
   * 注意：OpenHarmony的Native模块加载机制需要运行时支持
   * 当前实现返回null使用Mock模块，待运行时机制完善后再启用
   */
  private async tryLoadNativeModule(): Promise<SqliteModule | null> {
    try {
      hilog.info(DOMAIN, 'DatabaseService', 'Attempting to load native SQLite module...');

      // OpenHarmony Native模块加载说明：
      // 在OpenHarmony中，Native模块通过NAPI方式导出
      // 编译后的.so文件需要放在特定目录
      // 加载方式可能通过：
      // 1. 全局符号导出（native模块自动注册）
      // 2. 延迟导入（使用装饰器或运行时绑定）
      //
      // 当前阶段：返回null使用Mock模块
      // 后续：需要根据OpenHarmony实际SDK来确定正确的加载方式

      hilog.info(DOMAIN, 'DatabaseService', 'Native module loading not yet implemented, using mock');
      return null;
    } catch (error) {
      hilog.error(DOMAIN, 'DatabaseService', 'Error loading native module: %{public}s',
        JSON.stringify(error));
      return null;
    }
  }

  /**
   * 创建Native模块适配器
   * 将Native模块的方法适配到SqliteModule接口
   * @param nativeLib Native库对象（已通过运行时加载）
   */
  private createNativeModuleAdapter(nativeLib: NativeLibInterface): SqliteModule | null {
    if (!nativeLib) {
      hilog.warn(DOMAIN, 'DatabaseService', 'Invalid native library');
      return null;
    }

    hilog.info(DOMAIN, 'DatabaseService', 'Creating native module adapter');

    // 返回NativeSqliteModule实例
    return new NativeSqliteModule(nativeLib);
  }

  /**
   * 创建Mock模块用于开发测试
   */
  private createMockModule(): SqliteModule {
    const self = this;

    class MockSqliteModule extends SqliteModule {
      private mockOpenResult: OpenResult = new OpenResult();
      private mockDbInfo: DbInfo = new DbInfo();
      private mockTables: TableInfo[] = [];
      private mockColumns: Map<string, ColumnInfo[]> = new Map();
      private mockIndexes: IndexInfo[] = [];
      private mockRows: TableRow[] = [];

      constructor() {
        super();
        this.initMockData();
      }

      private initMockData(): void {
        const mockCol1 = new ColumnInfo();
        mockCol1.name = 'id';
        mockCol1.dataType = 'INTEGER';
        mockCol1.notNull = true;
        mockCol1.primaryKey = true;

        const mockCol2 = new ColumnInfo();
        mockCol2.name = 'name';
        mockCol2.dataType = 'TEXT';
        mockCol2.notNull = false;
        mockCol2.primaryKey = false;

        const mockCol3 = new ColumnInfo();
        mockCol3.name = 'email';
        mockCol3.dataType = 'TEXT';
        mockCol3.notNull = false;
        mockCol3.primaryKey = false;

        const mockCol4 = new ColumnInfo();
        mockCol4.name = 'user_id';
        mockCol4.dataType = 'INTEGER';
        mockCol4.notNull = true;
        mockCol4.primaryKey = false;

        const mockCol5 = new ColumnInfo();
        mockCol5.name = 'amount';
        mockCol5.dataType = 'REAL';
        mockCol5.notNull = false;
        mockCol5.primaryKey = false;

        const mockTable1 = new TableInfo();
        mockTable1.name = 'users';
        mockTable1.type = 'table';
        mockTable1.rowCount = 100;
        mockTable1.columns = [mockCol1, mockCol2, mockCol3];

        const mockTable2 = new TableInfo();
        mockTable2.name = 'orders';
        mockTable2.type = 'table';
        mockTable2.rowCount = 50;
        mockTable2.columns = [mockCol1, mockCol4, mockCol5];

        this.mockTables = [mockTable1, mockTable2];
        this.mockColumns.set('users', [mockCol1, mockCol2, mockCol3]);
        this.mockColumns.set('orders', [mockCol1, mockCol4, mockCol5]);

        const mockIdx1 = new IndexInfo();
        mockIdx1.name = 'idx_users_email';
        mockIdx1.tableName = 'users';
        mockIdx1.unique = false;
        mockIdx1.columns = ['email'];

        this.mockIndexes = [mockIdx1];

        const mockRow1: TableRow = new TableRowImpl();
        mockRow1.setValue('id', '1');
        mockRow1.setValue('name', 'Test User 1');
        mockRow1.setValue('email', 'test1@example.com');
        const mockRow2: TableRow = new TableRowImpl();
        mockRow2.setValue('id', '2');
        mockRow2.setValue('name', 'Test User 2');
        mockRow2.setValue('email', 'test2@example.com');
        const mockRow3: TableRow = new TableRowImpl();
        mockRow3.setValue('id', '3');
        mockRow3.setValue('name', 'Test User 3');
        mockRow3.setValue('email', 'test3@example.com');
        this.mockRows = [mockRow1, mockRow2, mockRow3];
      }

      openDatabase(path: string): Promise<OpenResult> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: openDatabase %{public}s', path);
        this.mockOpenResult = new OpenResult();
        this.mockOpenResult.success = true;
        return Promise.resolve(this.mockOpenResult);
      }

      closeDatabase(): Promise<void> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: closeDatabase');
        return Promise.resolve();
      }

      executeSql(sql: string, args?: string[]): Promise<QueryResult> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: executeSql %{public}s', sql);
        const result = new QueryResultImpl();
        result.success = true;

        // 根据SQL返回不同的mock数据
        const upperSql = sql.toUpperCase();

        if (upperSql.includes('SELECT') && upperSql.includes('FROM')) {
          if (upperSql.includes('COUNT')) {
            // COUNT查询
            result.columns = ['count'];
            const row: TableRow = new TableRowImpl();
            row.setValue('count', '100');
            result.rows = [row];
          } else if (upperSql.includes('USERS')) {
            result.columns = ['id', 'name', 'email'];
            result.rows = this.mockRows;
          } else if (upperSql.includes('ORDERS')) {
            result.columns = ['id', 'user_id', 'product', 'amount'];
            const orderRow1: TableRow = new TableRowImpl();
            orderRow1.setValue('id', '1');
            orderRow1.setValue('user_id', '1');
            orderRow1.setValue('product', 'iPhone 15');
            orderRow1.setValue('amount', '6999.00');
            result.rows = [orderRow1];
          } else {
            result.columns = ['id', 'name'];
            result.rows = this.mockRows;
          }
        } else if (upperSql.includes('INSERT') || upperSql.includes('UPDATE') || upperSql.includes('DELETE')) {
          result.success = true;
          result.affectedRows = 1;
        } else {
          result.success = true;
        }

        result.executionTime = Math.floor(Math.random() * 50) + 10;
        return Promise.resolve(result);
      }

      getTables(): Promise<TableInfo[]> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: getTables');
        return Promise.resolve(this.mockTables);
      }

      getColumns(tableName: string): Promise<ColumnInfo[]> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: getColumns %{public}s', tableName);
        const cols = this.mockColumns.get(tableName);
        return Promise.resolve(cols || []);
      }

      getIndexes(tableName?: string): Promise<IndexInfo[]> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: getIndexes %{public}s', tableName || 'all');
        if (tableName) {
          const filtered = this.mockIndexes.filter(idx => idx.tableName === tableName);
          return Promise.resolve(filtered);
        }
        return Promise.resolve(this.mockIndexes);
      }

      explainQuery(sql: string): Promise<string> {
        hilog.info(DOMAIN, 'DatabaseService', 'Mock: explainQuery');
        return Promise.resolve('SEARCH TABLE users USING INTEGER PRIMARY KEY (id=?)');
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
        this.mockDbInfo = new DbInfo();
        this.mockDbInfo.path = self.currentDb?.path || '';
        this.mockDbInfo.isOpen = self.currentDb?.isOpen || false;
        return Promise.resolve(this.mockDbInfo);
      }
    }

    return new MockSqliteModule();
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
