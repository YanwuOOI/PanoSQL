/**
 * TableInfo - 表信息模型
 * PanoDB Project
 */

import { ColumnInfo } from './ColumnInfo';

export class TableInfo {
  name: string = '';
  type: 'table' | 'view' = 'table';
  rowCount: number = 0;
  columns: ColumnInfo[] = [];
}

export class TableBasicInfo {
  name: string = '';
  type: 'table' | 'view' = 'table';
  rowCount: number = 0;
}
