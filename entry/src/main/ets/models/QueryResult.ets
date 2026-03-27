/**
 * QueryResult - 查询结果模型
 * PanoDB Project
 */

/**
 * 表格行数据实现类
 */
export class TableRowImpl {
  private data: Record<string, string | null> = {};

  setValue(key: string, value: string | null): void {
    this.data[key] = value;
  }

  getValue(key: string): string | null {
    return this.data[key] ?? null;
  }

  getColumnKeys(): string[] {
    return Object.keys(this.data);
  }
}

/**
 * 表格行数据
 */
export type TableRow = TableRowImpl;

export class QueryResult {
  success: boolean = false;
  columns: string[] = [];
  rows: TableRow[] = [];
  affectedRows: number = 0;
  executionTime: number = 0;
  error?: string = '';
}

export class QueryError {
  code: number = 0;
  message: string = '';
  sqlState?: string = '';
}

/**
 * SQL执行结果类型
 */
export type SqlExecutionResult = QueryResult;

/**
 * 获取单元格值
 */
export function getCellValue(row: TableRow, column: string): string | null {
  if (row instanceof TableRowImpl) {
    return row.getValue(column);
  }
  return null;
}

/**
 * 创建空结果
 */
export function createEmptyResult(): QueryResult {
  const result = new QueryResult();
  result.success = true;
  result.columns = [];
  result.rows = [];
  result.affectedRows = 0;
  result.executionTime = 0;
  return result;
}

/**
 * 创建错误结果
 */
export function createErrorResult(error: string): QueryResult {
  const result = new QueryResult();
  result.success = false;
  result.columns = [];
  result.rows = [];
  result.affectedRows = 0;
  result.executionTime = 0;
  result.error = error;
  return result;
}
