/**
 * DatabaseInfo - 数据库信息模型
 * PanoDB Project
 */

export class DatabaseInfo {
  id: string;
  name: string;
  path: string;
  sandboxPath: string;
  originalPath: string;
  size: number;
  tableCount: number;
  createdTime: number;
  modifiedTime: number;
  lastOpenedTime: number;

  constructor() {
    this.id = '';
    this.name = '';
    this.path = '';
    this.sandboxPath = '';
    this.originalPath = '';
    this.size = 0;
    this.tableCount = 0;
    this.createdTime = Date.now();
    this.modifiedTime = Date.now();
    this.lastOpenedTime = Date.now();
  }

  /**
   * 从文件路径创建DatabaseInfo
   */
  static fromPath(filePath: string): DatabaseInfo {
    const info = new DatabaseInfo();
    const fileName = filePath.split('/').pop() || 'database.db';
    info.id = `${Date.now()}_${fileName}`;
    info.name = fileName.replace(/\.(db|sqlite|sqlite3)$/i, '');
    info.path = filePath;
    info.sandboxPath = filePath;
    return info;
  }

  /**
   * 获取文件大小描述
   */
  getSizeDescription(): string {
    if (this.size < 1024) {
      return `${this.size} B`;
    } else if (this.size < 1024 * 1024) {
      return `${(this.size / 1024).toFixed(1)} KB`;
    } else if (this.size < 1024 * 1024 * 1024) {
      return `${(this.size / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(this.size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
  }
}
