import type { CompletionContext } from '@codemirror/autocomplete';
import { StateEffect, StateField } from '@codemirror/state';
import { Decoration, EditorView, ViewPlugin, type DecorationSet } from '@codemirror/view';
import type { TokenizeResult, TokenKind } from '../components/playground/runtime-bridge.ts';

export type EditorToken = { from: number; to: number; kind: TokenKind };
type Tokens = {
  revision: number;
  ready: boolean;
  tokens: EditorToken[];
  decorations: DecorationSet;
};

export const setTokens = StateEffect.define<TokenizeResult>();

// Godot offsets count code points; CodeMirror offsets count UTF-16 code units.
export function utf16Offsets(source: string) {
  const offsets = [0];
  for (const character of source) offsets.push(offsets[offsets.length - 1] + character.length);
  return offsets;
}

function empty(revision: number): Tokens {
  return {
    revision,
    ready: false,
    tokens: [],
    decorations: Decoration.none,
  };
}

export const tokenState = StateField.define<Tokens>({
  create: () => empty(0),
  update(previous, transaction) {
    let next = transaction.docChanged
      ? {
          ...empty(previous.revision + 1),
          decorations: previous.decorations.map(transaction.changes),
        }
      : previous;
    for (const effect of transaction.effects) {
      if (!effect.is(setTokens)) continue;
      const result = effect.value;
      if (result.language !== 'simple' || result.revision !== next.revision) continue;
      const offsets = utf16Offsets(transaction.newDoc.toString());
      const range = ({ start, length }: { start: number; length: number }) => ({
        from: offsets[Math.max(0, Math.min(start, offsets.length - 1))],
        to: offsets[Math.max(0, Math.min(start + length, offsets.length - 1))],
      });
      const tokens = result.tokens.map((token) => ({ ...range(token), kind: token.kind }));
      next = {
        ...next,
        ready: true,
        tokens,
        decorations: Decoration.set(
          tokens
            .filter((token) => token.from < token.to)
            .map((token) =>
              Decoration.mark({ class: `tok-${token.kind}` }).range(token.from, token.to)
            ),
          true
        ),
      };
    }
    return next;
  },
  provide: (field) => EditorView.decorations.from(field, (value) => value.decorations),
});

const waiting = new WeakMap<EditorView, Set<(available: boolean) => void>>();

// Completion queries can wait for the debounced lexer response without lexing in JS.
export function currentTokens(context: CompletionContext): Promise<Tokens | null> {
  const expected = context.state.field(tokenState);
  if (expected.ready) return Promise.resolve(expected);
  const view = context.view;
  if (!view) return Promise.resolve(null);
  return new Promise((resolve) => {
    const listeners = waiting.get(view)!;
    const finish = (available: boolean) => {
      listeners.delete(finish);
      const current = view.state.field(tokenState);
      resolve(
        available && !context.aborted && current.revision === expected.revision && current.ready
          ? current
          : null
      );
    };
    listeners.add(finish);
    context.addEventListener('abort', () => finish(false), { onDocChange: true });
    if (view.state.field(tokenState).ready) finish(true);
  });
}

export const tokenization = [
  tokenState,
  ViewPlugin.define((view) => {
    const listeners = new Set<(available: boolean) => void>();
    waiting.set(view, listeners);
    return {
      update(update) {
        if (update.docChanged || update.state.field(tokenState).ready) {
          for (const listener of [...listeners]) listener(true);
        }
      },
      destroy() {
        for (const listener of [...listeners]) listener(false);
        waiting.delete(view);
      },
    };
  }),
  EditorView.baseTheme({
    '.tok-keyword, .tok-bool, .tok-null': { color: 'var(--color-primary)', fontWeight: '600' },
    '.tok-function, .tok-builtin': { color: 'var(--color-navy)' },
    '.tok-string': { color: '#276749' },
    '.tok-number': { color: '#9d6241' },
    '.tok-comment': { color: 'var(--color-muted)', fontStyle: 'italic' },
    '.tok-operator, .tok-punctuation': { color: 'var(--color-muted)' },
  }),
];
