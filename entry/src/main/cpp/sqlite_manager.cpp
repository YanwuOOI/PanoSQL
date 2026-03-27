/**
 * SQLite Manager - Native SQLite数据库操作实现
 * PanoDB Project
 */
#include "sqlite_manager.h"
#include <chrono>
#include <sstream>

SqliteManager::SqliteManager() : m_db(nullptr), m_inTransaction(false) {
}

SqliteManager::~SqliteManager() {
    if (m_db) {
        sqlite3_close(m_db);
        m_db = nullptr;
    }
}

bool SqliteManager::openDatabase(const std::string& path) {
    if (m_db) {
        closeDatabase();
    }

    int result = sqlite3_open(path.c_str(), &m_db);
    if (result != SQLITE_OK) {
        return false;
    }
    m_dbPath = path;
    return true;
}

bool SqliteManager::closeDatabase() {
    if (m_db) {
        if (m_inTransaction) {
            rollback();
        }
        sqlite3_close(m_db);
        m_db = nullptr;
        m_dbPath = "";
        return true;
    }
    return false;
}

std::vector<std::string> SqliteManager::getTableNames() {
    std::vector<std::string> tables;
    if (!m_db) return tables;

    const char* sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name";
    sqlite3_stmt* stmt;

    if (sqlite3_prepare_v2(m_db, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char* name = (const char*)sqlite3_column_text(stmt, 0);
            if (name) {
                tables.push_back(name);
            }
        }
    }
    sqlite3_finalize(stmt);
    return tables;
}

std::vector<std::string> SqliteManager::getViewNames() {
    std::vector<std::string> views;
    if (!m_db) return views;

    const char* sql = "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name";
    sqlite3_stmt* stmt;

    if (sqlite3_prepare_v2(m_db, sql, -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char* name = (const char*)sqlite3_column_text(stmt, 0);
            if (name) {
                views.push_back(name);
            }
        }
    }
    sqlite3_finalize(stmt);
    return views;
}

std::vector<ColumnInfo> SqliteManager::getColumns(const std::string& tableName) {
    std::vector<ColumnInfo> columns;
    if (!m_db) return columns;

    std::string sql = "PRAGMA table_info('" + tableName + "')";
    sqlite3_stmt* stmt;

    if (sqlite3_prepare_v2(m_db, sql.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            ColumnInfo col;
            col.name = (const char*)sqlite3_column_text(stmt, 1) ? (const char*)sqlite3_column_text(stmt, 1) : "";
            col.dataType = (const char*)sqlite3_column_text(stmt, 2) ? (const char*)sqlite3_column_text(stmt, 2) : "";
            col.notNull = sqlite3_column_int(stmt, 3) != 0;
            col.defaultValue = "";
            if (sqlite3_column_type(stmt, 4) != SQLITE_NULL) {
                col.defaultValue = (const char*)sqlite3_column_text(stmt, 4) ? (const char*)sqlite3_column_text(stmt, 4) : "";
            }
            col.primaryKey = sqlite3_column_int(stmt, 5) != 0;
            columns.push_back(col);
        }
    }
    sqlite3_finalize(stmt);
    return columns;
}

std::vector<TableInfo> SqliteManager::getTables() {
    std::vector<TableInfo> tables;
    if (!m_db) return tables;

    // Get tables
    std::vector<std::string> tableNames = getTableNames();
    for (const auto& name : tableNames) {
        TableInfo info;
        info.name = name;
        info.type = "table";
        info.rowCount = getRowCount(name);
        info.columns = getColumns(name);
        tables.push_back(info);
    }

    // Get views
    std::vector<std::string> viewNames = getViewNames();
    for (const auto& name : viewNames) {
        TableInfo info;
        info.name = name;
        info.type = "view";
        info.rowCount = 0;
        info.columns = getColumns(name);
        tables.push_back(info);
    }

    return tables;
}

std::vector<IndexInfo> SqliteManager::getIndexes(const std::string& tableName) {
    std::vector<IndexInfo> indexes;
    if (!m_db) return indexes;

    std::string sql;
    if (tableName.empty()) {
        sql = "SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'";
    } else {
        sql = "SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' AND tbl_name='" + tableName + "'";
    }

    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(m_db, sql.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            IndexInfo info;
            info.name = (const char*)sqlite3_column_text(stmt, 0) ? (const char*)sqlite3_column_text(stmt, 0) : "";
            info.tableName = (const char*)sqlite3_column_text(stmt, 1) ? (const char*)sqlite3_column_text(stmt, 1) : "";
            info.unique = false; // Will be determined by PRAGMA

            // Get index info for columns
            std::string indexName = info.name;
            std::string pragmaSql = "PRAGMA index_info('" + indexName + "')";
            sqlite3_stmt* pragmaStmt;
            if (sqlite3_prepare_v2(m_db, pragmaSql.c_str(), -1, &pragmaStmt, nullptr) == SQLITE_OK) {
                while (sqlite3_step(pragmaStmt) == SQLITE_ROW) {
                    const char* colName = (const char*)sqlite3_column_text(pragmaStmt, 2);
                    if (colName) {
                        info.columns.push_back(colName);
                    }
                }
                sqlite3_finalize(pragmaStmt);
            }

            // Check if unique
            std::string uniqueSql = "PRAGMA index_list('" + info.tableName + "')";
            sqlite3_stmt* uniqueStmt;
            if (sqlite3_prepare_v2(m_db, uniqueSql.c_str(), -1, &uniqueStmt, nullptr) == SQLITE_OK) {
                while (sqlite3_step(uniqueStmt) == SQLITE_ROW) {
                    const char* idxName = (const char*)sqlite3_column_text(uniqueStmt, 1);
                    if (idxName && info.name == idxName) {
                        info.unique = sqlite3_column_int(uniqueStmt, 2) != 0;
                        break;
                    }
                }
                sqlite3_finalize(uniqueStmt);
            }

            indexes.push_back(info);
        }
    }
    sqlite3_finalize(stmt);
    return indexes;
}

QueryResult SqliteManager::execute(const std::string& sql, const std::vector<std::string>& args) {
    auto start = std::chrono::high_resolution_clock::now();

    QueryResult result;
    result.success = true;
    result.affectedRows = 0;

    if (!m_db) {
        result.success = false;
        result.error = "Database not opened";
        return result;
    }

    sqlite3_stmt* stmt;
    int prepareResult = sqlite3_prepare_v2(m_db, sql.c_str(), -1, &stmt, nullptr);

    if (prepareResult != SQLITE_OK) {
        result.success = false;
        result.error = sqlite3_errmsg(m_db);
        return result;
    }

    // Bind arguments
    for (size_t i = 0; i < args.size() && i < (size_t)sqlite3_bind_parameter_count(stmt); ++i) {
        sqlite3_bind_text(stmt, i + 1, args[i].c_str(), -1, SQLITE_TRANSIENT);
    }

    // Check if it's a query (has results to return)
    bool isQuery = sqlite3_column_count(stmt) > 0;

    // Execute and collect results
    while (true) {
        int stepResult = sqlite3_step(stmt);
        if (stepResult == SQLITE_ROW) {
            if (result.columns.empty()) {
                int colCount = sqlite3_column_count(stmt);
                for (int i = 0; i < colCount; ++i) {
                    const char* colName = sqlite3_column_name(stmt, i);
                    result.columns.push_back(colName ? colName : "");
                }
            }
            std::vector<std::string> row;
            int colCount = sqlite3_column_count(stmt);
            for (int i = 0; i < colCount; ++i) {
                switch (sqlite3_column_type(stmt, i)) {
                    case SQLITE_NULL:
                        row.push_back("NULL");
                        break;
                    case SQLITE_INTEGER:
                        row.push_back(std::to_string(sqlite3_column_int64(stmt, i)));
                        break;
                    case SQLITE_FLOAT:
                        row.push_back(std::to_string(sqlite3_column_double(stmt, i)));
                        break;
                    case SQLITE_TEXT:
                        row.push_back((const char*)sqlite3_column_text(stmt, i) ? (const char*)sqlite3_column_text(stmt, i) : "");
                        break;
                    case SQLITE_BLOB:
                        row.push_back("[BLOB]");
                        break;
                    default:
                        row.push_back("");
                        break;
                }
            }
            result.rows.push_back(row);
        } else if (stepResult == SQLITE_DONE) {
            result.affectedRows = sqlite3_changes(m_db);
            break;
        } else {
            result.success = false;
            result.error = sqlite3_errmsg(m_db);
            break;
        }
    }

    sqlite3_finalize(stmt);

    auto end = std::chrono::high_resolution_clock::now();
    result.executionTime = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    return result;
}

QueryResult SqliteManager::rawQuery(const std::string& sql) {
    return execute(sql, {});
}

std::string SqliteManager::explain(const std::string& sql) {
    if (!m_db) return "";

    std::string explainSql = "EXPLAIN QUERY PLAN " + sql;
    QueryResult result = execute(explainSql);

    std::string output;
    for (const auto& row : result.rows) {
        for (const auto& cell : row) {
            output += cell + " ";
        }
        output += "\n";
    }
    return output;
}

bool SqliteManager::beginTransaction() {
    if (!m_db || m_inTransaction) return false;
    execute("BEGIN TRANSACTION");
    m_inTransaction = true;
    return true;
}

bool SqliteManager::commit() {
    if (!m_db || !m_inTransaction) return false;
    execute("COMMIT");
    m_inTransaction = false;
    return true;
}

bool SqliteManager::rollback() {
    if (!m_db || !m_inTransaction) return false;
    execute("ROLLBACK");
    m_inTransaction = false;
    return true;
}

std::string SqliteManager::getTableDDL(const std::string& tableName) {
    if (!m_db) return "";

    std::string sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name='" + tableName + "'";
    QueryResult result = execute(sql);

    if (result.success && result.rows.size() > 0 && result.rows[0].size() > 0) {
        return result.rows[0][0];
    }
    return "";
}

int SqliteManager::getRowCount(const std::string& tableName) {
    std::string sql = "SELECT COUNT(*) FROM " + tableName;
    QueryResult result = execute(sql);

    if (result.success && result.rows.size() > 0 && result.rows[0].size() > 0) {
        try {
            return std::stoi(result.rows[0][0]);
        } catch (...) {
            return 0;
        }
    }
    return 0;
}

std::string SqliteManager::getLastError() {
    if (m_db) {
        return sqlite3_errmsg(m_db);
    }
    return "No database connection";
}
