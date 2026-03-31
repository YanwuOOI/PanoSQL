# PanoSQL 任务计划

> 基于 Manus 风格的文件规划系统

## 项目概述

**项目名称**: PanoDB - HarmonyOS PC 数据库管理工具
**项目类型**: HarmonyOS PC 原生应用
**开发平台**: OpenHarmony 6.0 (API Level 20)
**当前阶段**: Phase 1 MVP 已完成编译

---

## 阶段规划

### Phase 1: MVP - SQLite 查看器 ✅ 已完成
- [x] 编译通过
- [x] 数据库打开/关闭
- [x] Schema 树展示
- [x] SQL 编辑器 (TextArea)
- [x] 数据表格展示
- [x] getColumns() 实现 ✅ 2026-03-31

### Phase 2: 功能完善 (规划中)
- [ ] 数据编辑（增删改）
- [ ] SQL 格式化
- [ ] CSV/JSON 导出
- [ ] 最近打开列表
- [ ] 单元测试

### Phase 3: 体验升级 (进行中)
- [x] SQL 语法高亮 ✅ 2026-03-31
- [ ] KV-Store 可视化
- [ ] UI 美化
- [ ] 自由窗口适配

### Phase 4: 集成与发布 (规划中)
- [ ] 功能集成
- [ ] 系统测试
- [ ] 缺陷修复
- [ ] 发布准备

---

## 当前任务

### 任务 1: 修复 getColumns() 实现 ✅ 已完成

**问题**: `DatabaseService.getColumns()` 返回空数组

**推荐方案**: 使用 `query()` + `RdbPredicates` 遍历列定义

**实施步骤**:
1. 修改 `DatabaseService.ets` 中的 `getColumns()` 方法
2. 使用 predicate 查询表数据，通过 `ResultSet.getColumnName()` 和 `getColumnType()` 获取列信息
3. 验证编译通过

**文件**: `entry/src/main/ets/services/DatabaseService.ets:198-212`

---

### 任务 2: 实现 SQL 语法高亮 ✅ 已完成

**现状**: 使用 TextArea，无语法高亮

**可选方案**:

| 方案 | 优点 | 缺点 |
|------|------|------|
| A. RichEditor | 原生组件 | 多色文本支持待验证 |
| B. Web + CodeMirror | 功能完整 | 需加载外部资源 |
| C. 分层 TextArea | 完全可控 | 实现复杂 |
| D. 基础关键字高亮 | 简单 | 功能有限 |

**UI 设计文档定义颜色**:
- SQL关键字: #C084FC (紫)
- 函数: #F472B6 (粉)
- 字符串: #22D3EE (青)
- 数字: #FBBF24 (金)
- 运算符: #FB923C (橙)

---

## 详细实施计划

### 任务 1: getColumns() 修复

#### Step 1.1: 实现 getColumns() 方法
- **文件**: `entry/src/main/ets/services/DatabaseService.ets`
- **修改**: 替换存根实现
- **代码位置**: 第 198-212 行

#### Step 1.2: 验证编译
- 运行编译检查
- 确保无 ArkTS 类型错误

#### Step 1.3: 测试验证
- 打开数据库
- 查看 Schema 树中表的列信息

---

### 任务 2: SQL 语法高亮（待确认）

#### 方案 A: RichEditor 多色文本（推荐）

**实现思路**:
1. 创建自定义 `SqlRichEditor` 组件
2. 使用 `RichEditor.customKeyboard()` 实现自定义键盘
3. 使用 `RichEditor.StyledString` 实现多色文本

**文件**: `entry/src/main/ets/components/SqlRichEditor.ets`（新建）

**实施步骤**:
1. 创建 `SqlRichEditor.ets` 组件
2. 实现 SQL 关键字高亮逻辑
3. 替换 `SqlEditor.ets` 中的 TextArea
4. 验证编译和功能

---

## 决策记录

| 日期 | 决策 | 原因 |
|------|------|------|
| 2026-03-30 | 使用 RDB Store API 替代 NAPI C++ | ArkTS 原生接口更易维护 |
| 2026-03-30 | SQL 编辑器降级为 TextArea | RichEditor 语法高亮方案不可行 |

---

## 更新日志

- 2026-03-31: 编译通过；getColumns() 修复完成；SQL 语法高亮回退为 TextArea
- 2026-03-30: 初始化任务计划
