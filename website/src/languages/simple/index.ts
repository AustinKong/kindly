import { EditorState } from '@codemirror/state';
import { simpleCompletions } from './completions.ts';
import { indentation } from '../tokenization.ts';

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
