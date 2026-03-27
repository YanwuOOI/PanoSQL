/**
 * IndexInfo - 索引信息模型
 * PanoDB Project
 */

export class IndexInfo {
  name: string = '';
  tableName: string = '';
  unique: boolean = false;
  columns: string[] = [];
  sql?: string = '';
}

export class IndexBasicInfo {
  name: string = '';
  tableName: string = '';
  unique: boolean = false;
}
