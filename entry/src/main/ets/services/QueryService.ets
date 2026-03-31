/**
 * QueryService - 查询服务
 * 处理SQL查询的解析、执行和结果处理
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import DatabaseService from './DatabaseService';
import { QueryResult, TableRow, getCellValue } from '../models/QueryResult';

const DOMAIN = 0xFF04;

class QueryService {
  /**
   * 执行SQL查询
   */
  async execute(sql: string, params?: (string | number | null)[]): Promise<QueryResult> {
    hilog.info(DOMAIN, 'QueryService', 'Executing query: %{public}s', sql.substring(0, 100));

    const result = await DatabaseService.executeSql(sql, params?.map(p => String(p)));

    if (!result.success) {
      hilog.error(DOMAIN, 'QueryService', 'Query failed: %{public}s', result.error);
    } else {
      hilog.info(DOMAIN, 'QueryService', 'Query succeeded: %{public}d rows in %{public}d ms',
        result.rows.length, result.executionTime);
    }

    return result;
  }

  /**
   * 获取查询执行计划
   */
  async explain(sql: string): Promise<string> {
    return await DatabaseService.explain(sql);
  }

  /**
   * 格式化SQL语句
   * 支持关键字大写、缩进、字符串保护
   */
  formatSql(sql: string): string {
    if (!sql || sql.trim().length === 0) {
      return '';
    }

    // 第一步：保护字符串和注释
    const protectedParts: string[] = [];
    let protectedIndex = 0;

    // 保护单引号字符串
    let result = sql.replace(/'([^']*)'/g, (match) => {
      protectedParts.push(match);
      return `__PROTECTED_${protectedIndex++}__`;
    });

    // 保护双引号字符串
    result = result.replace(/"([^"]*)"/g, (match) => {
      protectedParts.push(match);
      return `__PROTECTED_${protectedIndex++}__`;
    });

    // 保护注释
    result = result.replace(/--[^\n]*/g, (match) => {
      protectedParts.push(match);
      return `__PROTECTED_${protectedIndex++}__`;
    });
    result = result.replace(/\/\*[^*]*\*\//g, (match) => {
      protectedParts.push(match);
      return `__PROTECTED_${protectedIndex++}__`;
    });

    // 关键字列表（按优先级排序，长的在前）
    const keywords = [
      // DQL
      'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'ORDER BY', 'GROUP BY', 'HAVING',
      'LIMIT', 'OFFSET', 'AS', 'DISTINCT', 'ALL', 'ANY', 'SOME', 'EXISTS', 'BETWEEN',
      'LIKE', 'IN', 'IS NULL', 'IS NOT NULL', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
      'UNION', 'UNION ALL', 'INTERSECT', 'EXCEPT',
      // DML
      'INSERT INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE FROM',
      'REPLACE INTO', 'IGNORE', 'ON DUPLICATE KEY UPDATE',
      // DDL
      'CREATE TABLE', 'CREATE INDEX', 'CREATE VIEW', 'CREATE TRIGGER',
      'ALTER TABLE', 'DROP TABLE', 'DROP INDEX', 'DROP VIEW', 'DROP TRIGGER',
      'ADD COLUMN', 'DROP COLUMN', 'MODIFY COLUMN', 'RENAME TO',
      'PRIMARY KEY', 'FOREIGN KEY', 'REFERENCES', 'NOT NULL', 'UNIQUE', 'DEFAULT',
      'CHECK', 'CONSTRAINT', 'INDEX', 'VIEW', 'TRIGGER',
      'IF NOT EXISTS', 'IF EXISTS', 'AUTO_INCREMENT', 'UNSIGNED', 'ZEROFILL',
      // Join
      'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'OUTER JOIN', 'CROSS JOIN',
      'FULL OUTER JOIN', 'NATURAL JOIN', 'LEFT OUTER JOIN', 'RIGHT OUTER JOIN',
      'ON', 'USING',
      // Transaction
      'BEGIN', 'COMMIT', 'ROLLBACK', 'SAVEPOINT', 'RELEASE SAVEPOINT',
      'TRANSACTION', 'START TRANSACTION',
      // CTE
      'WITH', 'RECURSIVE',
      // Other
      'NULL', 'TRUE', 'FALSE', 'CAST', 'COALESCE', 'IFNULL', 'IF', 'IIF'
    ];

    // 在关键字前后添加换行（保持原始大小写）
    for (const keyword of keywords) {
      // 创建一个匹配原始大小写的关键字正则
      const escapedKeyword = keyword.replace(/ /g, '\\s+');
      const regex = new RegExp(`\\b(${escapedKeyword})\\b`, 'gi');
      result = result.replace(regex, '\n' + keyword.toUpperCase());
    }

    // 清理多余的换行
    result = result.replace(/\n+/g, '\n').trim();

    // 恢复被保护的部分
    for (let i = 0; i < protectedParts.length; i++) {
      result = result.replace(`__PROTECTED_${i}__`, protectedParts[i]);
    }

    // 添加缩进
    const lines = result.split('\n');
    let indentLevel = 0;
    const indentedLines = lines.map(line => {
      const trimmedLine = line.trim();
      if (!trimmedLine) {
        return '';
      }

      // 减少缩进的关键字
      const outdentKeywords = ['END', 'ELSE', 'UNION', 'UNION ALL', 'INTERSECT', 'EXCEPT'];
      const shouldOutdent = outdentKeywords.some(kw => trimmedLine.toUpperCase().startsWith(kw));

      if (shouldOutdent && indentLevel > 0) {
        indentLevel--;
      }

      const indentedLine = '  '.repeat(indentLevel) + trimmedLine;

      // 增加缩进的关键字
      const indentKeywords = [
        'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'SET', 'VALUES',
        'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'OUTER JOIN', 'CROSS JOIN',
        'FULL OUTER JOIN', 'NATURAL JOIN', 'LEFT OUTER JOIN', 'RIGHT OUTER JOIN',
        'ORDER BY', 'GROUP BY', 'HAVING', 'LIMIT', 'OFFSET',
        'INSERT INTO', 'UPDATE', 'DELETE FROM', 'REPLACE INTO',
        'BEGIN', 'CASE', 'WHEN', 'THEN', 'WITH', 'RECURSIVE'
      ];
      const shouldIndent = indentKeywords.some(kw => trimmedLine.toUpperCase().startsWith(kw));

      if (shouldIndent && !shouldOutdent) {
        indentLevel++;
      }

      return indentedLine;
    });

    return indentedLines.filter(l => l.length > 0).join('\n');
  }

  /**
   * 导出结果为JSON
   */
  exportAsJson(result: QueryResult): string {
    class ExportData {
      columns: string[] = [];
      rows: TableRow[] = [];
      affectedRows: number = 0;
      executionTime: number = 0;
    }
    if (!result.success) {
      const errObj = new ExportData();
      errObj.columns = [];
      errObj.rows = [];
      errObj.affectedRows = 0;
      errObj.executionTime = 0;
      return JSON.stringify({ error: result.error }, null, 2);
    }

    const exportData = new ExportData();
    exportData.columns = result.columns;
    exportData.rows = result.rows;
    exportData.affectedRows = result.affectedRows;
    exportData.executionTime = result.executionTime;
    return JSON.stringify(exportData, null, 2);
  }

  /**
   * 导出结果为CSV
   */
  exportAsCsv(result: QueryResult): string {
    if (!result.success) {
      return '';
    }

    const lines: string[] = [];

    // 添加表头
    lines.push(result.columns.map(col => this.escapeCsvValue(col)).join(','));

    // 添加数据行
    for (const row of result.rows) {
      const values = result.columns.map(col => {
        const value = getCellValue(row, col);
        return this.escapeCsvValue(value !== null && value !== undefined ? String(value) : '');
      });
      lines.push(values.join(','));
    }

    return lines.join('\n');
  }

  /**
   * 导出结果为SQL INSERT语句
   */
  exportAsSql(result: QueryResult, tableName: string): string {
    if (!result.success || result.columns.length === 0) {
      return '';
    }

    const lines: string[] = [];

    for (const row of result.rows) {
      const values = result.columns.map(col => {
        const value = getCellValue(row, col);
        if (value === null || value === undefined) {
          return 'NULL';
        }
        // 字符串值需要加引号并转义
        if (typeof value === 'string') {
          return `'${value.replace(/'/g, "''")}'`;
        }
        return String(value);
      });

      lines.push(`INSERT INTO \`${tableName}\` (\`${result.columns.join('`, `')}\`) VALUES (${values.join(', ')});`);
    }

    return lines.join('\n');
  }

  /**
   * 转义CSV值
   */
  private escapeCsvValue(value: string): string {
    if (value.includes('"') || value.includes(',') || value.includes('\n')) {
      return `"${value.replace(/"/g, '""')}"`;
    }
    return value;
  }

  /**
   * 检测SQL语句类型
   */
  detectSqlType(sql: string): 'SELECT' | 'INSERT' | 'UPDATE' | 'DELETE' | 'DDL' | 'OTHER' {
    const upperSql = sql.trim().toUpperCase();

    if (upperSql.startsWith('SELECT')) {
      return 'SELECT';
    } else if (upperSql.startsWith('INSERT')) {
      return 'INSERT';
    } else if (upperSql.startsWith('UPDATE')) {
      return 'UPDATE';
    } else if (upperSql.startsWith('DELETE')) {
      return 'DELETE';
    } else if (upperSql.startsWith('CREATE') || upperSql.startsWith('ALTER') || upperSql.startsWith('DROP')) {
      return 'DDL';
    }

    return 'OTHER';
  }
}

export default new QueryService();
