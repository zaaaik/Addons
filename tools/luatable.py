"""Lectura de archivos SavedVariables de WoW y escritura de literales Lua, sin dependencias."""
import re

_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)")
_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
             "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
        "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class _Parser:
    def __init__(self, src):
        self.s = src
        self.i = 0

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise ValueError("%s (línea %d)" % (msg, line))

    def skip(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif s.startswith("--", self.i):
                m = re.match(r"--\[(=*)\[", s[self.i:])
                if m:
                    end = s.find("]" + m.group(1) + "]", self.i)
                    self.i = len(s) if end < 0 else end + len(m.group(1)) + 2
                else:
                    end = s.find("\n", self.i)
                    self.i = len(s) if end < 0 else end + 1
            else:
                break

    def peek(self):
        self.skip()
        return self.s[self.i] if self.i < len(self.s) else ""

    def expect(self, ch):
        if self.peek() != ch:
            self.error("Se esperaba %r" % ch)
        self.i += 1

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = bytearray()
        s = self.s
        while True:
            if self.i >= len(s):
                self.error("Cadena sin cerrar")
            c = s[self.i]
            if c == q:
                self.i += 1
                return out.decode("utf-8", errors="replace")
            if c == "\\":
                e = s[self.i + 1]
                if e.isdigit():
                    m = re.match(r"\d{1,3}", s[self.i + 1:])
                    out.append(int(m.group(0)))
                    self.i += 1 + len(m.group(0))
                    continue
                out += _ESC.get(e, e).encode("utf-8")
                self.i += 2
                continue
            out += c.encode("utf-8")
            self.i += 1

    def value(self):
        c = self.peek()
        if c in "\"'":
            return self.string()
        if c == "{":
            return self.table()
        if c == "[" and re.match(r"\[=*\[", self.s[self.i:]):
            m = re.match(r"\[(=*)\[\n?", self.s[self.i:])
            end = self.s.find("]" + m.group(1) + "]", self.i)
            text = self.s[self.i + len(m.group(0)):end]
            self.i = end + len(m.group(1)) + 2
            return text
        m = _NUMBER.match(self.s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            if t.lower().startswith(("0x", "-0x")):
                return int(t, 16)
            return float(t) if any(ch in t for ch in ".eE") else int(t)
        m = _NAME.match(self.s, self.i)
        if m:
            self.i = m.end()
            word = m.group(0)
            if word == "true":
                return True
            if word == "false":
                return False
            if word == "nil":
                return None
        self.error("Valor no reconocido")

    def table(self):
        self.expect("{")
        result, index = {}, 1
        while True:
            c = self.peek()
            if c == "}":
                self.i += 1
                break
            if c == "[" and not re.match(r"\[=*\[", self.s[self.i:]):
                self.i += 1
                key = self.value()
                self.expect("]")
                self.expect("=")
                result[key] = self.value()
            else:
                m = _NAME.match(self.s, self.i)
                save = self.i
                if m and m.group(0) not in ("true", "false", "nil"):
                    self.i = m.end()
                    if self.peek() == "=":
                        self.i += 1
                        result[m.group(0)] = self.value()
                    else:
                        self.i = save
                        result[index] = self.value()
                        index += 1
                else:
                    result[index] = self.value()
                    index += 1
            if self.peek() in ",;":
                self.i += 1
        return result


def loads_savedvariables(src):
    """Devuelve {NombreVariable: valor} de un archivo SavedVariables."""
    p = _Parser(src)
    out = {}
    while p.peek():
        m = _NAME.match(p.s, p.i)
        if not m:
            p.error("Se esperaba una asignación")
        p.i = m.end()
        p.expect("=")
        out[m.group(0)] = p.value()
    return out


def load_savedvariables(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return loads_savedvariables(f.read())


def lua_string(s):
    out = ['"']
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ord(ch) < 32:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda k: (not isinstance(k, str), str(k))):
            key = k if isinstance(k, str) and _NAME.fullmatch(k) and k not in _KEYWORDS else "[%s]" % lua_value(k)
            parts.append("%s=%s" % (key, lua_value(v[k])))
        return "{" + ",".join(parts) + "}"
    raise TypeError("Tipo no soportado: %r" % type(v))
