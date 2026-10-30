// Messages « authentiques » (en anglais, comme les affichent les vrais outils), indépendants de la langue choisie.
import type { Lang } from '../engine'

type P = Record<string, string | number>
const fill = (s: string, p: P) => s.replace(/\{(\w+)\}/g, (m, k) => (p[k] !== undefined ? String(p[k]) : m))

const JS_SYNTAX: Record<string, string> = {
  'syntax.missingParen': 'SyntaxError: missing ) after argument list',
  'syntax.missingBrace': 'SyntaxError: Unexpected end of input',
  'syntax.unterminatedString': 'SyntaxError: Invalid or unexpected token',
  'syntax.unexpected': "SyntaxError: Unexpected token '{found}'",
  'syntax.missingSemicolon': "SyntaxError: Unexpected identifier '{found}'",
  'js.constNeedsInit': 'SyntaxError: Missing initializer in const declaration',
}

const COMPILE: Record<Lang, Record<string, string>> = {
  python: {
    'py.expectedColon': "SyntaxError: expected ':'",
    'py.expectedIndent': 'IndentationError: expected an indented block',
    'py.unexpectedIndent': 'IndentationError: unexpected indent',
    'py.dedentMismatch': 'IndentationError: unindent does not match any outer indentation level',
    'py.useAnd': 'SyntaxError: invalid syntax',
    'py.useOr': 'SyntaxError: invalid syntax',
    'py.useNot': 'SyntaxError: invalid syntax',
    'py.noIncrement': 'SyntaxError: invalid syntax',
    'py.assignInCond': "SyntaxError: invalid syntax. Maybe you meant '==' or ':=' instead of '='?",
    'syntax.unterminatedString': 'SyntaxError: unterminated string literal',
    'syntax.missingParen': "SyntaxError: '(' was never closed",
    'syntax.unexpected': 'SyntaxError: invalid syntax',
    'syntax.incompleteExpr': 'SyntaxError: invalid syntax',
    'py.expectedNewline': 'SyntaxError: invalid syntax',
  },
  csharp: {
    'syntax.missingSemicolon': 'error CS1002: ; expected',
    'syntax.missingParen': 'error CS1026: ) expected',
    'syntax.missingBrace': 'error CS1513: } expected',
    'syntax.expected': 'error CS1003: Syntax error, \'{expected}\' expected',
    'var.undeclared': "error CS0103: The name '{name}' does not exist in the current context",
    'var.redeclared': "error CS0128: A local variable named '{name}' is already defined in this scope",
    'var.unassigned': "error CS0165: Use of unassigned local variable '{name}'",
    'type.mismatch': "error CS0029: Cannot implicitly convert type '{found}' to '{expected}'",
    'type.doubleToInt': "error CS0266: Cannot implicitly convert type 'double' to 'int'. An explicit conversion exists (are you missing a cast?)",
    'cond.notBool': "error CS0029: Cannot implicitly convert type '{type}' to 'bool'",
    'call.unknown': "error CS0103: The name '{name}' does not exist in the current context",
    'call.argCount': "error CS1501: No overload for method '{name}' takes {given} arguments",
    'call.argType': "error CS1503: Argument: cannot convert from '{found}' to '{expected}'",
    'func.missingReturn': "error CS0161: '{name}': not all code paths return a value",
    'op.badOperands': "error CS0019: Operator '{op}' cannot be applied to operands of type '{left}' and '{right}'",
    'member.unknown': "error CS1061: '{type}' does not contain a definition for '{name}'",
    'type.unknown': "error CS0246: The type or namespace name '{name}' could not be found",
    'stmt.notStatement': 'error CS0201: Only assignment, call, increment, decrement, await, and new object expressions can be used as a statement',
    'return.type': "error CS0029: Cannot implicitly convert type '{found}' to '{expected}'",
    'expr.voidValue': "error CS0029: Cannot implicitly convert type 'void'",
  },
  dart: {
    'syntax.missingSemicolon': "Error: Expected ';' after this.",
    'syntax.missingParen': "Error: Expected ')' before this.",
    'syntax.missingBrace': "Error: Expected '}' before this.",
    'var.undeclared': "Error: Undefined name '{name}'.",
    'type.mismatch': "Error: A value of type '{found}' can't be assigned to a variable of type '{expected}'.",
    'type.doubleToInt': "Error: A value of type 'double' can't be assigned to a variable of type 'int'.",
    'dart.stringPlus': "Error: The argument type '{right}' can't be assigned to the parameter type '{left}'.",
    'cond.notBool': "Error: A value of type '{type}' can't be assigned to a variable of type 'bool'.",
    'call.unknown': "Error: Method not found: '{name}'.",
    'call.argCount': 'Error: Too many positional arguments: {expected} allowed, but {given} found.',
    'member.unknown': "Error: The getter '{name}' isn't defined for the class '{type}'.",
    'type.unknown': "Error: Type '{name}' not found.",
    'var.unassigned': "Error: Non-nullable variable '{name}' must be assigned before it can be used.",
    'dart.noMain': "Error: Undefined name 'main'.",
    'func.missingReturn': "Error: A non-null value must be returned since the return type '{type}' doesn't allow null.",
  },
  javascript: JS_SYNTAX,
  typescript: {
    'syntax.missingSemicolon': "error TS1005: ';' expected.",
    'syntax.missingParen': "error TS1005: ')' expected.",
    'syntax.missingBrace': "error TS1005: '}' expected.",
    'syntax.expected': "error TS1005: '{expected}' expected.",
    'syntax.unterminatedString': 'error TS1002: Unterminated string literal.',
    'js.constNeedsInit': "error TS1155: 'const' declarations must be initialized.",
    'var.undeclared': "error TS2304: Cannot find name '{name}'.",
    'var.redeclared': "error TS2451: Cannot redeclare block-scoped variable '{name}'.",
    'var.final': "error TS2588: Cannot assign to '{name}' because it is a constant.",
    'type.mismatch': "error TS2322: Type '{found}' is not assignable to type '{expected}'.",
    'return.type': "error TS2322: Type '{found}' is not assignable to type '{expected}'.",
    'call.unknown': "error TS2304: Cannot find name '{name}'.",
    'call.argCount': 'error TS2554: Expected {expected} arguments, but got {given}.',
    'call.argType': "error TS2345: Argument of type '{found}' is not assignable to parameter of type '{expected}'.",
    'op.badOperands': "error TS2362: The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type.",
  },
}

// TypeScript est compilé en JavaScript : mêmes erreurs à l'exécution (Node).
const JS_RUNTIME: Record<string, string> = {
  'runtime.undeclared': 'ReferenceError: {name} is not defined',
  'runtime.unknownFunc': 'ReferenceError: {name} is not defined',
  'runtime.final': 'TypeError: Assignment to constant variable.',
  'js.nullProp': "TypeError: Cannot read properties of {type} (reading '{name}')",
  'js.notFunction': 'TypeError: {name} is not a function',
  'runtime.notIterable': 'TypeError: object is not iterable',
  'runtime.stackOverflow': 'RangeError: Maximum call stack size exceeded',
}

const RUNTIME: Record<Lang, Record<string, string>> = {
  python: {
    'py.nameError': "NameError: name '{name}' is not defined",
    'py.nameErrorFunc': "NameError: name '{name}' is not defined",
    'py.unboundLocal': "UnboundLocalError: cannot access local variable '{name}' where it is not associated with a value",
    'py.strConcat': 'TypeError: unsupported operand type(s) for +: \'{left}\' and \'{right}\'',
    'runtime.badOperands': "TypeError: unsupported operand type(s) for {op}: '{left}' and '{right}'",
    'py.zeroDiv': 'ZeroDivisionError: division by zero',
    'runtime.indexOut': 'IndexError: list index out of range',
    'py.recursion': 'RecursionError: maximum recursion depth exceeded',
    'runtime.argCount': 'TypeError: {name}() takes {expected} positional arguments but {given} were given',
    'py.valueError.int': "ValueError: invalid literal for int() with base 10: {value}",
    'runtime.notIterable': "TypeError: '{type}' object is not iterable",
    'runtime.noMember': "AttributeError: '{type}' object has no attribute '{name}'",
  },
  csharp: {
    'runtime.indexOut': 'Unhandled exception. System.IndexOutOfRangeException: Index was outside the bounds of the array.',
    'runtime.divZero': 'Unhandled exception. System.DivideByZeroException: Attempted to divide by zero.',
    'runtime.stackOverflow': 'Stack overflow.',
  },
  dart: {
    'runtime.indexOut': 'Unhandled exception:\nRangeError (index): Invalid value: Not in inclusive range 0..{max}: {index}',
    'runtime.divZero': 'Unhandled exception:\nIntegerDivisionByZeroException',
    'runtime.stackOverflow': 'Unhandled exception:\nStack Overflow',
    'runtime.emptyList': 'Unhandled exception:\nBad state: No element',
  },
  javascript: JS_RUNTIME,
  typescript: JS_RUNTIME,
}

export function realCompileMessage(lang: Lang, code: string, params: P): string | null {
  const m = COMPILE[lang][code]
  if (!m) return null
  if (lang === 'python' && code === 'py.strConcat' && params.left === 'str') return `TypeError: can only concatenate str (not "${params.right}") to str`
  return fill(m, params)
}

export function realRuntimeMessage(lang: Lang, code: string, params: P): string | null {
  if (lang === 'python' && code === 'py.strConcat' && params.left === 'str') return `TypeError: can only concatenate str (not "${params.right}") to str`
  if (code === 'js.nullProp' && params.set) return `TypeError: Cannot set properties of ${params.type} (setting '${params.name}')`
  if (lang === 'csharp' && code === 'runtime.indexOut' && params.list) return 'Unhandled exception. System.ArgumentOutOfRangeException: Index was out of range. Must be non-negative and less than the size of the collection.'
  const m = RUNTIME[lang][code]
  if (!m) return null
  return fill(m, { ...params, max: typeof params.len === 'number' ? params.len - 1 : '' })
}
