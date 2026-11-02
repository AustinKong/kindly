import { EditorState } from '@codemirror/state';
import { completeFromList, type CompletionContext } from '@codemirror/autocomplete';
import { builtins } from '../builtins.ts';
import { currentTokens, indentation } from '../tokenization.ts';

export const initialSource =
  'Dear Compiler,\n\nPlease let message be "Hello, Kindly!".\nKindly execute print(message).\n\nBest regards.\n';

const keywords = [
  'Dear',
  'Compiler',
  'Best',
  'regards',
  'Please',
  'let',
  'be',
  'update',
  'to',
  'define',
  'Kindly',
  'execute',
  'return',
  'cease',
  'proceed',
  'With',
  'respect',
  'Alternatively',
  'if',
  'Otherwise',
  'As',
  'long',
  'For',
  'each',
  'from',
  'step',
  'true',
  'false',
  'none',
  'and',
  'or',
  'not',
];
const complete = completeFromList([
  ...builtins.map(({ name, signature }) => ({ label: name, type: 'function', detail: signature })),
  ...keywords.map((label) => ({ label, type: 'keyword' })),
]);

export async function kindlyCompletions(context: CompletionContext) {
  const current = await currentTokens(context);
  if (!current) return null;
  const token = current.tokens.find((token) => token.from < context.pos && token.to >= context.pos);
  if (token?.kind === 'string' || token?.kind === 'comment') return null;
  return complete(context);
}

export function kindly() {
  return [
    EditorState.languageData.of(() => [
      {
        autocomplete: kindlyCompletions,
        commentTokens: { line: '#' },
        closeBrackets: { brackets: ['(', '[', '{', '"'] },
      },
    ]),
    indentation,
  ];
}
