import { EditorState } from '@codemirror/state';
import {
  completeFromList,
  snippetCompletion,
  type CompletionContext,
} from '@codemirror/autocomplete';
import { builtins } from '../builtins.ts';
import { currentTokens, indentation } from '../tokenization.ts';

export const initialSource =
  'Dear Compiler,\n\nPlease let message be "Hello, Kindly!".\nKindly execute print(message).\n\nBest regards.\n';

const snippets: Record<string, string> = {
  'Please let': 'Please let ${1:name} be ${2:value}.',
  'Please update': 'Please update ${1:name} to ${2:value}.',
  'Please define': 'Please define ${1:name}(${2:parameters}):\n\tKindly return ${3:value}.',
  'Kindly execute': 'Kindly execute ${1:print}(${2:value}).',
  'Kindly return': 'Kindly return ${1:value}.',
  'Kindly cease': 'Kindly cease.',
  'Kindly proceed': 'Kindly proceed.',
  'With respect to': 'With respect to ${1:condition}:\n\t${2:body}',
  'Alternatively, if': 'Alternatively, if ${1:condition}:\n\t${2:body}',
  Otherwise: 'Otherwise:\n\t${1:body}',
  'As long as': 'As long as ${1:condition}:\n\t${2:body}',
  'For each': 'For each ${1:i} from ${2:0} to ${3:10}:\n\tKindly execute print(${1:i}).',
  'Dear Compiler': 'Dear Compiler,',
  'Best regards': 'Best regards.',
};
const phrases = Object.entries(snippets).map(([label, snippet]) =>
  snippetCompletion(snippet, { label, type: 'keyword' })
);
const complete = completeFromList([
  ...builtins.map(({ name, signature }) => ({ label: name, type: 'function', detail: signature })),
  ...['true', 'false', 'none', 'and', 'or', 'not'].map((label) => ({ label, type: 'keyword' })),
]);

export async function kindlyCompletions(context: CompletionContext) {
  const current = await currentTokens(context);
  if (!current) return null;
  const token = current.tokens.find((token) => token.from < context.pos && token.to >= context.pos);
  if (token?.kind === 'string' || token?.kind === 'comment') return null;
  const prefix = context.matchBefore(/[A-Za-z][A-Za-z ,]*$/);
  const options = prefix
    ? phrases.filter((option) => option.label.toLowerCase().startsWith(prefix.text.toLowerCase()))
    : [];
  if (prefix && options.length) return { from: prefix.from, options, filter: false };
  if (
    !prefix &&
    context.explicit &&
    !context.state.doc
      .lineAt(context.pos)
      .text.slice(0, context.pos - context.state.doc.lineAt(context.pos).from)
      .trim()
  )
    return { from: context.pos, options: phrases };
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
