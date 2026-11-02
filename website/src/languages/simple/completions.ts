import { completeFromList, type CompletionContext } from '@codemirror/autocomplete';
import { builtins } from '../builtins.ts';
import { currentTokens } from '../tokenization.ts';
import { keywords } from './syntax.ts';

const complete = completeFromList([
  ...keywords.map((label) => ({
    label,
    type: ['True', 'False', 'None'].includes(label) ? 'constant' : 'keyword',
  })),
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
