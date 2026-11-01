import { builtins } from '../builtins.ts';
import { keywords } from './syntax.ts';

// TextMate grammar for Astro's server-rendered code blocks.
export const simpleGrammar = {
  name: 'simple',
  scopeName: 'source.simple',
  patterns: [
    { name: 'comment.line.number-sign.simple', match: '#.*$' },
    { name: 'string.quoted.double.simple', match: '"[^"\\n]*(?:"|$)' },
    { name: 'constant.language.simple', match: '\\b(?:True|False|None)\\b' },
    { name: 'keyword.control.simple', match: `\\b(?:${keywords.join('|')})\\b` },
    {
      name: 'support.function.simple',
      match: `\\b(?:${builtins.map(({ name }) => name).join('|')})\\b`,
    },
    { name: 'constant.numeric.simple', match: '\\b[0-9]+(?:\\.[0-9]+)?' },
    { name: 'variable.other.simple', match: '[A-Za-z_][A-Za-z_0-9]*' },
    { name: 'keyword.operator.simple', match: '!=|==|<=|>=|[=<>+*/%\\-]' },
  ],
};
