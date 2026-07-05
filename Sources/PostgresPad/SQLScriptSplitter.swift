import Foundation

/// Splits a SQL script into individual statements on `;`, respecting
/// single-quoted strings, double-quoted identifiers, dollar-quoted strings,
/// line comments and (nested) block comments. Postgres' extended query
/// protocol only accepts one statement per query, so the console runs the
/// pieces sequentially.
enum SQLScriptSplitter {
    static func split(_ script: String) -> [String] {
        var statements: [String] = []
        var current = ""
        let chars = Array(script)
        var i = 0

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                statements.append(trimmed)
            }
            current = ""
        }

        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : nil

            switch c {
            case ";":
                flush()
                i += 1

            case "'":
                // Single-quoted string; '' is an escaped quote.
                current.append(c)
                i += 1
                while i < chars.count {
                    current.append(chars[i])
                    if chars[i] == "'" {
                        if i + 1 < chars.count && chars[i + 1] == "'" {
                            current.append(chars[i + 1])
                            i += 2
                            continue
                        }
                        i += 1
                        break
                    }
                    i += 1
                }

            case "\"":
                // Double-quoted identifier; "" is an escaped quote.
                current.append(c)
                i += 1
                while i < chars.count {
                    current.append(chars[i])
                    if chars[i] == "\"" {
                        if i + 1 < chars.count && chars[i + 1] == "\"" {
                            current.append(chars[i + 1])
                            i += 2
                            continue
                        }
                        i += 1
                        break
                    }
                    i += 1
                }

            case "-" where next == "-":
                // Line comment: keep it out of the statement text.
                while i < chars.count && chars[i] != "\n" {
                    i += 1
                }

            case "/" where next == "*":
                // Block comment; Postgres allows nesting.
                var depth = 1
                i += 2
                while i < chars.count && depth > 0 {
                    if chars[i] == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                        depth += 1
                        i += 2
                    } else if chars[i] == "*" && i + 1 < chars.count && chars[i + 1] == "/" {
                        depth -= 1
                        i += 2
                    } else {
                        i += 1
                    }
                }

            case "$":
                // Possible dollar quote: $tag$ ... $tag$
                if let tag = dollarTag(in: chars, at: i) {
                    current.append(contentsOf: tag)
                    i += tag.count
                    // Copy until the matching closing tag.
                    while i < chars.count {
                        if chars[i] == "$", matches(chars, at: i, tag: tag) {
                            current.append(contentsOf: tag)
                            i += tag.count
                            break
                        }
                        current.append(chars[i])
                        i += 1
                    }
                } else {
                    current.append(c)
                    i += 1
                }

            default:
                current.append(c)
                i += 1
            }
        }
        flush()
        return statements
    }

    /// Returns the full dollar-quote tag (e.g. `$$` or `$body$`) starting at
    /// `index`, or nil if this `$` does not open a dollar quote.
    private static func dollarTag(in chars: [Character], at index: Int) -> [Character]? {
        var j = index + 1
        var tag: [Character] = ["$"]
        while j < chars.count {
            let c = chars[j]
            if c == "$" {
                tag.append("$")
                return tag
            }
            if c.isLetter || c.isNumber || c == "_" {
                tag.append(c)
                j += 1
            } else {
                return nil
            }
        }
        return nil
    }

    private static func matches(_ chars: [Character], at index: Int, tag: [Character]) -> Bool {
        guard index + tag.count <= chars.count else { return false }
        for (offset, tagChar) in tag.enumerated() where chars[index + offset] != tagChar {
            return false
        }
        return true
    }
}
