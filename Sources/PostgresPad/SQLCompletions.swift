import Foundation

/// Static completion vocabulary for the SQL editor. Schema identifiers
/// (tables/columns) from the live connection are merged in on top.
enum SQLCompletions {
    static let keywords: [String] = [
        "SELECT", "FROM", "WHERE", "GROUP BY", "ORDER BY", "HAVING",
        "LIMIT", "OFFSET", "DISTINCT", "AS", "ASC", "DESC",
        "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM", "RETURNING",
        "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN",
        "CROSS JOIN", "ON", "USING",
        "AND", "OR", "NOT", "NULL", "IS NULL", "IS NOT NULL",
        "IN", "EXISTS", "BETWEEN", "LIKE", "ILIKE",
        "UNION", "UNION ALL", "INTERSECT", "EXCEPT",
        "CASE", "WHEN", "THEN", "ELSE", "END",
        "WITH", "RECURSIVE",
        "CREATE TABLE", "CREATE INDEX", "CREATE VIEW", "CREATE SCHEMA",
        "ALTER TABLE", "DROP TABLE", "DROP INDEX", "TRUNCATE",
        "ADD COLUMN", "DROP COLUMN", "RENAME TO",
        "PRIMARY KEY", "FOREIGN KEY", "REFERENCES", "UNIQUE",
        "DEFAULT", "CONSTRAINT", "CHECK",
        "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT",
        "EXPLAIN", "ANALYZE", "VACUUM",
        "GRANT", "REVOKE", "CAST",
        "NULLS FIRST", "NULLS LAST", "FETCH FIRST",
        "CURRENT_DATE", "CURRENT_TIMESTAMP", "CURRENT_USER", "INTERVAL"
    ]

    static let functions: [String] = [
        "count", "sum", "avg", "min", "max",
        "coalesce", "nullif", "greatest", "least",
        "now", "age", "date_trunc", "extract", "to_char", "to_date",
        "to_timestamp", "make_interval",
        "lower", "upper", "initcap", "length", "trim", "substring",
        "replace", "concat", "split_part", "position", "left", "right",
        "round", "floor", "ceil", "abs", "random", "power", "sqrt",
        "array_agg", "string_agg", "json_agg", "jsonb_agg",
        "jsonb_build_object", "unnest", "generate_series",
        "row_number", "rank", "dense_rank", "lag", "lead",
        "gen_random_uuid"
    ]

    static let all: [String] = keywords + functions
}
