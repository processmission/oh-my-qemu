#!/usr/bin/env python3
"""Parse, validate, and dump the register-semantics RS-IR (v1).

The DSL is a line-oriented Trigger / Condition / Transition rule format.
The vocabulary lives in ../assets/ir-ops.def (DEF(kind, name, arity, flags,
signature)), in the spirit of QEMU's tcg-opc.h opcode table.
"""

import argparse
import os
import re
import sys

VERSION = "1.0"
SYMBOL_KINDS = ("register", "field", "constant", "state", "event", "irq",
                "timer", "fifo", "address")
ACCESS = {"rw", "ro", "wo", "rw1c"}
IRQ_KINDS = {"level", "edge"}
TIERS = {"driver", "companion-test", "hardware"}
CONFIDENCE = {"HIGH", "MEDIUM", "LOW", "CONFLICT"}
IMPLS = {"registerinfo", "manual-mmio", "helper"}
HOOKS = {"pre_write", "post_write", "post_read", "manual", "reset"}
OBSERVE_LOG = {"none", "unimp", "guest_error", "both"}
OBSERVE_ERROR = {"none", "guest_error", "error_report", "assert"}
TRACE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.:-]*$")
ADDRESS_STATUS = {"modeled", "unimplemented", "reserved"}
KNOWN_FLAGS = {"SIDE_EFFECTS", "PURE", "GUEST_VISIBLE", "MIGRATABLE",
               "RESET_AFFECTING", "LOGGING_ONLY", "EXPANDS", "UNSUPPORTED"}
OPERAND_CLASSES = set("BRSITFEMV")
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]*$")
ID_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
NUM_RE = re.compile(r"^-?(?:0[xX][0-9a-fA-F]+|[0-9]+)$")
DEF_RE = re.compile(
    r"^DEF\(\s*([a-z]+)\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(-?\d+)\s*,"
    r"\s*([^,]*)\s*,\s*([^)]*)\s*\)\s*$")


class IrError(Exception):
    def __init__(self, line, message):
        super().__init__(message)
        self.line = line
        self.message = message


class OpDef:
    def __init__(self, kind, name, arity, flags, signature, variadic):
        self.kind = kind
        self.name = name
        self.arity = arity
        self.flags = flags
        self.signature = signature
        self.variadic = variadic

    def classes(self):
        return list(self.signature)


class Vocab:
    def __init__(self, path, ops):
        self.path = path
        self.ops = ops

    def get(self, kind, name):
        return self.ops.get((kind, name))


def load_vocab(path):
    if not os.path.isfile(path):
        raise IrError(0, "vocabulary file not found: %s" % path)
    ops = {}
    with open(path, "r", encoding="utf-8") as handle:
        for lineno, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = DEF_RE.match(line)
            if not match:
                raise IrError(lineno, "invalid DEF line in vocabulary")
            kind, name, arity_text, flags_text, signature_text = match.groups()
            if kind not in ("trigger", "condition", "operation"):
                raise IrError(lineno, "unknown DEF kind: %s" % kind)
            arity = int(arity_text)
            flags = set()
            if flags_text.strip() not in ("", "NONE"):
                flags = set(part.strip() for part in flags_text.split("|"))
                unknown = flags - KNOWN_FLAGS
                if unknown:
                    raise IrError(lineno, "unknown DEF flag(s): %s" %
                                  ",".join(sorted(unknown)))
            signature = []
            variadic = False
            if signature_text.strip() not in ("", "-"):
                for part in signature_text.split(","):
                    cls = part.strip()
                    if cls.endswith("..."):
                        variadic = True
                        cls = cls[:-3]
                    if cls not in OPERAND_CLASSES:
                        raise IrError(lineno, "unknown operand class: %s" % cls)
                    signature.append(cls)
            if variadic:
                if arity != -1:
                    raise IrError(lineno, "variadic signature requires arity -1")
            elif arity < 0 or len(signature) != arity:
                raise IrError(lineno, "arity %d does not match signature %r" %
                              (arity, signature_text.strip()))
            if (kind, name) in ops:
                raise IrError(lineno, "duplicate DEF %s/%s" % (kind, name))
            ops[(kind, name)] = OpDef(kind, name, arity, flags, signature, variadic)
    return Vocab(path, ops)


class Source:
    def __init__(self, ident, citation, line):
        self.ident = ident
        self.citation = citation
        self.line = line


class Symbol:
    def __init__(self, kind, name, attrs, line):
        self.kind = kind
        self.name = name
        self.attrs = attrs
        self.line = line


class Trigger:
    def __init__(self, kind, subject, attrs, line):
        self.kind = kind
        self.subject = subject
        self.attrs = attrs
        self.line = line


class Transition:
    def __init__(self, op, args, explicit_flags, line):
        self.op = op
        self.args = args
        self.explicit_flags = explicit_flags
        self.line = line
        self.effective_flags = set()


class Framework:
    def __init__(self, implementation, hook, rationale, line):
        self.implementation = implementation
        self.hook = hook
        self.rationale = rationale
        self.line = line


class Observe:
    def __init__(self, attrs, line):
        self.attrs = attrs
        self.line = line


class Rule:
    def __init__(self, ident, summary, attrs, line):
        self.ident = ident
        self.summary = summary
        self.attrs = attrs
        self.line = line
        self.trigger = None
        self.condition = None
        self.transitions = []
        self.framework = None
        self.observe = None
        self.qtests = []
        self.gaps = []
        self.expansions = []


class Flow:
    def __init__(self, ident, rule_ids, line):
        self.ident = ident
        self.rule_ids = rule_ids
        self.line = line


class Document:
    def __init__(self, path):
        self.path = path
        self.version = None
        self.target = {}
        self.sources = []
        self.symbols = []
        self.rules = []
        self.flows = []
        self.unresolved = []
        self.symbol_by_name = {}
        self.rule_by_id = {}
        self.source_by_id = {}


class Call:
    def __init__(self, name, args):
        self.name = name
        self.args = args


class Ref:
    def __init__(self, name):
        self.name = name


class Num:
    def __init__(self, raw):
        self.raw = raw


class Str:
    def __init__(self, text):
        self.text = text


def strip_quotes(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        if '"' in text[1:-1]:
            raise IrError(0, "quoted value may not contain a double quote")
        return text[1:-1]
    return text


def parse_attrs(text, line, where, allow_unknown=True):
    attrs = {}
    index = 0
    length = len(text)
    while index < length:
        while index < length and text[index].isspace():
            index += 1
        if index >= length:
            break
        match = re.match(r"([A-Za-z_][A-Za-z0-9_-]*)=", text[index:])
        if not match:
            raise IrError(line, "%s: expected key=value near %r" %
                          (where, text[index:index + 24]))
        key = match.group(1)
        index += len(match.group(0))
        if index < length and text[index] == '"':
            end = text.find('"', index + 1)
            if end < 0:
                raise IrError(line, "%s: unterminated quoted value for %s" %
                              (where, key))
            value = text[index + 1:end]
            index = end + 1
        else:
            start = index
            while index < length and not text[index].isspace():
                index += 1
            value = text[start:index]
        if not value:
            raise IrError(line, "%s: empty value for %s" % (where, key))
        if key in attrs:
            raise IrError(line, "%s: duplicate attribute %s" % (where, key))
        attrs[key] = value
    return attrs


class ExprParser:
    def __init__(self, text, line, where):
        self.text = text
        self.line = line
        self.where = where
        self.pos = 0

    def error(self, message):
        raise IrError(self.line, "%s: %s near %r" %
                      (self.where, message, self.text[self.pos:self.pos + 24]))

    def skip_ws(self):
        while self.pos < len(self.text) and self.text[self.pos].isspace():
            self.pos += 1

    def parse(self):
        node = self.parse_expr()
        self.skip_ws()
        if self.pos != len(self.text):
            self.error("unexpected trailing text")
        return node

    def parse_expr(self):
        self.skip_ws()
        if self.pos >= len(self.text):
            self.error("expected an expression")
        char = self.text[self.pos]
        if char == '"':
            end = self.text.find('"', self.pos + 1)
            if end < 0:
                self.error("unterminated string literal")
            value = self.text[self.pos + 1:end]
            self.pos = end + 1
            return Str(value)
        match = re.match(r"-?(?:0[xX][0-9a-fA-F]+|[0-9]+)", self.text[self.pos:])
        if match and (char != "-" or len(match.group(0)) > 1):
            self.pos += len(match.group(0))
            return Num(match.group(0))
        match = re.match(r"[A-Za-z_][A-Za-z0-9_.-]*", self.text[self.pos:])
        if not match:
            self.error("expected symbol, number, string, or call")
        name = match.group(0)
        self.pos += len(name)
        self.skip_ws()
        if self.pos < len(self.text) and self.text[self.pos] == "(":
            self.pos += 1
            args = []
            self.skip_ws()
            if self.pos < len(self.text) and self.text[self.pos] == ")":
                self.pos += 1
                return Call(name, args)
            while True:
                args.append(self.parse_expr())
                self.skip_ws()
                if self.pos >= len(self.text):
                    self.error("unterminated call")
                if self.text[self.pos] == ")":
                    self.pos += 1
                    return Call(name, args)
                if self.text[self.pos] != ",":
                    self.error("expected ',' or ')'")
                self.pos += 1
        return Ref(name)


def format_expr(node):
    if isinstance(node, Ref):
        return node.name
    if isinstance(node, Num):
        return node.raw
    if isinstance(node, Str):
        return '"%s"' % node.text
    if isinstance(node, Call):
        return "%s(%s)" % (node.name, ", ".join(format_expr(arg) for arg in node.args))
    raise IrError(0, "internal: unknown expression node")


def parse_number(text, line, where):
    if not NUM_RE.match(text):
        raise IrError(line, "%s: expected a number, got %r" % (where, text))
    try:
        return int(text, 0) if text.lower().startswith(("0x", "-0x")) else int(text, 10)
    except ValueError:
        raise IrError(line, "%s: invalid number %r" % (where, text))


def parse_bits(text, line):
    match = re.match(r"^([0-9]+)(?:\.\.([0-9]+))?$", text)
    if not match:
        raise IrError(line, "field bits must be N or N..M, got %r" % text)
    low = int(match.group(1))
    high = int(match.group(2)) if match.group(2) is not None else low
    if high < low:
        raise IrError(line, "field bit range must be ascending, got %r" % text)
    return low, high


class Parser:
    def __init__(self, path, vocab):
        self.path = path
        self.vocab = vocab
        self.doc = Document(path)
        self.current_rule = None
        self.seen_ir = False

    def error(self, line, message):
        raise IrError(line, message)

    def parse(self):
        with open(self.path, "r", encoding="utf-8") as handle:
            for lineno, raw in enumerate(handle, 1):
                line = raw.rstrip("\n")
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                if line[:1].isspace():
                    if self.current_rule is None:
                        self.error(lineno, "rule body without a preceding rule")
                    self.parse_rule_body(lineno, stripped)
                else:
                    self.current_rule = None
                    self.parse_top(lineno, stripped)
        return self.doc

    def parse_top(self, lineno, line):
        if line.startswith("ir "):
            if self.seen_ir:
                self.error(lineno, "duplicate ir directive")
            version = line[3:].strip()
            if version != VERSION:
                self.error(lineno, "unsupported IR version %r (expected %s)" %
                           (version, VERSION))
            self.seen_ir = True
            self.doc.version = version
            return
        if not self.seen_ir:
            self.error(lineno, "the first directive must be 'ir %s'" % VERSION)
        match = re.match(r"^target\s+(\S+)\s+(.+)$", line)
        if match:
            key, value = match.group(1), strip_quotes(match.group(2))
            if key not in ("ip", "variants", "workload"):
                self.error(lineno, "unknown target field %r" % key)
            if key in self.doc.target:
                self.error(lineno, "duplicate target field %r" % key)
            if not value:
                self.error(lineno, "empty target field %r" % key)
            self.doc.target[key] = value
            return
        match = re.match(r"^source\s+(\S+)\s+(.+)$", line)
        if match:
            ident, citation = match.group(1), strip_quotes(match.group(2))
            if not ID_RE.match(ident):
                self.error(lineno, "invalid source id %r" % ident)
            if ident in self.doc.source_by_id:
                self.error(lineno, "duplicate source id %r" % ident)
            if not citation:
                self.error(lineno, "empty source citation")
            source = Source(ident, citation, lineno)
            self.doc.sources.append(source)
            self.doc.source_by_id[ident] = source
            return
        match = re.match(r"^symbol\s+(\S+)\s+(\S+)(?:\s+(.*))?$", line)
        if match:
            kind, name, tail = match.group(1), match.group(2), match.group(3) or ""
            if kind not in SYMBOL_KINDS:
                self.error(lineno, "unknown symbol kind %r" % kind)
            if not IDENT_RE.match(name) or "<" in name or ">" in name:
                self.error(lineno, "invalid symbol name %r" % name)
            if name in self.doc.symbol_by_name:
                self.error(lineno, "duplicate symbol name %r" % name)
            attrs = parse_attrs(tail, lineno, "symbol %s" % name)
            symbol = Symbol(kind, name, attrs, lineno)
            self.doc.symbols.append(symbol)
            self.doc.symbol_by_name[name] = symbol
            return
        match = re.match(r'^rule\s+(\S+)\s+"([^"]*)"\s*(.*)$', line)
        if match:
            ident, summary, tail = match.group(1), match.group(2), match.group(3)
            if not ID_RE.match(ident):
                self.error(lineno, "invalid rule id %r" % ident)
            if ident in self.doc.rule_by_id:
                self.error(lineno, "duplicate rule id %r" % ident)
            if not summary.strip():
                self.error(lineno, "rule summary must be non-empty")
            attrs = parse_attrs(tail, lineno, "rule %s" % ident, allow_unknown=False)
            unknown = set(attrs) - {"tier", "confidence", "sources"}
            if unknown:
                self.error(lineno, "unknown rule attribute(s): %s" %
                           ",".join(sorted(unknown)))
            rule = Rule(ident, summary, attrs, lineno)
            self.doc.rules.append(rule)
            self.doc.rule_by_id[ident] = rule
            self.current_rule = rule
            return
        match = re.match(r"^flow\s+(\S+)\s+(.+)$", line)
        if match:
            ident, chain = match.group(1), match.group(2)
            if not ID_RE.match(ident):
                self.error(lineno, "invalid flow id %r" % ident)
            if any(flow.ident == ident for flow in self.doc.flows):
                self.error(lineno, "duplicate flow id %r" % ident)
            rule_ids = [part.strip() for part in chain.split("->")]
            if not rule_ids or any(not ID_RE.match(part) for part in rule_ids):
                self.error(lineno, "invalid flow rule chain %r" % chain)
            self.doc.flows.append(Flow(ident, rule_ids, lineno))
            return
        match = re.match(r'^unresolved\s+"([^"]*)"\s*$', line)
        if match:
            if not match.group(1).strip():
                self.error(lineno, "unresolved entry must be non-empty")
            self.doc.unresolved.append(match.group(1))
            return
        self.error(lineno, "unknown directive: %r" % line)

    def parse_rule_body(self, lineno, line):
        rule = self.current_rule
        if line.startswith("trigger "):
            if rule.trigger is not None:
                self.error(lineno, "duplicate trigger")
            rest = line[len("trigger "):].strip()
            parts = rest.split(None, 1)
            kind = parts[0]
            defn = self.vocab.get("trigger", kind)
            if defn is None:
                self.error(lineno, "unknown trigger kind %r" % kind)
            subject = None
            tail = ""
            if len(parts) > 1:
                second = parts[1].strip()
                if defn.arity == 0:
                    tail = second
                elif second.startswith("="):
                    self.error(lineno, "trigger %s requires a subject" % kind)
                else:
                    subject = second.split(None, 1)[0]
                    tail = second[len(subject):].strip()
            if defn.arity == 1 and subject is None:
                self.error(lineno, "trigger %s requires a subject" % kind)
            if subject is not None and not IDENT_RE.match(subject):
                self.error(lineno, "invalid trigger subject %r" % subject)
            attrs = parse_attrs(tail, lineno, "trigger %s" % kind)
            rule.trigger = Trigger(kind, subject, attrs, lineno)
            return
        if line.startswith("condition "):
            if rule.condition is not None:
                self.error(lineno, "duplicate condition")
            text = line[len("condition "):].strip()
            if not text:
                self.error(lineno, "empty condition")
            rule.condition = ExprParser(text, lineno, "condition").parse()
            return
        if line.startswith("transition "):
            rest = line[len("transition "):].strip()
            explicit = None
            match = re.match(r"^([A-Z][A-Z0-9_|,]*)\s+(.*)$", rest)
            if match:
                explicit = set()
                for part in re.split(r"[|,]", match.group(1)):
                    part = part.strip()
                    if not part:
                        continue
                    if part not in KNOWN_FLAGS:
                        self.error(lineno, "unknown transition flag %r" % part)
                    explicit.add(part)
                rest = match.group(2).strip()
            node = ExprParser(rest, lineno, "transition").parse()
            if not isinstance(node, Call):
                self.error(lineno, "transition must be an operation call")
            rule.transitions.append(Transition(node.name, node.args, explicit, lineno))
            return
        if line.startswith("framework "):
            if rule.framework is not None:
                self.error(lineno, "duplicate framework")
            rest = line[len("framework "):].strip()
            parts = rest.split(None, 1)
            impl = parts[0]
            tail = parts[1] if len(parts) > 1 else ""
            attrs = parse_attrs(tail, lineno, "framework", allow_unknown=False)
            unknown = set(attrs) - {"hook", "rationale"}
            if unknown:
                self.error(lineno, "unknown framework attribute(s): %s" %
                           ",".join(sorted(unknown)))
            rule.framework = Framework(impl, attrs.get("hook", ""),
                                       attrs.get("rationale", ""), lineno)
            return
        if line.startswith("observe "):
            if rule.observe is not None:
                self.error(lineno, "duplicate observe")
            attrs = parse_attrs(line[len("observe "):].strip(), lineno,
                                "observe", allow_unknown=False)
            unknown = set(attrs) - {"trace", "log", "error"}
            if unknown:
                self.error(lineno, "unknown observe attribute(s): %s" %
                           ",".join(sorted(unknown)))
            if not attrs:
                self.error(lineno, "observe needs trace, log, or error")
            rule.observe = Observe(attrs, lineno)
            return
        if line.startswith("qtest "):
            value = strip_quotes(line[len("qtest "):])
            if not value:
                self.error(lineno, "empty qtest assertion")
            rule.qtests.append(value)
            return
        if line.startswith("gap ") or line.startswith("unknown "):
            value = strip_quotes(line.split(None, 1)[1])
            if not value:
                self.error(lineno, "empty gap entry")
            rule.gaps.append(value)
            return
        if line.startswith("expansion "):
            value = strip_quotes(line[len("expansion "):])
            if not value:
                self.error(lineno, "empty expansion note")
            rule.expansions.append(value)
            return
        self.error(lineno, "unknown rule body directive: %r" % line)


def resolve_atom(node, operand_class, doc, line, where):
    if operand_class == "B":
        raise IrError(line, "%s: expected a condition call, got an atom" % where)
    if isinstance(node, Ref):
        symbol = doc.symbol_by_name.get(node.name)
        if symbol is None:
            raise IrError(line, "%s: unknown symbol %r" % (where, node.name))
        allowed = {
            "R": {"register", "field", "state"},
            "S": set(SYMBOL_KINDS),
            "I": {"irq"},
            "T": {"timer"},
            "F": {"fifo"},
            "E": {"event"},
            "M": set(SYMBOL_KINDS),
            "V": {"constant"},
        }.get(operand_class)
        if allowed is None:
            raise IrError(line, "%s: internal unknown operand class %r" %
                          (where, operand_class))
        if symbol.kind not in allowed:
            raise IrError(line, "%s: %r is a %s symbol, expected %s" %
                          (where, node.name, symbol.kind, "/".join(sorted(allowed))))
        return
    if isinstance(node, (Num, Str)):
        if operand_class not in ("M", "V"):
            raise IrError(line, "%s: literal not allowed for class %s" %
                          (where, operand_class))
        return
    raise IrError(line, "%s: nested call is not allowed here" % where)


def check_condition(node, doc, vocab, line, where):
    if not isinstance(node, Call):
        raise IrError(line, "%s: condition must be a condition call" % where)
    defn = vocab.get("condition", node.name)
    if defn is None:
        raise IrError(line, "%s: %r is not a condition operator" %
                      (where, node.name))
    if defn.variadic:
        if not node.args:
            raise IrError(line, "%s: variadic %s needs at least one operand" %
                          (where, node.name))
        classes = [defn.signature[0]] * len(node.args)
    else:
        if len(node.args) != defn.arity:
            raise IrError(line, "%s: %s expects %d operand(s), got %d" %
                          (where, node.name, defn.arity, len(node.args)))
        classes = defn.signature
    for index, (arg, operand_class) in enumerate(zip(node.args, classes)):
        child_where = "%s.%s[%d]" % (where, node.name, index)
        if operand_class == "B":
            check_condition(arg, doc, vocab, line, child_where)
        else:
            resolve_atom(arg, operand_class, doc, line, child_where)


def parse_flags_text(text, line):
    flags = set()
    for part in re.split(r"[|,]", text):
        part = part.strip()
        if not part:
            continue
        if part not in KNOWN_FLAGS:
            raise IrError(line, "unknown flag %r" % part)
        flags.add(part)
    return flags


def validate(doc, vocab):
    errors = []

    def add(line, message):
        errors.append((line, message))

    if doc.version != VERSION:
        add(0, "missing or unsupported version (expected %s)" % VERSION)
    for key in ("ip", "variants", "workload"):
        if not doc.target.get(key):
            add(0, "missing target field %r" % key)
    if not doc.sources:
        add(0, "at least one source is required")
    if "variants" in doc.target and not doc.target["variants"].strip():
        add(0, "target variants must be non-empty")

    for symbol in doc.symbols:
        where = "symbol %s" % symbol.name
        attrs = symbol.attrs
        if symbol.kind == "register":
            for key in ("offset", "width"):
                if key not in attrs:
                    add(symbol.line, "%s: missing required attribute %r" % (where, key))
            for key in ("offset", "width", "reset"):
                if key in attrs:
                    try:
                        value = parse_number(attrs[key], symbol.line, "%s.%s" % (where, key))
                    except IrError as exc:
                        add(exc.line, exc.message)
                        value = None
                    if key == "width" and value is not None and value <= 0:
                        add(symbol.line, "%s: width must be positive" % where)
            if "access" in attrs and attrs["access"] not in ACCESS:
                add(symbol.line, "%s: access must be one of %s" %
                    (where, ",".join(sorted(ACCESS))))
        elif symbol.kind == "field":
            if "bits" not in attrs:
                add(symbol.line, "%s: missing required attribute 'bits'" % where)
            else:
                try:
                    parse_bits(attrs["bits"], symbol.line)
                except IrError as exc:
                    add(exc.line, exc.message)
            if "." not in symbol.name:
                add(symbol.line, "%s: field name must be <REGISTER>.<FIELD>" % where)
            else:
                reg_name = symbol.name.rsplit(".", 1)[0]
                reg = doc.symbol_by_name.get(reg_name)
                if reg is None or reg.kind != "register":
                    add(symbol.line, "%s: register %r is not declared" %
                        (where, reg_name))
                elif "bits" in attrs and "width" in reg.attrs:
                    try:
                        low, high = parse_bits(attrs["bits"], symbol.line)
                        width = parse_number(reg.attrs["width"], reg.line, "register width")
                        if high >= width:
                            add(symbol.line, "%s: bits %r exceed register width %d" %
                                (where, attrs["bits"], width))
                    except IrError:
                        pass
            if "access" in attrs and attrs["access"] not in ACCESS:
                add(symbol.line, "%s: access must be one of %s" %
                    (where, ",".join(sorted(ACCESS))))
        elif symbol.kind == "constant":
            if "value" not in attrs:
                add(symbol.line, "%s: missing required attribute 'value'" % where)
            else:
                try:
                    parse_number(attrs["value"], symbol.line, where + ".value")
                except IrError as exc:
                    add(exc.line, exc.message)
        elif symbol.kind == "state":
            if "type" not in attrs:
                add(symbol.line, "%s: missing required attribute 'type'" % where)
        elif symbol.kind == "irq":
            if "kind" in attrs and attrs["kind"] not in IRQ_KINDS:
                add(symbol.line, "%s: irq kind must be level or edge" % where)
        elif symbol.kind == "fifo":
            for key in ("depth", "width"):
                if key not in attrs:
                    add(symbol.line, "%s: missing required attribute %r" % (where, key))
                else:
                    try:
                        value = parse_number(attrs[key], symbol.line, where + "." + key)
                        if value <= 0:
                            add(symbol.line, "%s: %s must be positive" % (where, key))
                    except IrError as exc:
                        add(exc.line, exc.message)
        elif symbol.kind == "address":
            for key in ("base", "size"):
                if key not in attrs:
                    add(symbol.line, "%s: missing required attribute %r" % (where, key))
                else:
                    try:
                        value = parse_number(attrs[key], symbol.line, where + "." + key)
                        if key == "size" and value <= 0:
                            add(symbol.line, "%s: size must be positive" % where)
                    except IrError as exc:
                        add(exc.line, exc.message)
            status = attrs.get("status")
            if status is not None and status not in ADDRESS_STATUS:
                add(symbol.line, "%s: status must be one of %s" %
                    (where, ",".join(sorted(ADDRESS_STATUS))))
            if status == "unimplemented":
                if not attrs.get("placeholder"):
                    add(symbol.line, "%s: unimplemented address needs a placeholder name" % where)
                if not attrs.get("source"):
                    add(symbol.line, "%s: unimplemented address needs a source" % where)
        if "source" in attrs and attrs["source"] not in doc.source_by_id:
            add(symbol.line, "%s: unknown source id %r" %
                (where, attrs["source"]))

    for rule in doc.rules:
        where = "rule %s" % rule.ident
        for key in ("tier", "confidence", "sources"):
            if key not in rule.attrs:
                add(rule.line, "%s: missing attribute %r" % (where, key))
        tier = rule.attrs.get("tier")
        if tier is not None and tier not in TIERS:
            add(rule.line, "%s: tier must be one of %s" %
                (where, ",".join(sorted(TIERS))))
        confidence = rule.attrs.get("confidence")
        if confidence is not None and confidence not in CONFIDENCE:
            add(rule.line, "%s: confidence must be one of %s" %
                (where, ",".join(sorted(CONFIDENCE))))
        sources = [part.strip() for part in rule.attrs.get("sources", "").split(",")
                   if part.strip()]
        if "sources" in rule.attrs and not sources:
            add(rule.line, "%s: sources must be non-empty" % where)
        for source_id in sources:
            if source_id not in doc.source_by_id:
                add(rule.line, "%s: unknown source id %r" % (where, source_id))
        if rule.trigger is None:
            add(rule.line, "%s: missing trigger" % where)
        if not rule.transitions:
            add(rule.line, "%s: at least one transition is required" % where)
        if rule.framework is None:
            add(rule.line, "%s: missing framework" % where)
        else:
            if rule.framework.implementation not in IMPLS:
                add(rule.framework.line, "%s: framework implementation must be one of %s" %
                    (where, ",".join(sorted(IMPLS))))
            if rule.framework.hook not in HOOKS:
                add(rule.framework.line, "%s: framework hook must be one of %s" %
                    (where, ",".join(sorted(HOOKS))))
            if not rule.framework.rationale.strip():
                add(rule.framework.line, "%s: framework rationale must be non-empty" % where)
        if not rule.qtests:
            add(rule.line, "%s: at least one qtest assertion is required" % where)

        if rule.trigger is not None:
            defn = vocab.get("trigger", rule.trigger.kind)
            if defn is None:
                add(rule.trigger.line, "%s: unknown trigger kind %r" %
                    (where, rule.trigger.kind))
            else:
                if defn.arity == 1:
                    if rule.trigger.subject is None:
                        add(rule.trigger.line, "%s: trigger %s requires a subject" %
                            (where, rule.trigger.kind))
                    else:
                        symbol = doc.symbol_by_name.get(rule.trigger.subject)
                        if symbol is None:
                            add(rule.trigger.line, "%s: unknown trigger subject %r" %
                                (where, rule.trigger.subject))
                        else:
                            try:
                                resolve_atom(Ref(rule.trigger.subject),
                                             defn.signature[0], doc,
                                             rule.trigger.line, where + ".trigger")
                            except IrError as exc:
                                add(exc.line, exc.message)
                elif defn.arity == 0 and rule.trigger.subject is not None:
                    add(rule.trigger.line, "%s: trigger %s takes no subject" %
                        (where, rule.trigger.kind))

        if rule.condition is not None:
            try:
                check_condition(rule.condition, doc, vocab, rule.line,
                                where + ".condition")
            except IrError as exc:
                add(exc.line, exc.message)

        expands = False
        unsupported = False
        logging_only_any = False
        for transition in rule.transitions:
            defn = vocab.get("operation", transition.op)
            if defn is None:
                add(transition.line, "%s: unknown operation %r" %
                    (where, transition.op))
                logging_only_all = False
                continue
            if defn.kind != "operation":
                add(transition.line, "%s: %r is not an operation" %
                    (where, transition.op))
            explicit = transition.explicit_flags
            if explicit is None:
                effective = set(defn.flags)
            else:
                effective = set(explicit)
                if "PURE" in effective:
                    add(transition.line, "%s: PURE is not valid on a transition" % where)
                extra = effective - (defn.flags | {"UNSUPPORTED"})
                if extra:
                    add(transition.line, "%s: flags %s not declared for %s" %
                        (where, ",".join(sorted(extra)), transition.op))
            if "PURE" in effective:
                add(transition.line, "%s: PURE operation in a transition" % where)
            if (effective & {"GUEST_VISIBLE", "MIGRATABLE", "RESET_AFFECTING"}
                    and "SIDE_EFFECTS" not in effective):
                add(transition.line, "%s: side-effect flags require SIDE_EFFECTS" % where)
            if "LOGGING_ONLY" in effective and "GUEST_VISIBLE" in effective:
                add(transition.line, "%s: LOGGING_ONLY cannot be GUEST_VISIBLE" % where)
            transition.effective_flags = effective
            if "EXPANDS" in effective:
                expands = True
            if "UNSUPPORTED" in effective:
                unsupported = True
            if "LOGGING_ONLY" in effective:
                logging_only_any = True
            if defn.variadic:
                if not transition.args:
                    add(transition.line, "%s: variadic %s needs at least one operand" %
                        (where, transition.op))
                    continue
                classes = [defn.signature[0]] * len(transition.args)
            else:
                if len(transition.args) != defn.arity:
                    add(transition.line, "%s: %s expects %d operand(s), got %d" %
                        (where, transition.op, defn.arity, len(transition.args)))
                    continue
                classes = defn.signature
            for index, (arg, operand_class) in enumerate(zip(transition.args, classes)):
                try:
                    resolve_atom(arg, operand_class, doc, transition.line,
                                 "%s.%s[%d]" % (where, transition.op, index))
                except IrError as exc:
                    add(exc.line, exc.message)
        if logging_only_any and not rule.gaps:
            add(rule.line, "%s: logging-only transition must record a gap" % where)
        if expands and not rule.expansions:
            add(rule.line, "%s: EXPANDS requires an expansion note" % where)
        if unsupported and not rule.gaps:
            add(rule.line, "%s: UNSUPPORTED requires a gap note" % where)

        if rule.observe is not None:
            observe = rule.observe
            trace = observe.attrs.get("trace", "none")
            if trace != "none" and not TRACE_RE.match(trace):
                add(observe.line, "%s: invalid trace event name %r" % (where, trace))
            log = observe.attrs.get("log", "none")
            if log not in OBSERVE_LOG:
                add(observe.line, "%s: log must be one of %s" %
                    (where, ",".join(sorted(OBSERVE_LOG))))
            error_policy = observe.attrs.get("error", "none")
            if error_policy not in OBSERVE_ERROR:
                add(observe.line, "%s: error must be one of %s" %
                    (where, ",".join(sorted(OBSERVE_ERROR))))
            if trace == "none" and log == "none" and not rule.gaps:
                add(observe.line, "%s: observe with no trace/log needs a gap" % where)

        visible = any("GUEST_VISIBLE" in transition.effective_flags
                      for transition in rule.transitions)
        unimplemented = any(
            ("UNSUPPORTED" in transition.effective_flags
             or "LOGGING_ONLY" in transition.effective_flags)
            for transition in rule.transitions)
        if visible:
            if rule.observe is None:
                add(rule.line, "%s: guest-visible transition requires an observe line" % where)
            else:
                trace = rule.observe.attrs.get("trace", "none")
                log = rule.observe.attrs.get("log", "none")
                if trace == "none" and log == "none":
                    add(rule.observe.line,
                        "%s: guest-visible rule needs trace or log" % where)
        if unimplemented:
            if rule.observe is None:
                add(rule.line,
                    "%s: unimplemented/logging transition requires an observe line" % where)
            else:
                log = rule.observe.attrs.get("log", "none")
                if log not in ("unimp", "both"):
                    add(rule.observe.line,
                        "%s: unimplemented/logging rule requires log=unimp or log=both" % where)

    for flow in doc.flows:
        if not flow.rule_ids:
            add(flow.line, "flow %s: empty rule chain" % flow.ident)
        for rule_id in flow.rule_ids:
            if rule_id not in doc.rule_by_id:
                add(flow.line, "flow %s: unknown rule id %r" % (flow.ident, rule_id))

    return errors


def quote(text):
    return '"%s"' % text


def attr_text(attrs):
    parts = []
    for key, value in attrs.items():
        if re.search(r"\s", value) or value == "" or '"' in value:
            parts.append('%s="%s"' % (key, value))
        else:
            parts.append("%s=%s" % (key, value))
    return " ".join(parts)


def dump_document(doc, path):
    lines = ["# canonical dump of %s" % path, "ir %s" % VERSION]
    for key in ("ip", "variants", "workload"):
        value = doc.target.get(key, "")
        lines.append("target %s %s" % (key, quote(value) if " " in value else value))
    for source in doc.sources:
        lines.append("source %s %s" % (source.ident, quote(source.citation)))
    for symbol in doc.symbols:
        attrs = attr_text(symbol.attrs)
        lines.append("symbol %s %s%s" % (symbol.kind, symbol.name,
                                         (" " + attrs) if attrs else ""))
    for rule in doc.rules:
        sources = rule.attrs.get("sources", "")
        lines.append('rule %s "%s" tier=%s confidence=%s sources=%s' %
                     (rule.ident, rule.summary, rule.attrs.get("tier", ""),
                      rule.attrs.get("confidence", ""), sources))
        if rule.trigger is not None:
            subject = (" " + rule.trigger.subject) if rule.trigger.subject else ""
            attrs = attr_text(rule.trigger.attrs)
            lines.append("  trigger %s%s%s" %
                         (rule.trigger.kind, subject,
                          (" " + attrs) if attrs else ""))
        if rule.condition is not None:
            lines.append("  condition %s" % format_expr(rule.condition))
        for transition in rule.transitions:
            flags = ""
            if transition.explicit_flags is not None:
                flags = ",".join(sorted(transition.explicit_flags)) + " "
            args = ", ".join(format_expr(arg) for arg in transition.args)
            lines.append("  transition %s%s(%s)" % (flags, transition.op, args))
        framework = rule.framework
        lines.append('  framework %s hook=%s rationale=%s' %
                     (framework.implementation, framework.hook,
                      quote(framework.rationale)))
        if rule.observe is not None:
            lines.append("  observe %s" % attr_text(rule.observe.attrs))
        for value in rule.qtests:
            lines.append("  qtest %s" % quote(value))
        for value in rule.gaps:
            lines.append("  gap %s" % quote(value))
        for value in rule.expansions:
            lines.append("  expansion %s" % quote(value))
    for flow in doc.flows:
        lines.append("flow %s %s" % (flow.ident, " -> ".join(flow.rule_ids)))
    for value in doc.unresolved:
        lines.append("unresolved %s" % quote(value))
    return "\n".join(lines) + "\n"


def print_vocab(vocab):
    for (kind, name) in sorted(vocab.ops):
        defn = vocab.ops[(kind, name)]
        flags = "|".join(sorted(defn.flags)) if defn.flags else "NONE"
        signature = "-"
        if defn.signature:
            signature = ",".join(defn.signature) + ("..." if defn.variadic else "")
        print("%s\t%s\t%d\t%s\t%s" %
              (kind, name, defn.arity, flags, signature))


def translate_document(document):
    rows = ["kind\tid\tmechanism\thook\ttrace\tlog\terror\tqtests\tplaceholder"]
    for rule in document.rules:
        observe = rule.observe.attrs if rule.observe is not None else {}
        rows.append("\t".join([
            "rule",
            rule.ident,
            rule.framework.implementation,
            rule.framework.hook,
            observe.get("trace", "none"),
            observe.get("log", "none"),
            observe.get("error", "none"),
            str(len(rule.qtests)),
            "-",
        ]))
    for symbol in document.symbols:
        if symbol.kind != "address" or symbol.attrs.get("status") != "unimplemented":
            continue
        rows.append("\t".join([
            "address",
            symbol.name,
            "unimplemented-device",
            "-",
            "-",
            "-",
            "-",
            "0",
            symbol.attrs.get("placeholder", "-"),
        ]))
    return "\n".join(rows) + "\n"


def main(argv):
    parser = argparse.ArgumentParser(
        prog="validate_register_ir.py",
        description="Parse, validate, and dump the register-semantics RS-IR (v1).",
        epilog="Examples: validate_register_ir.py output/register-semantics.ir "
               "| --dump <file.ir> | --translate <file.ir> | --list-ops")
    parser.add_argument("path", nargs="?", help="register-semantics .ir file")
    parser.add_argument("--vocab", help="vocabulary DEF file (default: ../assets/ir-ops.def)")
    parser.add_argument("--dump", action="store_true",
                        help="print the canonical text form after validation")
    parser.add_argument("--translate", action="store_true",
                        help="print the RS-IR to QEMU translation worklist as TSV")
    parser.add_argument("--list-ops", action="store_true",
                        help="print the vocabulary as TSV and exit")
    args = parser.parse_args(argv)

    default_vocab = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ir-ops.def"))
    vocab_path = args.vocab or default_vocab
    try:
        vocab = load_vocab(vocab_path)
    except (IrError, OSError) as exc:
        line = getattr(exc, "line", 0)
        message = getattr(exc, "message", str(exc))
        print("FAIL: vocabulary %s:%d: %s" % (vocab_path, line, message))
        return 2

    if args.list_ops:
        print_vocab(vocab)
        return 0
    if not args.path:
        parser.print_usage(sys.stderr)
        return 2

    try:
        document = Parser(args.path, vocab).parse()
    except IrError as exc:
        print("%s:%d: %s" % (args.path, exc.line, exc.message))
        print("FAIL: parse error in %s" % args.path)
        return 1
    except OSError as exc:
        print("FAIL: cannot read %s: %s" % (args.path, exc))
        return 2

    errors = validate(document, vocab)
    if errors:
        for line, message in errors:
            print("%s:%d: %s" % (args.path, line, message))
        print("FAIL: %d error(s) in %s" % (len(errors), args.path))
        return 1

    if args.translate:
        sys.stdout.write(translate_document(document))
        return 0
    if args.dump:
        sys.stdout.write(dump_document(document, args.path))
        return 0

    symbol_counts = {}
    for symbol in document.symbols:
        symbol_counts[symbol.kind] = symbol_counts.get(symbol.kind, 0) + 1
    trigger_counts = {}
    operation_counts = {}
    for rule in document.rules:
        if rule.trigger is not None:
            trigger_counts[rule.trigger.kind] = trigger_counts.get(rule.trigger.kind, 0) + 1
        for transition in rule.transitions:
            operation_counts[transition.op] = operation_counts.get(transition.op, 0) + 1
    print("PASS: %s (version=%s symbols=%d rules=%d flows=%d sources=%d)" %
          (args.path, document.version, len(document.symbols), len(document.rules),
           len(document.flows), len(document.sources)))
    for kind in sorted(symbol_counts):
        print("  symbol %-9s %d" % (kind, symbol_counts[kind]))
    for kind in sorted(trigger_counts):
        print("  trigger %-8s %d" % (kind, trigger_counts[kind]))
    for op in sorted(operation_counts):
        print("  operation %-8s %d" % (op, operation_counts[op]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
