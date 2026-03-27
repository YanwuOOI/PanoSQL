/**
 * SQLite Manager - Native SQLite数据库操作接口
 * PanoDB Project
 */
#ifndef SQLite_MANAGER_H
#define SQLite_MANAGER_H

#include <string>
#include <vector>
#include <sqlite3.h>

struct ColumnInfo {
    std::string name;
    std::string dataType;
    bool notNull;
    bool primaryKey;
    std::string defaultValue;
};

struct TableInfo {
    std::string name;
    std::string type;  // "table" or "view"
    int rowCount;
    std::vector<ColumnInfo> columns;
};

struct IndexInfo {
    std::string name;
    std::string tableName;
    bool unique;
    std::vector<std::string> columns;
};

struct QueryResult {
    bool success;
    std::vector<std::string> columns;
    std::vector<std::vector<std::string>> rows;
    int affectedRows;
    long long executionTime;
    std::string error;
};

class SqliteManager {
public:
    SqliteManager();
    ~SqliteManager();

    // 数据库操作
    bool openDatabase(const std::string& path);
    bool closeDatabase();
    bool isOpen() const { return m_db != nullptr; }
    std::string getDatabasePath() const { return m_dbPath; }

    // Schema操作
    std::vector<std::string> getTableNames();
    std::vector<std::string> getViewNames();
    std::vector<TableInfo> getTables();
    std::vector<IndexInfo> getIndexes(const std::string& tableName = "");
    std::vector<ColumnInfo> getColumns(const std::string& tableName);

    // SQL执行
    QueryResult execute(const std::string& sql, const std::vector<std::string>& args = {});
    QueryResult rawQuery(const std::string& sql);
    std::string explain(const std::string& sql);

    // 事务
    bool beginTransaction();
    bool commit();
    bool rollback();

    // 工具
    std::string getTableDDL(const std::string& tableName);
    int getRowCount(const std::string& tableName);

private:
    sqlite3* m_db;
    std::string m_dbPath;
    bool m_inTransaction;

    // 内部方法
    QueryResult executeInternal(const std::string& sql, bool isQuery);
    std::string getLastError();
};

#endif // SQLite_MANAGER_H
