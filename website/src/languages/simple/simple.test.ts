import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import test from 'node:test';
import { CompletionContext } from '@codemirror/autocomplete';
import { getIndentation, indentUnit } from '@codemirror/language';
import { diagnosticCount, setDiagnostics } from '@codemirror/lint';
import { EditorState } from '@codemirror/state';
import type { TokenizeResult } from '../../components/playground/runtime-bridge.ts';
import { builtins } from '../builtins.ts';
import { setTokens, tokenization, tokenState, utf16Offsets } from '../tokenization.ts';
import { simpleCompletions } from './completions.ts';
import { keywords } from './syntax.ts';
import { simple } from './index.ts';

function state(source: string, tokens?: TokenizeResult['tokens']) {
  let state = EditorState.create({
    doc: source,
    extensions: [tokenization, simple(), indentUnit.of('\t'), EditorState.tabSize.of(4)],
  });
  if (tokens)
    state = state.update({
      effects: setTokens.of({ language: 'simple', revision: 0, tokens }),
    }).state;
  return state;
}

test('completion keywords match the Simple lexer', async () => {
  const source = await readFile(
    new URL('../../../../runtime/engine/frontend/simple/lexer.gd', import.meta.url),
    'utf8'
  );
  const actual = [...source.matchAll(/"([A-Za-z]+)": Token\.Type\./g)].map((match) => match[1]);
  assert.deepEqual([...keywords].sort(), actual.sort());
});

test('builtin completions match runtime registrations', async () => {
  const directory = new URL('../../../../runtime/engine/standard_library/', import.meta.url);
  const names = new Set<string>();
  for (const file of await readdir(directory)) {
    if (!file.endsWith('.gd')) continue;
    const source = await readFile(new URL(file, directory), 'utf8');
    for (const match of source.matchAll(/define_native_function\("([a-z_]+)"/g))
      names.add(match[1]);
  }
  assert.deepEqual(builtins.map(({ name }) => name).sort(), [...names].sort());
});

test('bridge tokens convert Unicode offsets without displaying errors', () => {
  const current = state('"😀" pr', [
    { start: 0, length: 3, kind: 'string' },
    { start: 4, length: 2, kind: 'identifier' },
  ]);
  assert.deepEqual(utf16Offsets('a😀中'), [0, 1, 3, 4]);
  const actual = current.field(tokenState);
  assert.deepEqual(actual.tokens, [
    { from: 0, to: 4, kind: 'string' },
    { from: 5, to: 7, kind: 'identifier' },
  ]);
  assert.equal(actual.decorations.size, 2);
  assert.equal(diagnosticCount(current), 0);
});

test('edits invalidate token context and reject stale responses', () => {
  let current = state('pr', [{ start: 0, length: 2, kind: 'identifier' }]);
  current = current.update({ changes: { from: 0, to: 2, insert: '# pr' } }).state;
  assert.equal(current.field(tokenState).revision, 1);
  assert.equal(current.field(tokenState).ready, false);
  assert.equal(current.field(tokenState).tokens.length, 0);
  current = current.update({
    effects: setTokens.of({
      language: 'simple',
      revision: 0,
      tokens: [{ start: 0, length: 2, kind: 'keyword' }],
    }),
  }).state;
  assert.equal(current.field(tokenState).ready, false);
  current = current.update({
    effects: setTokens.of({
      language: 'simple',
      revision: 1,
      tokens: [{ start: 0, length: 4, kind: 'comment' }],
    }),
  }).state;
  assert.equal(current.field(tokenState).ready, true);
  assert.equal(current.field(tokenState).tokens[0].kind, 'comment');
});

test('token responses preserve CodeMirror execution diagnostics', () => {
  let current = state('x', []);
  current = current.update(
    setDiagnostics(current, [{ from: 0, to: 1, severity: 'error', message: 'runtime' }])
  ).state;
  current = current.update({
    effects: setTokens.of({ language: 'simple', revision: 0, tokens: [] }),
  }).state;
  assert.equal(diagnosticCount(current), 1);
});

test('unchanged highlights stay mapped while a new response is pending', () => {
  let current = state('var name = 1', [{ start: 0, length: 3, kind: 'keyword' }]);
  current = current.update({ changes: { from: current.doc.length, insert: '0' } }).state;
  assert.equal(current.field(tokenState).ready, false);
  assert.equal(current.field(tokenState).decorations.size, 1);
  assert.equal(current.field(tokenState).tokens.length, 0);
});

test('frontend completions use bridge token context and retain snippets', async () => {
  const ready = state('', []);
  const result = await simpleCompletions(new CompletionContext(ready, 0, true));
  assert.ok(result);
  const labels = result.options.map((option) => option.label);
  for (const word of [...keywords, ...builtins.map(({ name }) => name)])
    assert.ok(labels.includes(word));
  for (const word of ['in', 'range', 'class', 'import']) assert.ok(!labels.includes(word));
  assert.equal(typeof result.options.find((option) => option.label === 'for')?.apply, 'function');
  for (const kind of ['string', 'comment'] as const) {
    const source = kind === 'string' ? '"pr' : '# pr';
    const current = state(source, [{ start: 0, length: source.length, kind }]);
    assert.equal(
      await simpleCompletions(new CompletionContext(current, source.length, true)),
      null
    );
  }
  const pending = state('pr');
  assert.equal(await simpleCompletions(new CompletionContext(pending, 2, true)), null);
});

test('indentation uses bridge punctuation and remains responsive while pending', () => {
  const block = state('if True:\n', [{ start: 7, length: 1, kind: 'punctuation' }]);
  assert.equal(getIndentation(block, block.doc.length), 4);
  const comment = state('if True: # condition\n', [
    { start: 7, length: 1, kind: 'punctuation' },
    { start: 9, length: 11, kind: 'comment' },
  ]);
  assert.equal(getIndentation(comment, comment.doc.length), 4);
  const list = state('var items = [\n\t1,\n]', [
    { start: 12, length: 1, kind: 'punctuation' },
    { start: 15, length: 1, kind: 'number' },
    { start: 16, length: 1, kind: 'punctuation' },
    { start: 18, length: 1, kind: 'punctuation' },
  ]);
  assert.equal(getIndentation(list, list.doc.line(2).from), 4);
  assert.equal(getIndentation(list, list.doc.line(3).from), 0);
  const pending = state('if True:\n');
  assert.equal(getIndentation(pending, pending.doc.length), 4);
});
