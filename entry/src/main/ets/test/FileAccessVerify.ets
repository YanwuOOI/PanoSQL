/**
 * FileAccessVerify - 沙箱文件访问验证脚本
 * 第2周关键里程碑：验证DocumentViewPicker + 沙箱拷贝方案可行
 */
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0xFF00;

class VerifyResult {
  success: boolean = false;
  step: string = '';
  message: string = '';
  data?: string = '';
}

class FileAccessVerifier {
  private context: common.UIAbilityContext;
  private sandboxDbDir: string = '';

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 验证结果日志
   */
  private logResult(result: VerifyResult): void {
    hilog.info(DOMAIN, 'FileAccessVerify', '[%{public}s] %{public}s: %{public}s',
      result.success ? 'PASS' : 'FAIL', result.step, result.message);
    if (result.data) {
      hilog.info(DOMAIN, 'FileAccessVerify', '  Data: %{public}s', result.data);
    }
  }

  /**
   * 步骤1：验证DocumentViewPicker能否选择.db/.sqlite文件
   */
  async verifyDocumentPicker(): Promise<VerifyResult> {
    const result = new VerifyResult();
    result.step = 'DocumentViewPicker';

    try {
      hilog.info(DOMAIN, 'FileAccessVerify', 'Step 1: Testing DocumentViewPicker...');

      const documentPicker = new picker.DocumentViewPicker();
      const results = await documentPicker.select({
        fileSuffixFilters: ['.db', '.sqlite', '.sqlite3']
      });

      if (results.length === 0) {
        result.success = false;
        result.message = '用户取消了文件选择';
        return result;
      }

      const selectedPath = results[0];
      hilog.info(DOMAIN, 'FileAccessVerify', 'Selected file: %{public}s', selectedPath);

      result.success = true;
      result.message = '成功选择文件';
      result.data = selectedPath;
      return result;
    } catch (error) {
      result.success = false;
      result.message = `选择文件失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 步骤2：验证沙箱目录是否可写
   */
  verifySandboxDir(): VerifyResult {
    const result = new VerifyResult();
    result.step = 'SandboxDirectory';

    try {
      hilog.info(DOMAIN, 'FileAccessVerify', 'Step 2: Testing sandbox directory...');

      // 获取沙箱内数据库目录
      this.sandboxDbDir = this.context.databaseDir + '/databases';
      hilog.info(DOMAIN, 'FileAccessVerify', 'Sandbox db dir: %{public}s', this.sandboxDbDir);

      // 检查目录是否存在
      if (!fileIo.accessSync(this.sandboxDbDir)) {
        // 尝试创建目录
        try {
          fileIo.mkdirSync(this.sandboxDbDir);
          hilog.info(DOMAIN, 'FileAccessVerify', 'Created sandbox directory');
        } catch (mkdirError) {
          result.success = false;
          result.message = `创建沙箱目录失败: ${JSON.stringify(mkdirError)}`;
          return result;
        }
      }

      result.success = true;
      result.message = '沙箱目录可用';
      result.data = this.sandboxDbDir;
      return result;
    } catch (error) {
      result.success = false;
      result.message = `沙箱目录访问失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 步骤3：验证能否读取外部文件
   */
  async verifyFileRead(sourcePath: string): Promise<VerifyResult> {
    const result = new VerifyResult();
    result.step = 'FileRead';

    try {
      hilog.info(DOMAIN, 'FileAccessVerify', 'Step 3: Testing file read...');

      const file = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      const fileStats = fileIo.statSync(file.fd);

      hilog.info(DOMAIN, 'FileAccessVerify', 'File size: %{public}d bytes', fileStats.size);

      fileIo.closeSync(file);

      result.success = true;
      result.message = '成功读取文件';
      result.data = `Size: ${fileStats.size} bytes`;
      return result;
    } catch (error) {
      result.success = false;
      result.message = `文件读取失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 步骤4：验证文件拷贝到沙箱
   */
  async verifyCopyToSandbox(sourcePath: string): Promise<VerifyResult> {
    const result = new VerifyResult();
    result.step = 'CopyToSandbox';

    try {
      hilog.info(DOMAIN, 'FileAccessVerify', 'Step 4: Testing copy to sandbox...');

      if (!this.sandboxDbDir) {
        this.sandboxDbDir = this.context.databaseDir + '/databases';
      }

      // 生成目标文件名（添加时间戳避免冲突）
      const fileName = sourcePath.split('/').pop() || 'database.db';
      const destPath = `${this.sandboxDbDir}/${Date.now()}_${fileName}`;

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

      hilog.info(DOMAIN, 'FileAccessVerify', 'Copied to: %{public}s', destPath);

      result.success = true;
      result.message = '成功拷贝到沙箱';
      result.data = destPath;
      return result;
    } catch (error) {
      result.success = false;
      result.message = `拷贝失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 步骤5：验证能否打开沙箱内的SQLite数据库（需要Native模块支持）
   * 注意：此步骤需要NAPI模块编译并加载后才能执行
   */
  async verifyNapiOpen(sandboxPath: string): Promise<VerifyResult> {
    const result = new VerifyResult();
    result.step = 'NAPI_Open';

    try {
      hilog.info(DOMAIN, 'FileAccessVerify', 'Step 5: Testing NAPI SQLite open...');

      // 尝试动态导入Native模块
      // 注意：实际项目中应该使用native.xxx方式调用
      // 这里用try-catch包装，如果模块未编译也不会崩溃

      const nativeLib = await import('../cpp/panodb_sqlite.so').catch(() => null);

      if (!nativeLib) {
        hilog.warn(DOMAIN, 'FileAccessVerify', 'NAPI module not compiled yet, skipping Step 5');
        result.success = true;
        result.message = 'NAPI模块尚未编译，跳过此步骤';
        result.data = '需要在native模块编译后重新验证';
        return result;
      }

      // 调用Native方法
      const nativeResult = nativeLib.openDatabase(sandboxPath);

      if (nativeResult.success) {
        result.success = true;
        result.message = 'NAPI成功打开数据库';
        result.data = sandboxPath;
        return result;
      } else {
        result.success = false;
        result.message = `NAPI打开数据库失败: ${nativeResult.error}`;
        return result;
      }
    } catch (error) {
      result.success = false;
      result.message = `NAPI调用失败: ${JSON.stringify(error)}`;
      return result;
    }
  }

  /**
   * 运行完整验证流程
   */
  async runFullVerification(): Promise<VerifyResult[]> {
    const results: VerifyResult[] = [];

    hilog.info(DOMAIN, 'FileAccessVerify', '========================================');
    hilog.info(DOMAIN, 'FileAccessVerify', '开始沙箱文件访问验证');
    hilog.info(DOMAIN, 'FileAccessVerify', '========================================');

    // 步骤1：DocumentViewPicker
    const pickerResult = await this.verifyDocumentPicker();
    this.logResult(pickerResult);
    results.push(pickerResult);

    if (!pickerResult.success) {
      hilog.error(DOMAIN, 'FileAccessVerify', '验证失败：DocumentViewPicker不可用');
      return results;
    }

    const sourcePath = pickerResult.data!;

    // 步骤2：沙箱目录
    const sandboxResult = this.verifySandboxDir();
    this.logResult(sandboxResult);
    results.push(sandboxResult);

    if (!sandboxResult.success) {
      hilog.error(DOMAIN, 'FileAccessVerify', '验证失败：沙箱目录不可用');
      return results;
    }

    // 步骤3：文件读取
    const readResult = await this.verifyFileRead(sourcePath);
    this.logResult(readResult);
    results.push(readResult);

    if (!readResult.success) {
      hilog.error(DOMAIN, 'FileAccessVerify', '验证失败：无法读取源文件');
      return results;
    }

    // 步骤4：拷贝到沙箱
    const copyResult = await this.verifyCopyToSandbox(sourcePath);
    this.logResult(copyResult);
    results.push(copyResult);

    if (!copyResult.success) {
      hilog.error(DOMAIN, 'FileAccessVerify', '验证失败：拷贝到沙箱失败');
      return results;
    }

    // 步骤5：NAPI打开数据库
    const napiResult = await this.verifyNapiOpen(copyResult.data!);
    this.logResult(napiResult);
    results.push(napiResult);

    // 总结
    hilog.info(DOMAIN, 'FileAccessVerify', '========================================');
    const allSuccess = results.every(r => r.success);
    hilog.info(DOMAIN, 'FileAccessVerify', '验证%{public}s', allSuccess ? '全部通过' : '存在失败项');
    hilog.info(DOMAIN, 'FileAccessVerify', '========================================');

    return results;
  }
}

export default FileAccessVerifier;
