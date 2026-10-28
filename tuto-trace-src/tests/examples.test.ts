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

for (const lang of ['python', 'csharp', 'dart'] as Lang[]) {
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
  it('boucle infinie arrêtée', () => {
    const r = run('python', 'i = 0\nwhile True:\n    i = i + 1\n')
    expect(r.last?.kind).toBe('limit')
  })
  it('récursion infinie', () => {
    const r = run('python', 'def f(n):\n    return f(n + 1)\nf(0)\n')
    expect(r.last?.error?.code).toBe('py.recursion')
  })
})
