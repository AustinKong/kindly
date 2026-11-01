import {
  completeFromList,
  snippetCompletion,
  type CompletionContext,
} from '@codemirror/autocomplete';
import { builtins } from '../builtins.ts';
import { currentTokens } from '../tokenization.ts';
import { keywords } from './syntax.ts';

const snippets: Record<string, string> = {
  var: 'var ${1:name} = ${2:value}',
  def: 'def ${1:name}(${2:parameters}):\n\treturn ${3:value}',
  if: 'if ${1:condition}:\n\t${2:body}',
  elif: 'elif ${1:condition}:\n\t${2:body}',
  else: 'else:\n\t${1:body}',
  while: 'while ${1:condition}:\n\t${2:body}',
  for: 'for var ${1:i} = ${2:0} to ${3:10}:\n\tprint(${1:i})',
};

const complete = completeFromList([
  ...keywords.map((label) =>
    snippets[label]
      ? snippetCompletion(snippets[label], { label, type: 'keyword' })
      : { label, type: ['True', 'False', 'None'].includes(label) ? 'constant' : 'keyword' }
  ),
  ...builtins.map(({ name, signature }) => ({
    label: name,
    type: 'function',
    detail: signature,
  })),
]);

export async function simpleCompletions(context: CompletionContext) {
  const current = await currentTokens(context);
  if (!current) return null;
  const token = current.tokens.find((token) => token.from < context.pos && token.to >= context.pos);
  if (token?.kind === 'string' || token?.kind === 'comment') return null;
  return complete(context);
}
