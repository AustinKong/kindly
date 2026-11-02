import { builtins } from '../builtins.ts';

// Static highlighting for documentation. The editor uses the runtime lexer.
export const kindlyGrammar = {
  name: 'kindly',
  scopeName: 'source.kindly',
  patterns: [
    { name: 'comment.line.number-sign.kindly', match: '#.*$' },
    { name: 'string.quoted.double.kindly', match: '"[^"\\n]*(?:"|$)' },
    {
      name: 'keyword.control.kindly',
      match:
        '(?i)^\\s*(?:Dear\\s+Compiler|Best\\s+regards|Please\\s+(?:let|update|define)|Kindly\\s+(?:execute|return|cease|proceed)|With\\s+respect\\s+to|Alternatively,\\s*if|Otherwise|As\\s+long\\s+as|For\\s+each)\\b',
    },
    { name: 'constant.language.kindly', match: '(?i)\\b(?:true|false|none)\\b' },
    { name: 'keyword.operator.kindly', match: '(?i)\\b(?:and|or|not)\\b' },
    {
      name: 'support.function.kindly',
      match: `\\b(?:${builtins.map(({ name }) => name).join('|')})\\b`,
    },
    { name: 'constant.numeric.kindly', match: '\\b[0-9]+(?:\\.[0-9]+)?' },
    { name: 'variable.other.kindly', match: '[A-Za-z_][A-Za-z_0-9]*' },
    { name: 'keyword.operator.kindly', match: '!=|==|<=|>=|[=<>+*/%\\-]' },
  ],
};
