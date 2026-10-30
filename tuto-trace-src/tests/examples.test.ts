import { readFileSync, readdirSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { analyze, trace, type Lang } from '../src/engine'

const real: Record<string, { out: string; err: string }> = JSON.parse(readFileSync(new URL('./expected-real.json', import.meta.url), 'utf8'))
const dir = new URL('../src/examples/', import.meta.url)

function run(lang: Lang, src: string) {
  const a = analyze(lang, src)
  const errors = a.errors.filter((e) => e.severity === 'error')
  if (errors.length) return { errors, out: '', steps: [] }
  const steps = trace(a, src)
  return { errors, out: steps[steps.length - 1].out, steps, last: steps[steps.length - 1] }
}

for (const lang of ['python', 'csharp', 'dart', 'javascript', 'typescript'] as Lang[]) {
  describe(lang, () => {
    for (const f of readdirSync(new URL(`${lang}/`, dir))) {
      const src = readFileSync(new URL(`${lang}/${f}`, dir), 'utf8')
      it(f, () => {
        const r = run(lang, src)
        const exp = real[`${lang}/${f}`]
        if (f.startsWith('err-')) {
          // un exemple d'erreur doit échouer : à la compilation ou à l'exécution
          const failed = r.errors.length > 0 || r.last?.kind === 'error'
          expect(failed).toBe(true)
          if (exp) expect(r.out).toBe(exp.out)
          return
        }
        expect(r.errors).toEqual([])
        expect(r.last?.kind).toBe('end')
        if (exp) expect(r.out).toBe(exp.out)
        else expect(r.out).toMatchSnapshot()
      })
    }
  })
}

describe('détails', () => {
  it('while : 4 conditions et 3 retours', () => {
    const r = run('python', readFileSync(new URL('python/while-counter.py', dir), 'utf8'))
    expect(r.steps.filter((s) => s.kind === 'cond').length).toBe(4)
    expect(r.steps.filter((s) => s.kind === 'loopBack').length).toBe(3)
  })
  it('erreurs C# attendues', () => {
    const codes = (src: string) => analyze('csharp', src).errors.filter((e) => e.severity === 'error').map((e) => `${e.code}@${e.span.line}`)
    expect(codes(readFileSync(new URL('csharp/err-type.cs', dir), 'utf8'))).toEqual(['type.mismatch@1', 'type.doubleToInt@3'])
    expect(codes(readFileSync(new URL('csharp/err-undeclared.cs', dir), 'utf8'))).toEqual(['var.undeclared@2', 'var.undeclared@3'])
    expect(codes(readFileSync(new URL('csharp/err-semicolon.cs', dir), 'utf8'))).toEqual(['syntax.missingSemicolon@1', 'syntax.missingSemicolon@3'])
  })
  it('erreurs Dart attendues (comme dart analyze)', () => {
    const codes = (src: string) => analyze('dart', src).errors.filter((e) => e.severity === 'error').map((e) => `${e.code}@${e.span.line}`)
    expect(codes(readFileSync(new URL('dart/err-type.dart', dir), 'utf8'))).toEqual(['type.mismatch@2', 'type.doubleToInt@4', 'dart.stringPlus@5'])
    expect(codes(readFileSync(new URL('dart/err-undeclared.dart', dir), 'utf8'))).toEqual(['var.undeclared@3', 'var.undeclared@4'])
    expect(codes(readFileSync(new URL('dart/err-semicolon.dart', dir), 'utf8'))).toEqual(['syntax.missingSemicolon@2', 'syntax.missingSemicolon@4'])
  })
  it('erreurs Python', () => {
    const a = analyze('python', readFileSync(new URL('python/err-indent.py', dir), 'utf8'))
    expect(a.errors.map((e) => `${e.code}@${e.span.line}`)).toEqual(['py.expectedIndent@3'])
    const r = run('python', readFileSync(new URL('python/err-undeclared.py', dir), 'utf8'))
    expect(r.last?.error?.code).toBe('py.nameError')
  })
  it('division et affichage selon le langage', () => {
    expect(run('python', 'print(7 / 2, 7 // 2, -7 % 3, 2.0, True)').out).toBe('3.5 3 2 2.0 True\n')
    expect(run('csharp', 'Console.WriteLine(7 / 2);\nConsole.WriteLine(7.0 / 2);\nConsole.WriteLine(2.0);\nConsole.WriteLine(true);\nConsole.WriteLine(-7 % 3);').out).toBe('3\n3.5\n2\nTrue\n-1\n')
    expect(run('dart', 'void main() {\n  print(7 / 2);\n  print(7 ~/ 2);\n  print(-7 % 3);\n  print(2.0);\n  print(true);\n}').out).toBe('3.5\n3\n2\n2.0\ntrue\n')
  })
  it('JavaScript : nombres, undefined, conversions (comme Node)', () => {
    const js = (src: string) => run('javascript', src).out
    expect(js('console.log(7 / 2, 6 / 2, -7 % 3, 2.0, true, null, 1 / 0)')).toBe('3.5 3 -1 2 true null Infinity\n')
    expect(js('const t = [1, 2];\nconsole.log(t, t[5], t.length, ["a", "b"], [])')).toBe("[ 1, 2 ] undefined 2 [ 'a', 'b' ] []\n")
    expect(js('let x;\nconsole.log(x, "5" + 1, "5" - 1, "a" + [1, 2], `n = ${1 + 1}`)')).toBe('undefined 51 4 a1,2 n = 2\n')
    expect(js('console.log(1 == "1", 1 === "1", null == undefined, 0 || "défaut", 2 ** 10)')).toBe('true false true défaut 1024\n')
    expect(js('let n = 0\nn++\nconsole.log(n)')).toBe('1\n') // points-virgules facultatifs
    expect(js('function f(a, b) {\n  return b;\n}\nconsole.log(f(1))')).toBe('undefined\n')
    expect(js('const t = [3, 1];\nt.push(4);\nconsole.log(t.pop(), t.join("-"), t.includes(1), "Abc".toUpperCase(), (2.5).toFixed(2))')).toBe('4 3-1 true ABC 2.50\n')
  })
  it('JavaScript : erreurs à l’exécution', () => {
    expect(run('javascript', 'let a = 1;\nconsole.log(b);').last?.error?.code).toBe('runtime.undeclared')
    expect(run('javascript', 'const a = 1;\na++;').last?.error?.code).toBe('runtime.final')
    expect(run('javascript', 'let t = [];\nt[0].x;').last?.error?.code).toBe('js.nullProp')
    expect(run('javascript', 'function f(n) {\n  return f(n + 1);\n}\nf(0);').last?.error?.code).toBe('runtime.stackOverflow')
    // erreur de syntaxe : signalée avant l'exécution
    expect(analyze('javascript', 'let x = 1 let y = 2;').errors.map((e) => e.code)).toEqual(['syntax.missingSemicolon'])
  })
  it('erreurs TypeScript attendues (comme tsc)', () => {
    const codes = (src: string) => analyze('typescript', src).errors.filter((e) => e.severity === 'error').map((e) => `${e.code}@${e.span.line}`)
    expect(codes(readFileSync(new URL('typescript/err-type.ts', dir), 'utf8'))).toEqual(['type.mismatch@1'])
    expect(codes(readFileSync(new URL('typescript/err-undeclared.ts', dir), 'utf8'))).toEqual(['var.undeclared@2'])
    expect(codes('const a: number = 1;\na = 2;')).toEqual(['var.final@2'])
    expect(codes('function f(x: number): string {\n  return x;\n}\nf("a");')).toEqual(['return.type@2', 'call.argType@4'])
    expect(codes('let t = [1, 2];\nt = ["a"];')).toEqual(['type.mismatch@2'])
    // le même code sans annotation est du JavaScript valide
    expect(analyze('javascript', 'let age = "20";\nage = 3;').errors).toEqual([])
    expect(analyze('javascript', 'let a: number = 1;').errors.map((e) => e.code)).toEqual(['js.typeInJs'])
  })
  it('boucle infinie arrêtée', () => {
    const r = run('python', 'i = 0\nwhile True:\n    i = i + 1\n')
    expect(r.last?.kind).toBe('limit')
  })
  it('récursion infinie', () => {
    const r = run('python', 'def f(n):\n    return f(n + 1)\nf(0)\n')
    expect(r.last?.error?.code).toBe('py.recursion')
  })
})
