"""Lector mínimo de volcados MySQL (CREATE TABLE + INSERT INTO ... VALUES) sin dependencias."""
import re

_ESCAPES = {"n": "\n", "r": "\r", "t": "\t", "0": "\0", "Z": "\x1a", "b": "\b"}


def columns(sql, table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\n\)\s*ENGINE" % re.escape(table), sql, re.S)
    if not m:
        raise ValueError("No se encontró CREATE TABLE `%s`" % table)
    return re.findall(r"^\s+`(\w+)`", m.group(1), re.M)


def _rows(sql, table):
    marker = "INSERT INTO `%s`" % table
    n = len(sql)
    i = 0
    while True:
        i = sql.find(marker, i)
        if i < 0:
            return
        i = sql.index("VALUES", i) + 6
        while True:
            while sql[i] in " \t\r\n,":
                i += 1
            if sql[i] == ";":
                break
            if sql[i] != "(":
                raise ValueError("SQL inesperado cerca de: %r" % sql[i:i + 40])
            i += 1
            row = []
            while True:
                while sql[i] in " \t\r\n":
                    i += 1
                if sql[i] == "'":
                    i += 1
                    buf = []
                    while True:
                        c = sql[i]
                        if c == "\\":
                            e = sql[i + 1]
                            buf.append(_ESCAPES.get(e, e))
                            i += 2
                        elif c == "'":
                            if i + 1 < n and sql[i + 1] == "'":
                                buf.append("'")
                                i += 2
                            else:
                                i += 1
                                break
                        else:
                            buf.append(c)
                            i += 1
                    row.append("".join(buf))
                else:
                    j = i
                    while sql[j] not in ",)":
                        j += 1
                    v = sql[i:j].strip()
                    i = j
                    row.append(None if v.upper() == "NULL" else v)
                while sql[i] in " \t\r\n":
                    i += 1
                if sql[i] == ",":
                    i += 1
                    continue
                if sql[i] == ")":
                    i += 1
                    break
                raise ValueError("SQL inesperado cerca de: %r" % sql[i:i + 40])
            yield row


def load_table(sql, table):
    """Devuelve las filas de `table` como lista de diccionarios {columna: valor}."""
    cols = columns(sql, table)
    return [dict(zip(cols, r)) for r in _rows(sql, table)]


def load_file(path, table):
    with open(path, encoding="utf-8") as f:
        return load_table(f.read(), table)
