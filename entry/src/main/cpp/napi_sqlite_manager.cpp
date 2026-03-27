/**
 * NAPI SQLite Manager - ArkTS与Native SQLite的绑定层
 * PanoDB Project
 */
#include <string>
#include <vector>
#include <mutex>
#include <napi.h>
#include "sqlite_manager.h"

namespace {
    SqliteManager* g_manager = nullptr;
    std::mutex g_mutex;
}

// 获取全局管理器实例
static SqliteManager* GetManager() {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_manager) {
        g_manager = new SqliteManager();
    }
    return g_manager;
}

// 工具函数：将C++ std::string 转换为 NAPI String
static napi_value CreateJsString(napi_env env, const std::string& str) {
    napi_value result;
    napi_create_string_utf8(env, str.c_str(), NAPI_AUTO_LENGTH, &result);
    return result;
}

// 工具函数：将C++ bool转换为NAPI Boolean
static napi_value CreateJsBoolean(napi_env env, bool value) {
    napi_value result;
    napi_get_boolean(env, value, &result);
    return result;
}

// 工具函数：将C++ int转换为NAPI Number
static napi_value CreateJsNumber(napi_env env, int value) {
    napi_value result;
    napi_create_int32(env, value, &result);
    return result;
}

// 工具函数：将C++ int64转换为NAPI Number
static napi_value CreateJsInt64(napi_env env, int64_t value) {
    napi_value result;
    napi_create_int64(env, value, &result);
    return result;
}

// 工具函数：创建NAPI数组
static napi_value CreateJsArray(napi_env env, size_t length) {
    napi_value result;
    napi_create_array_with_length(env, length, &result);
    return result;
}

// 工具函数：设置数组元素
static void SetArrayElement(napi_env env, napi_value array, size_t index, napi_value element) {
    napi_set_element(env, array, index, element);
}

// ==================== Open Database ====================
napi_value OpenDatabase(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing database path argument");
        return nullptr;
    }

    // 获取数据库路径
    char dbPath[512];
    size_t pathLen;
    napi_get_value_string_utf8(env, args[0], dbPath, sizeof(dbPath), &pathLen);

    SqliteManager* manager = GetManager();
    bool success = manager->openDatabase(dbPath);

    napi_value result;
    napi_create_object(env, &result);

    napi_value jsSuccess;
    napi_get_boolean(env, success, &jsSuccess);
    napi_set_named_property(env, result, "success", jsSuccess);

    if (!success) {
        napi_value jsError = CreateJsString(env, manager->getLastError());
        napi_set_named_property(env, result, "error", jsError);
    }

    return result;
}

// ==================== Close Database ====================
napi_value CloseDatabase(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();
    bool success = manager->closeDatabase();

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

// ==================== Get Tables ====================
napi_value GetTables(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();
    std::vector<TableInfo> tables = manager->getTables();

    napi_value result;
    napi_create_array_with_length(env, tables.size(), &result);

    for (size_t i = 0; i < tables.size(); ++i) {
        napi_value jsTable;
        napi_create_object(env, &jsTable);

        napi_set_named_property(env, jsTable, "name", CreateJsString(env, tables[i].name));
        napi_set_named_property(env, jsTable, "type", CreateJsString(env, tables[i].type));
        napi_set_named_property(env, jsTable, "rowCount", CreateJsNumber(env, tables[i].rowCount));

        // Columns array
        napi_value jsColumns;
        napi_create_array_with_length(env, tables[i].columns.size(), &jsColumns);
        for (size_t j = 0; j < tables[i].columns.size(); ++j) {
            napi_value jsCol;
            napi_create_object(env, &jsCol);

            napi_set_named_property(env, jsCol, "name", CreateJsString(env, tables[i].columns[j].name));
            napi_set_named_property(env, jsCol, "dataType", CreateJsString(env, tables[i].columns[j].dataType));
            napi_set_named_property(env, jsCol, "notNull", CreateJsBoolean(env, tables[i].columns[j].notNull));
            napi_set_named_property(env, jsCol, "primaryKey", CreateJsBoolean(env, tables[i].columns[j].primaryKey));
            napi_set_named_property(env, jsCol, "defaultValue", CreateJsString(env, tables[i].columns[j].defaultValue));

            napi_set_element(env, jsColumns, j, jsCol);
        }
        napi_set_named_property(env, jsTable, "columns", jsColumns);

        napi_set_element(env, result, i, jsTable);
    }

    return result;
}

// ==================== Get Columns ====================
napi_value GetColumns(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing table name argument");
        return nullptr;
    }

    char tableName[256];
    size_t len;
    napi_get_value_string_utf8(env, args[0], tableName, sizeof(tableName), &len);

    SqliteManager* manager = GetManager();
    std::vector<ColumnInfo> columns = manager->getColumns(tableName);

    napi_value result;
    napi_create_array_with_length(env, columns.size(), &result);

    for (size_t i = 0; i < columns.size(); ++i) {
        napi_value jsCol;
        napi_create_object(env, &jsCol);

        napi_set_named_property(env, jsCol, "name", CreateJsString(env, columns[i].name));
        napi_set_named_property(env, jsCol, "dataType", CreateJsString(env, columns[i].dataType));
        napi_set_named_property(env, jsCol, "notNull", CreateJsBoolean(env, columns[i].notNull));
        napi_set_named_property(env, jsCol, "primaryKey", CreateJsBoolean(env, columns[i].primaryKey));
        napi_set_named_property(env, jsCol, "defaultValue", CreateJsString(env, columns[i].defaultValue));

        napi_set_element(env, result, i, jsCol);
    }

    return result;
}

// ==================== Get Indexes ====================
napi_value GetIndexes(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string tableName;
    if (argc >= 1) {
        char name[256];
        size_t len;
        napi_get_value_string_utf8(env, args[0], name, sizeof(name), &len);
        tableName = name;
    }

    SqliteManager* manager = GetManager();
    std::vector<IndexInfo> indexes = manager->getIndexes(tableName);

    napi_value result;
    napi_create_array_with_length(env, indexes.size(), &result);

    for (size_t i = 0; i < indexes.size(); ++i) {
        napi_value jsIndex;
        napi_create_object(env, &jsIndex);

        napi_set_named_property(env, jsIndex, "name", CreateJsString(env, indexes[i].name));
        napi_set_named_property(env, jsIndex, "tableName", CreateJsString(env, indexes[i].tableName));
        napi_set_named_property(env, jsIndex, "unique", CreateJsBoolean(env, indexes[i].unique));

        napi_value jsColumns;
        napi_create_array_with_length(env, indexes[i].columns.size(), &jsColumns);
        for (size_t j = 0; j < indexes[i].columns.size(); ++j) {
            napi_set_element(env, jsColumns, j, CreateJsString(env, indexes[i].columns[j]));
        }
        napi_set_named_property(env, jsIndex, "columns", jsColumns);

        napi_set_element(env, result, i, jsIndex);
    }

    return result;
}

// ==================== Execute SQL ====================
napi_value ExecuteSql(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing SQL argument");
        return nullptr;
    }

    // 获取SQL语句
    char sql[8192];
    size_t sqlLen;
    napi_get_value_string_utf8(env, args[0], sql, sizeof(sql), &sqlLen);

    // 获取参数数组（可选）
    std::vector<std::string> bindArgs;
    if (argc >= 2) {
        bool isArray = false;
        napi_is_array(env, args[1], &isArray);
        if (isArray) {
            uint32_t argsLength = 0;
            napi_get_array_length(env, args[1], &argsLength);
            for (uint32_t i = 0; i < argsLength; ++i) {
                napi_value jsValue;
                napi_get_element(env, args[1], i, &jsValue);

                char argValue[4096];
                size_t argLen;
                napi_get_value_string_utf8(env, jsValue, argValue, sizeof(argValue), &argLen);
                bindArgs.push_back(argValue);
            }
        }
    }

    SqliteManager* manager = GetManager();
    QueryResult qr = manager->execute(sql, bindArgs);

    napi_value result;
    napi_create_object(env, &result);

    napi_set_named_property(env, result, "success", CreateJsBoolean(env, qr.success));

    // Columns
    napi_value jsColumns;
    napi_create_array_with_length(env, qr.columns.size(), &jsColumns);
    for (size_t i = 0; i < qr.columns.size(); ++i) {
        napi_set_element(env, jsColumns, i, CreateJsString(env, qr.columns[i]));
    }
    napi_set_named_property(env, result, "columns", jsColumns);

    // Rows
    napi_value jsRows;
    napi_create_array_with_length(env, qr.rows.size(), &jsRows);
    for (size_t i = 0; i < qr.rows.size(); ++i) {
        napi_value jsRow;
        napi_create_array_with_length(env, qr.rows[i].size(), &jsRow);
        for (size_t j = 0; j < qr.rows[i].size(); ++j) {
            napi_set_element(env, jsRow, j, CreateJsString(env, qr.rows[i][j]));
        }
        napi_set_element(env, jsRows, i, jsRow);
    }
    napi_set_named_property(env, result, "rows", jsRows);

    napi_set_named_property(env, result, "affectedRows", CreateJsNumber(env, qr.affectedRows));
    napi_set_named_property(env, result, "executionTime", CreateJsInt64(env, qr.executionTime));

    if (!qr.error.empty()) {
        napi_set_named_property(env, result, "error", CreateJsString(env, qr.error));
    }

    return result;
}

// ==================== Explain Query ====================
napi_value ExplainQuery(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing SQL argument");
        return nullptr;
    }

    char sql[8192];
    size_t sqlLen;
    napi_get_value_string_utf8(env, args[0], sql, sizeof(sql), &sqlLen);

    SqliteManager* manager = GetManager();
    std::string plan = manager->explain(sql);

    return CreateJsString(env, plan);
}

// ==================== Transaction ====================
napi_value BeginTransaction(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();
    bool success = manager->beginTransaction();
    return CreateJsBoolean(env, success);
}

napi_value CommitTransaction(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();
    bool success = manager->commit();
    return CreateJsBoolean(env, success);
}

napi_value RollbackTransaction(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();
    bool success = manager->rollback();
    return CreateJsBoolean(env, success);
}

// ==================== Get Database Info ====================
napi_value GetDatabaseInfo(napi_env env, napi_callback_info info) {
    SqliteManager* manager = GetManager();

    napi_value result;
    napi_create_object(env, &result);

    napi_set_named_property(env, result, "path", CreateJsString(env, manager->getDatabasePath()));
    napi_set_named_property(env, result, "isOpen", CreateJsBoolean(env, manager->isOpen()));

    return result;
}

// ==================== Module Init ====================
napi_value Init(napi_env env, napi_value exports) {
    napi_value fn;

    // Database operations
    napi_create_function(env, nullptr, 0, OpenDatabase, nullptr, &fn);
    napi_set_named_property(env, exports, "openDatabase", fn);

    napi_create_function(env, nullptr, 0, CloseDatabase, nullptr, &fn);
    napi_set_named_property(env, exports, "closeDatabase", fn);

    napi_create_function(env, nullptr, 0, GetTables, nullptr, &fn);
    napi_set_named_property(env, exports, "getTables", fn);

    napi_create_function(env, nullptr, 0, GetColumns, nullptr, &fn);
    napi_set_named_property(env, exports, "getColumns", fn);

    napi_create_function(env, nullptr, 0, GetIndexes, nullptr, &fn);
    napi_set_named_property(env, exports, "getIndexes", fn);

    napi_create_function(env, nullptr, 0, ExecuteSql, nullptr, &fn);
    napi_set_named_property(env, exports, "executeSql", fn);

    napi_create_function(env, nullptr, 0, ExplainQuery, nullptr, &fn);
    napi_set_named_property(env, exports, "explainQuery", fn);

    napi_create_function(env, nullptr, 0, BeginTransaction, nullptr, &fn);
    napi_set_named_property(env, exports, "beginTransaction", fn);

    napi_create_function(env, nullptr, 0, CommitTransaction, nullptr, &fn);
    napi_set_named_property(env, exports, "commitTransaction", fn);

    napi_create_function(env, nullptr, 0, RollbackTransaction, nullptr, &fn);
    napi_set_named_property(env, exports, "rollbackTransaction", fn);

    napi_create_function(env, nullptr, 0, GetDatabaseInfo, nullptr, &fn);
    napi_set_named_property(env, exports, "getDatabaseInfo", fn);

    return exports;
}

NAPI_MODULE(panodb_sqlite, Init)
