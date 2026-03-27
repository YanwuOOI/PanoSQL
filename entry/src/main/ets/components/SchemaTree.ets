/**
 * SchemaTree - Schema树形导航组件
 * 以树形结构展示数据库的完整结构
 * PanoDB Project
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import SchemaService from '../services/SchemaService';
import { TableInfo, TableBasicInfo } from '../models/TableInfo';
import { ColumnInfo } from '../models/ColumnInfo';
import { IndexInfo } from '../models/IndexInfo';
import { COLORS, TreeNodeType } from '../utils/Constants';

const DOMAIN = 0xFF10;

// 树节点类型
class TreeNode {
  id: string = '';
  name: string = '';
  type: TreeNodeType = TreeNodeType.TABLE;
  children?: TreeNode[] = [];
  data?: TableInfo | ColumnInfo | IndexInfo | TableBasicInfo;
  expanded?: boolean = false;
}

@Component
export struct SchemaTree {
  @Link currentTableName: string;
  @State private treeData: TreeNode[] = [];
  @State private isLoading: boolean = false;
  @State private expandedNodes: Set<string> = new Set();
  @State private selectedNodeId: string = '';

  onNodeClick?: (node: TreeNode) => void;

  aboutToAppear() {
    // 组件出现时自动加载Schema
    this.loadSchema();
  }

  build() {
    Column() {
      if (this.isLoading) {
        this.buildLoading()
      } else if (this.treeData.length === 0) {
        this.buildEmpty()
      } else {
        this.buildTree()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.BG_ELEVATED)
  }

  @Builder
  buildLoading() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(COLORS.COLOR_PRIMARY)
      Text('加载中...')
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildEmpty() {
    Column() {
      Text('暂无数据')
        .fontSize(14)
        .fontColor(COLORS.TEXT_MUTED)
      Text('请先打开数据库')
        .fontSize(12)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildTree() {
    List() {
      ForEach(this.treeData, (node: TreeNode) => {
        ListItem() {
          this.buildNode(node, 0)
        }
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildNode(node: TreeNode, depth: number) {
    Column() {
      // 节点行
      Row() {
        // 展开/折叠箭头
        if (node.children && node.children.length > 0) {
          Text(this.expandedNodes.has(node.id) ? '▼' : '▶')
            .fontSize(10)
            .fontColor(COLORS.TEXT_MUTED)
            .margin({ right: 4 })
            .onClick(() => this.toggleNode(node.id))
        } else {
          Text(' ')
            .width(14)
        }

        // 节点图标
        this.buildNodeIcon(node.type)

        // 节点名称
        Text(node.name)
          .fontSize(13)
          .fontColor(this.selectedNodeId === node.id ? COLORS.TEXT_PRIMARY : COLORS.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexGrow(1)
          .flexShrink(1)
      }
      .padding({
        left: depth * 16 + 8,
        right: 8,
        top: 6,
        bottom: 6
      })
      .width('100%')
      .backgroundColor(this.selectedNodeId === node.id ? COLORS.BG_HOVER : Color.Transparent)
      .borderRadius(4)
      .onClick(() => this.onNodeClicked(node))

      // 子节点
      if (node.children && this.expandedNodes.has(node.id)) {
        ForEach(node.children, (child: TreeNode) => {
          ListItem() {
            this.buildNode(child, depth + 1)
          }
        })
      }
    }
  }

  @Builder
  buildNodeIcon(type: TreeNodeType) {
    if (type === TreeNodeType.DATABASE) {
      Text('⬡')
        .fontSize(14)
        .fontColor(COLORS.NODE_DATABASE)
        .margin({ right: 6 })
    } else if (type === TreeNodeType.TABLES || type === TreeNodeType.TABLE) {
      Text('▤')
        .fontSize(14)
        .fontColor(COLORS.NODE_TABLE)
        .margin({ right: 6 })
    } else if (type === TreeNodeType.VIEWS || type === TreeNodeType.VIEW) {
      Text('◉')
        .fontSize(14)
        .fontColor(COLORS.NODE_VIEW)
        .margin({ right: 6 })
    } else if (type === TreeNodeType.INDEXES || type === TreeNodeType.INDEX) {
      Text('◈')
        .fontSize(14)
        .fontColor(COLORS.NODE_INDEX)
        .margin({ right: 6 })
    } else if (type === TreeNodeType.COLUMN) {
      Circle()
        .width(6)
        .height(6)
        .fill(COLORS.NODE_COLUMN)
        .margin({ right: 8 })
    } else {
      Text('•')
        .fontSize(14)
        .fontColor(COLORS.TEXT_MUTED)
        .margin({ right: 6 })
    }
  }

  /**
   * 切换节点展开/折叠状态
   */
  toggleNode(id: string) {
    if (this.expandedNodes.has(id)) {
      this.expandedNodes.delete(id);
    } else {
      this.expandedNodes.add(id);
    }
    this.expandedNodes = new Set(this.expandedNodes);
  }

  /**
   * 节点点击处理
   */
  onNodeClicked(node: TreeNode) {
    this.selectedNodeId = node.id;

    // 如果是表节点，更新当前选中的表名
    if (node.type === TreeNodeType.TABLE) {
      this.currentTableName = node.name;
    }

    // 如果有子节点，展开/折叠
    if (node.children && node.children.length > 0) {
      this.toggleNode(node.id);
    }

    // 触发回调
    if (this.onNodeClick) {
      this.onNodeClick(node);
    }
  }

  /**
   * 加载Schema数据
   */
  async loadSchema() {
    this.isLoading = true;

    try {
      const schema = await SchemaService.getDatabaseSchema();

      // 构建树形结构
      const dbName = schema.databaseName;

      const rootNode = new TreeNode();
      rootNode.id = 'database';
      rootNode.name = dbName;
      rootNode.type = TreeNodeType.DATABASE;
      rootNode.expanded = true;
      rootNode.children = [];

      // 表节点
      if (schema.tables.length > 0) {
        const tablesNode = new TreeNode();
        tablesNode.id = 'tables';
        tablesNode.name = `表 (${schema.tables.length})`;
        tablesNode.type = TreeNodeType.TABLES;
        tablesNode.children = [];
        for (let i = 0; i < schema.tables.length; i++) {
          const t = schema.tables[i];
          tablesNode.children?.push(this.createTableNode(t));
        }
        rootNode.children?.push(tablesNode);
      }

      // 视图节点
      if (schema.views.length > 0) {
        const viewsNode = new TreeNode();
        viewsNode.id = 'views';
        viewsNode.name = `视图 (${schema.views.length})`;
        viewsNode.type = TreeNodeType.VIEWS;
        viewsNode.children = [];
        for (let i = 0; i < schema.views.length; i++) {
          const v = schema.views[i];
          viewsNode.children?.push(this.createViewNode(v));
        }
        rootNode.children?.push(viewsNode);
      }

      // 索引节点
      if (schema.indexes.length > 0) {
        // 按表分组索引
        const tableIndexes = new Map<string, IndexInfo[]>();
        for (let i = 0; i < schema.indexes.length; i++) {
          const idx = schema.indexes[i];
          if (!tableIndexes.has(idx.tableName)) {
            tableIndexes.set(idx.tableName, []);
          }
          const arr = tableIndexes.get(idx.tableName);
          if (arr) {
            arr.push(idx);
          }
        }

        const indexesNode = new TreeNode();
        indexesNode.id = 'indexes';
        indexesNode.name = `索引 (${schema.indexes.length})`;
        indexesNode.type = TreeNodeType.INDEXES;
        indexesNode.children = [];

        const keys = tableIndexes.keys();
        let keyIndex = 0;
        while (true) {
          const iterResult = keys.next();
          if (iterResult.done === true) {
            break;
          }
          const tableName = iterResult.value;
          if (tableName === undefined) {
            break;
          }
          const indexes = tableIndexes.get(tableName);
          if (indexes) {
            const tableNode = new TreeNode();
            tableNode.id = `index_table_${tableName}`;
            tableNode.name = tableName;
            tableNode.type = TreeNodeType.TABLE;
            const idxChildren: TreeNode[] = [];
            for (let j = 0; j < indexes.length; j++) {
              const idx = indexes[j];
              const childNode = new TreeNode();
              childNode.id = `index_${idx.name}`;
              childNode.name = idx.name;
              childNode.type = TreeNodeType.INDEX;
              childNode.data = idx;
              idxChildren.push(childNode);
            }
            tableNode.children = idxChildren;
            indexesNode.children?.push(tableNode);
          }
          keyIndex++;
        }

        rootNode.children?.push(indexesNode);
      }

      this.treeData = [rootNode];

      // 默认展开
      this.expandedNodes.add('database');
      this.expandedNodes.add('tables');
      this.expandedNodes = new Set(this.expandedNodes);

      hilog.info(DOMAIN, 'SchemaTree', 'Schema loaded: %{public}d tables', schema.tables.length);
    } catch (error) {
      hilog.error(DOMAIN, 'SchemaTree', 'Failed to load schema: %{public}s',
        JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 创建表节点
   */
  private createTableNode(table: TableInfo): TreeNode {
    const children: TreeNode[] = [];
    for (let i = 0; i < table.columns.length; i++) {
      const col = table.columns[i];
      const childNode = new TreeNode();
      childNode.id = `col_${table.name}_${col.name}`;
      childNode.name = `${col.name} (${col.dataType}${col.primaryKey ? ', PK' : ''})`;
      childNode.type = TreeNodeType.COLUMN;
      childNode.data = col;
      children.push(childNode);
    }

    const node = new TreeNode();
    node.id = `table_${table.name}`;
    node.name = table.name;
    node.type = TreeNodeType.TABLE;
    node.data = table;
    node.children = children;
    return node;
  }

  /**
   * 创建视图节点
   */
  private createViewNode(view: TableInfo): TreeNode {
    const node = new TreeNode();
    node.id = `view_${view.name}`;
    node.name = view.name;
    node.type = TreeNodeType.VIEW;
    node.data = view;
    return node;
  }

  /**
   * 创建索引表节点
   */
  private createIndexTableNode(tableName: string, indexes: IndexInfo[]): TreeNode {
    const children: TreeNode[] = [];
    for (let i = 0; i < indexes.length; i++) {
      const idx = indexes[i];
      const childNode = new TreeNode();
      childNode.id = `index_${idx.name}`;
      childNode.name = idx.name;
      childNode.type = TreeNodeType.INDEX;
      childNode.data = idx;
      children.push(childNode);
    }

    const node = new TreeNode();
    node.id = `index_table_${tableName}`;
    node.name = tableName;
    node.type = TreeNodeType.TABLE;
    node.children = children;
    return node;
  }

  /**
   * 注册节点点击回调
   */
  setOnNodeClick(callback: (node: TreeNode) => void) {
    this.onNodeClick = callback;
  }
}
