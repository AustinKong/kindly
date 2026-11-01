import { EditorState } from '@codemirror/state';
import { simpleCompletions } from './completions.ts';
import { indentService } from '@codemirror/language';
import { tokenState } from '../tokenization.ts';

export const initialSource = 'var message = "Hello, Kindly!"\nprint(message)\n';

export function simple() {
  return [
    EditorState.languageData.of(() => [
      {
        autocomplete: simpleCompletions,
        commentTokens: { line: '#' },
        closeBrackets: { brackets: ['(', '[', '{', '"'] },
      },
    ]),
    indentation,
  ];
}

const indentation = indentService.of((context, position) => {
  let line = context.lineAt(position, -1);
  if (line.from === position && position > 0 && context.simulatedBreak === null) {
    line = context.lineAt(position - 1, -1);
  }
  const base = context.lineIndent(line.from, -1);
  const before = line.text.slice(0, position - line.from).trimEnd();
  const current = context.state.field(tokenState);
  if (current.ready) {
    const brackets: number[] = [];
    let last = '';
    for (const token of current.tokens) {
      if (token.to > position) break;
      if (token.kind === 'comment') continue;
      const text = context.state.sliceDoc(token.from, token.to);
      if (token.kind === 'punctuation') {
        if ('([{'.includes(text)) brackets.push(token.from);
        else if (')]}'.includes(text)) brackets.pop();
      }
      if (token.from >= line.from) last = token.kind === 'punctuation' ? text : '';
    }
    if (brackets.length) {
      const opening = brackets[brackets.length - 1];
      const closing = /^[)\]}]/.test(context.textAfterPos(position).trimStart());
      return context.lineIndent(opening) + (closing ? 0 : context.unit);
    }
    return base + (last === ':' ? context.unit : 0);
  }
  // Immediate typing affordance while the debounced token response is pending.
  // Highlighting and completion context always use the lexer response.
  const header =
    /^(?:if|elif|else|while|for|def)\b/.test(before.trimStart()) && before.endsWith(':');
  return base + (header || /[([{]$/.test(before) ? context.unit : 0);
});
