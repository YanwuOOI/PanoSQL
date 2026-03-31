# PanoSQL 研究发现

> 项目探索过程中发现的关键信息

## 技术架构

### 当前实现
- **数据库层**: OpenHarmony RDB Store API (@ohos.data.rdb)
- **UI 框架**: ArkUI Stage Model
- **开发语言**: ArkTS (TypeScript 超集)
- **构建工具**: Hvigor

### 关键技术点

#### RDB Store API 限制
- `executeSql()` 返回 `Promise<void>`，无法直接获取 SELECT 结果
- SELECT 查询需使用 `query()` + `RdbPredicates`
- 复杂 WHERE 条件无法通过 predicate 实现

#### 已知问题
- `getColumns()` 暂返回空数组
- SQL 编辑器使用 TextArea（无语法高亮）

### 项目结构
```
entry/src/main/ets/
├── entryability/     # 应用入口
├── pages/           # 页面
│   ├── Index.ets    # 首页
│   └── TableBrowserPage.ets  # 表浏览页
├── components/      # 组件
│   ├── SchemaTree.ets
│   ├── SqlEditor.ets
│   └── TableView.ets
├── services/        # 服务
│   └── DatabaseService.ets
└── models/          # 数据模型
```

---

## 问题 1: getColumns() 修复方案

### 当前状态
**文件**: `entry/src/main/ets/services/DatabaseService.ets:198-212`

```typescript
async getColumns(tableName: string): Promise<ColumnInfo[]> {
  // 直接返回空数组 - 存根实现
  return [];
}
```

### 问题分析
- 需要使用 `PRAGMA table_info('table_name')` 获取列信息
- 但 `executeSql()` 无法返回 ResultSet
- `query()` + `RdbPredicates` 不支持 PRAGMA 语句

### 可能的解决方案

#### 方案 A: 使用 predicate 枚举表结构
```typescript
// 通过查询表数据推断列信息
async getColumns(tableName: string): Promise<ColumnInfo[]> {
  // 使用 LIMIT 1 查询获取一条记录
  // 从结果集推断列名和数据类型
  const predicates = new relationalStore.RdbPredicates(tableName);
  predicates.limitAs(1);
  const resultSet = await this.store.query(predicates, ['*']);
  // 遍历列信息...
}
```
**缺点**: 无法获取 NOT NULL、PRIMARY KEY 等元数据

#### 方案 B: 利用 ResultSet.getColumnName() 和 getColumnType()
```typescript
// 只需查询一行，遍历列定义
const resultSet = await this.store.query(predicates, ['*']);
const columnCount = resultSet.columnCount;
for (let i = 0; i < columnCount; i++) {
  const colName = resultSet.getColumnName(i);
  const colType = resultSet.getColumnType(i);
  // 创建 ColumnInfo
}
```
**优点**: 可以获取列名和类型
**缺点**: 无法获取 NOT NULL、DEFAULT 等属性

#### 方案 C: 使用 executeSql 执行 PRAGMA（待验证）
```typescript
// 某些 RDB 实现可能支持
await this.store.executeSql(`PRAGMA table_info('${tableName}')`);
```
**问题**: `executeSql` 返回 void，无法获取结果

### 推荐方案
**方案 B** - 实现简单，可获取基本列信息

---

## 问题 2: SQL 语法高亮方案

### 当前状态
- 使用 TextArea 组件
- 无语法高亮功能
- UI 设计文档定义了颜色方案

### 可用方案

#### 方案 A: RichEditor 组件
**优点**: 原生 ArkUI 组件
**缺点**:
- 需要验证是否支持多色文本混合
- 已有反馈说语法高亮方案不可行

#### 方案 B: Web 组件 + CodeMirror
**优点**: 功能完整（语法高亮、自动补全）
**缺点**: 需要加载外部资源，性能考虑

#### 方案 C: 自定义 TextArea + 正则替换显示
**优点**: 完全可控
**缺点**: 实现复杂，需要维护多个 TextArea 层叠

#### 方案 D: 降级方案 - 仅关键字高亮
**优点**: 可使用 RichEditor 或多层 TextArea 实现基础高亮
**缺点**: 不完整

### UI 设计文档定义的颜色
| 语法元素 | 颜色 |
|----------|------|
| SQL关键字 | #C084FC |
| 函数 | #F472B6 |
| 字符串 | #22D3EE |
| 数字 | #FBBF24 |
| 运算符 | #FB923C |
| 注释 | #6B7280 |
| 表名/列名 | #60A5FA |

---

## 问题 3: ColumnInfo 模型重复

### 发现
项目存在两套 ColumnInfo 定义:
1. `models/ColumnInfo.ets` - 简单定义
2. `models/TableSchema.ets` - 详细定义（含 isUnique, autoIncrement）

### 建议
统一使用 `TableSchema.ets` 中的定义

---

## Phase 2: 数据编辑功能

### 现状分析

#### 已实现组件

| 组件 | 文件 | 状态 |
|------|------|------|
| TableView | `components/TableView.ets` | ✅ 已支持编辑UI |
| TableEditState | `models/TableEditState.ets` | ✅ SQL生成逻辑 |
| DatabaseService | `services/DatabaseService.ets` | ⚠️ 缺少 update/delete |
| TableBrowserPage | `pages/TableBrowserPage.ets` | ✅ executeEditSqls() |

#### TableView 编辑功能
```typescript
// 已有按钮和回调
- 新增行 (insertRow)
- 删除行 (confirmDelete)
- 保存更改 (saveChanges)
- 放弃更改 (discardChanges)

// 回调
setOnSaveRequest(callback: (sqls: string[]) => void)
```

#### DatabaseService 数据操作现状

| 方法 | 签名 | 状态 |
|------|------|------|
| `insert` | `insert(table, data)` | ✅ 已实现 |
| `update` | - | ❌ 缺失 |
| `delete` | - | ❌ 缺失 |
| `executeSql` | `executeSql(sql)` | ✅ 已实现 |

### 需要实现

#### 1. DatabaseService.update() 方法
```typescript
async update(table: string, data: Record<string, string | number | null>, where: string): Promise<number>
```
- 使用 RDB Store API 的 `update()` 方法
- 通过 RdbPredicates 构建 WHERE 条件

#### 2. DatabaseService.delete() 方法
```typescript
async delete(table: string, where: string): Promise<number>
```
- 使用 RDB Store API 的 `delete()` 方法

### 实施步骤

1. 在 `DatabaseService.ets` 添加 `update()` 方法
2. 在 `DatabaseService.ets` 添加 `delete()` 方法
3. 验证编译通过

---

## 更新日志

- 2026-03-31: 分析数据编辑功能现状，制定实现计划
- 2026-03-31: 深入分析 getColumns() 和 SQL 语法高亮方案
- 2026-03-30: 初始化研究发现
