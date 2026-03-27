/**
 * FileTransferService - 文件传输服务
 * 处理文件在应用沙箱与外部存储之间的拷贝
 * 解决HarmonyOS沙箱隔离问题
 */
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF01;

class TransferResult {
  success: boolean = false;
  path?: string = '';
  error?: string = '';
}

class FileTransferService {
  private context: common.UIAbilityContext | null = null;
  private sandboxDbDir: string = '';

  /**
   * 初始化服务
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    // 获取沙箱内数据库存储目录
    this.sandboxDbDir = this.context.databaseDir + '/databases';
    // 确保目录存在
    if (!fileIo.accessSync(this.sandboxDbDir)) {
      try {
        fileIo.mkdirSync(this.sandboxDbDir);
        hilog.info(DOMAIN, 'FileTransferService', 'Created sandbox directory: %{public}s', this.sandboxDbDir);
      } catch (error) {
        hilog.error(DOMAIN, 'FileTransferService', 'Failed to create sandbox directory: %{public}s',
          JSON.stringify(error));
      }
    }
  }

  /**
   * 获取沙箱数据库路径
   */
  getSandboxDatabasePath(): string {
    return this.sandboxDbDir;
  }

  /**
   * 通过系统文件选择器选择并拷贝数据库到沙箱
   * @returns 沙箱内的新路径
   */
  async selectAndCopyToSandbox(): Promise<TransferResult> {
    const result = new TransferResult();

    try {
      hilog.info(DOMAIN, 'FileTransferService', 'Opening document picker...');

      // 1. 打开系统文件选择器
      const documentPicker = new picker.DocumentViewPicker();
      const results = await documentPicker.select({
        fileSuffixFilters: ['.db', '.sqlite', '.sqlite3']
      });

      // 检查是否有选择结果
      let sourcePath: string = '';
      let hasResult = false;

      if (results && results.length > 0) {
        // 使用循环获取第一个元素
        for (let i = 0; i < results.length; i++) {
          const item = results[i];
          if (item && item !== '') {
            sourcePath = item;
            hasResult = true;
            break;
          }
        }
      }

      if (!hasResult) {
        hilog.info(DOMAIN, 'FileTransferService', 'User cancelled file selection');
        result.success = false;
        result.error = '用户取消了文件选择';
        return result;
      }

      hilog.info(DOMAIN, 'FileTransferService', 'Selected file: %{public}s', sourcePath);

      // 2. 拷贝到沙箱
      return await this.copyToSandbox(sourcePath);
    } catch (error) {
      hilog.error(DOMAIN, 'FileTransferService', 'selectAndCopyToSandbox failed: %{public}s',
        JSON.stringify(error));
      result.success = false;
      result.error = `选择文件失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 将外部数据库文件拷贝到沙箱
   * @param sourcePath 用户选择的原始文件路径
   * @returns 沙箱内的新路径
   */
  async copyToSandbox(sourcePath: string): Promise<TransferResult> {
    const result = new TransferResult();

    if (!this.context) {
      result.success = false;
      result.error = '服务未初始化';
      return result;
    }

    try {
      // 确保沙箱目录存在
      if (!fileIo.accessSync(this.sandboxDbDir)) {
        fileIo.mkdirSync(this.sandboxDbDir);
      }

      // 生成目标文件名（添加时间戳避免冲突）
      const pathParts = sourcePath.split('/');
      const fileName = pathParts[pathParts.length - 1] || 'database.db';
      const destPath = `${this.sandboxDbDir}/${Date.now()}_${fileName}`;

      hilog.info(DOMAIN, 'FileTransferService', 'Copying from %{public}s to %{public}s',
        sourcePath, destPath);

      // 读取源文件
      const sourceFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      const sourceStats = fileIo.statSync(sourceFile.fd);

      // 创建目标文件
      const destFile = fileIo.openSync(destPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);

      // 分块拷贝（64KB buffer）
      const bufferSize = 64 * 1024;
      let offset = 0;

      while (offset < sourceStats.size) {
        const toRead = Math.min(bufferSize, sourceStats.size - offset);
        const buffer = new ArrayBuffer(toRead);
        fileIo.readSync(sourceFile.fd, buffer, { offset });
        fileIo.writeSync(destFile.fd, buffer, { offset });
        offset += toRead;
      }

      fileIo.closeSync(sourceFile);
      fileIo.closeSync(destFile);

      hilog.info(DOMAIN, 'FileTransferService', 'Copy successful: %{public}s', destPath);

      result.success = true;
      result.path = destPath;
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'FileTransferService', 'copyToSandbox failed: %{public}s',
        JSON.stringify(error));
      result.success = false;
      result.error = `拷贝失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 将沙箱内的数据库导出到外部位置
   * @param sandboxPath 沙箱内文件路径
   * @param destPath 目标路径（可选，如果不指定则打开保存对话框）
   */
  async exportToOriginal(sandboxPath: string, destPath?: string): Promise<TransferResult> {
    const result = new TransferResult();

    try {
      let targetPath = destPath;

      if (!targetPath) {
        // 打开保存对话框
        hilog.info(DOMAIN, 'FileTransferService', 'Opening save dialog...');
        const documentSaver = new picker.DocumentViewPicker();
        // DocumentViewPicker的save方法直接返回路径
        const saveResult = await documentSaver.save();
        if (saveResult && saveResult.length > 0) {
          targetPath = saveResult[0];
        }
      }

      if (!targetPath || targetPath === '') {
        hilog.info(DOMAIN, 'FileTransferService', 'User cancelled save');
        result.success = false;
        result.error = '用户取消了保存';
        return result;
      }

      hilog.info(DOMAIN, 'FileTransferService', 'Exporting from %{public}s to %{public}s',
        sandboxPath, targetPath);

      // 拷贝文件
      const sourceFile = fileIo.openSync(sandboxPath, fileIo.OpenMode.READ_ONLY);
      const sourceStats = fileIo.statSync(sourceFile.fd);

      const destFile = fileIo.openSync(targetPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);

      const bufferSize = 64 * 1024;
      let offset = 0;

      while (offset < sourceStats.size) {
        const toRead = Math.min(bufferSize, sourceStats.size - offset);
        const buffer = new ArrayBuffer(toRead);
        fileIo.readSync(sourceFile.fd, buffer, { offset });
        fileIo.writeSync(destFile.fd, buffer, { offset });
        offset += toRead;
      }

      fileIo.closeSync(sourceFile);
      fileIo.closeSync(destFile);

      hilog.info(DOMAIN, 'FileTransferService', 'Export successful');

      result.success = true;
      result.path = targetPath;
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'FileTransferService', 'exportToOriginal failed: %{public}s',
        JSON.stringify(error));
      result.success = false;
      result.error = `导出失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 删除沙箱内的数据库副本
   * @param sandboxPath 沙箱内文件路径
   */
  async deleteSandboxCopy(sandboxPath: string): Promise<TransferResult> {
    const result = new TransferResult();

    try {
      if (fileIo.accessSync(sandboxPath)) {
        fileIo.unlinkSync(sandboxPath);
        hilog.info(DOMAIN, 'FileTransferService', 'Deleted sandbox copy: %{public}s', sandboxPath);
      }
      result.success = true;
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'FileTransferService', 'deleteSandboxCopy failed: %{public}s',
        JSON.stringify(error));
      result.success = false;
      result.error = `删除失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 检查沙箱内是否存在指定文件
   */
  existsInSandbox(fileName: string): boolean {
    const fullPath = `${this.sandboxDbDir}/${fileName}`;
    return fileIo.accessSync(fullPath);
  }

  /**
   * 获取沙箱内所有数据库文件
   */
  listSandboxDatabases(): string[] {
    try {
      if (!fileIo.accessSync(this.sandboxDbDir)) {
        return [];
      }

      const files = fileIo.listFileSync(this.sandboxDbDir);
      const result: string[] = [];
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        if (file.endsWith('.db') || file.endsWith('.sqlite')) {
          result.push(file);
        }
      }
      return result;
    } catch (error) {
      hilog.error(DOMAIN, 'FileTransferService', 'listSandboxDatabases failed: %{public}s',
        JSON.stringify(error));
      return [];
    }
  }
}

export default new FileTransferService();
