/**
 * Constants - 全局常量定义
 * PanoDB Project
 */

/**
 * 应用配置常量
 */
export class AppConfig {
  static readonly APP_NAME: string = 'PanoDB';
  static readonly APP_VERSION: string = '1.0.0';
  static readonly WINDOW_DEFAULT_WIDTH: number = 1200;
  static readonly WINDOW_DEFAULT_HEIGHT: number = 800;
  static readonly WINDOW_MIN_WIDTH: number = 800;
  static readonly WINDOW_MIN_HEIGHT: number = 600;
  static readonly PAGINATION_DEFAULT_PAGE_SIZE: number = 100;
  static readonly PAGINATION_MAX_PAGE_SIZE: number = 1000;
  static readonly FILE_DB_SUFFIXES: string[] = ['.db', '.sqlite', '.sqlite3'];
  static readonly FILE_MAX_FILE_SIZE: number = 1024 * 1024 * 1024;
  static readonly EDITOR_MAX_LINES: number = 10000;
  static readonly EDITOR_FONT_FAMILY: string = 'monospace';
  static readonly EDITOR_FONT_SIZE: number = 14;
}

/**
 * SQL关键字
 */
export const SQL_KEYWORDS: string[] = [
  'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'BETWEEN',
  'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'CROSS', 'ON',
  'ORDER', 'BY', 'ASC', 'DESC', 'NULLS', 'FIRST', 'LAST',
  'GROUP', 'HAVING', 'DISTINCT', 'ALL',
  'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE',
  'CREATE', 'TABLE', 'INDEX', 'VIEW', 'TRIGGER', 'DATABASE',
  'ALTER', 'ADD', 'COLUMN', 'DROP', 'RENAME', 'TO',
  'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'UNIQUE', 'CHECK', 'DEFAULT',
  'CONSTRAINT', 'AUTOINCREMENT', 'INTEGER', 'TEXT', 'REAL', 'BLOB', 'NUMERIC',
  'VARCHAR', 'CHAR', 'DATE', 'DATETIME', 'TIMESTAMP',
  'IF', 'EXISTS', 'IF NOT EXISTS', 'IF EXISTS',
  'AS', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
  'UNION', 'INTERSECT', 'EXCEPT',
  'LIMIT', 'OFFSET', 'FETCH', 'NEXT', 'ROWS', 'ONLY',
  'WITH', 'RECURSIVE', 'CTE',
  'BEGIN', 'COMMIT', 'ROLLBACK', 'TRANSACTION', 'SAVEPOINT', 'RELEASE',
  'EXPLAIN', 'QUERY', 'PLAN',
  'VACUUM', 'ANALYZE', 'REINDEX',
  'ATTACH', 'DETACH', 'DATABASE'
];

/**
 * SQL函数
 */
export const SQL_FUNCTIONS: string[] = [
  'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'TOTAL',
  'COALESCE', 'IFNULL', 'NULLIF', 'IIF',
  'LENGTH', 'LOWER', 'UPPER', 'TRIM', 'LTRIM', 'RTRIM',
  'SUBSTR', 'SUBSTRING', 'REPLACE', 'INSTR', 'LIKE',
  'ABS', 'ROUND', 'RANDOM', 'SQRT', 'POWER',
  'DATE', 'TIME', 'DATETIME', 'JULIANDAY', 'STRFTIME',
  'TYPEOF', 'CAST', 'UNICODE', 'CHAR',
  'GROUP_CONCAT', 'GROUP_CONCAT'
];

/**
 * 数据库连接状态
 */
export enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  ERROR = 'error'
}

/**
 * 节点类型
 */
export enum TreeNodeType {
  DATABASE = 'database',
  TABLES = 'tables',
  VIEWS = 'views',
  INDEXES = 'indexes',
  TABLE = 'table',
  VIEW = 'view',
  INDEX = 'index',
  COLUMN = 'column'
}

/**
 * SQL执行状态
 */
export enum ExecutionState {
  IDLE = 'idle',
  EXECUTING = 'executing',
  SUCCESS = 'success',
  ERROR = 'error'
};

/**
 * 颜色常量类
 */
export class Colors {
  // 背景色
  static readonly BG_DEEP: string = '#0D0D0D';
  static readonly BG_BASE: string = '#141414';
  static readonly BG_ELEVATED: string = '#1A1A1A';
  static readonly BG_HOVER: string = '#242424';
  static readonly BG_ACTIVE: string = '#2A2A2A';

  // 边框色
  static readonly BORDER_DEFAULT: string = '#2A2A2A';
  static readonly BORDER_HOVER: string = '#3A3A3A';
  static readonly BORDER_FOCUS: string = '#3B82F6';

  // 文字色
  static readonly TEXT_PRIMARY: string = '#E5E5E5';
  static readonly TEXT_SECONDARY: string = '#A1A1AA';
  static readonly TEXT_MUTED: string = '#71717A';

  // 功能色
  static readonly COLOR_PRIMARY: string = '#3B82F6';
  static readonly COLOR_SUCCESS: string = '#22C55E';
  static readonly COLOR_WARNING: string = '#F97316';
  static readonly COLOR_ERROR: string = '#EF4444';
  static readonly COLOR_INFO: string = '#06B6D4';

  // SQL语法高亮
  static readonly SQL_KEYWORD: string = '#C084FC';
  static readonly SQL_FUNCTION: string = '#F472B6';
  static readonly SQL_STRING: string = '#22D3EE';
  static readonly SQL_NUMBER: string = '#FBBF24';
  static readonly SQL_OPERATOR: string = '#FB923C';
  static readonly SQL_COMMENT: string = '#6B7280';
  static readonly SQL_TABLE: string = '#60A5FA';
  static readonly SQL_NULL: string = '#EF4444';

  // 树节点色
  static readonly NODE_DATABASE: string = '#3B82F6';
  static readonly NODE_TABLE: string = '#FBBF24';
  static readonly NODE_VIEW: string = '#C084FC';
  static readonly NODE_INDEX: string = '#22C55E';
  static readonly NODE_COLUMN: string = '#71717A';
}

// COLORS类 - 保持向后兼容
export class COLORS {
  static readonly BG_DEEP: string = Colors.BG_DEEP;
  static readonly BG_BASE: string = Colors.BG_BASE;
  static readonly BG_ELEVATED: string = Colors.BG_ELEVATED;
  static readonly BG_HOVER: string = Colors.BG_HOVER;
  static readonly BG_ACTIVE: string = Colors.BG_ACTIVE;
  static readonly BORDER_DEFAULT: string = Colors.BORDER_DEFAULT;
  static readonly BORDER_HOVER: string = Colors.BORDER_HOVER;
  static readonly BORDER_FOCUS: string = Colors.BORDER_FOCUS;
  static readonly TEXT_PRIMARY: string = Colors.TEXT_PRIMARY;
  static readonly TEXT_SECONDARY: string = Colors.TEXT_SECONDARY;
  static readonly TEXT_MUTED: string = Colors.TEXT_MUTED;
  static readonly COLOR_PRIMARY: string = Colors.COLOR_PRIMARY;
  static readonly COLOR_SUCCESS: string = Colors.COLOR_SUCCESS;
  static readonly COLOR_WARNING: string = Colors.COLOR_WARNING;
  static readonly COLOR_ERROR: string = Colors.COLOR_ERROR;
  static readonly COLOR_INFO: string = Colors.COLOR_INFO;
  static readonly SQL_KEYWORD: string = Colors.SQL_KEYWORD;
  static readonly SQL_FUNCTION: string = Colors.SQL_FUNCTION;
  static readonly SQL_STRING: string = Colors.SQL_STRING;
  static readonly SQL_NUMBER: string = Colors.SQL_NUMBER;
  static readonly SQL_OPERATOR: string = Colors.SQL_OPERATOR;
  static readonly SQL_COMMENT: string = Colors.SQL_COMMENT;
  static readonly SQL_TABLE: string = Colors.SQL_TABLE;
  static readonly SQL_NULL: string = Colors.SQL_NULL;
  static readonly NODE_DATABASE: string = Colors.NODE_DATABASE;
  static readonly NODE_TABLE: string = Colors.NODE_TABLE;
  static readonly NODE_VIEW: string = Colors.NODE_VIEW;
  static readonly NODE_INDEX: string = Colors.NODE_INDEX;
  static readonly NODE_COLUMN: string = Colors.NODE_COLUMN;
}
