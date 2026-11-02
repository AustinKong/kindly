import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import CodeMirror, { type ReactCodeMirrorRef } from '@uiw/react-codemirror';
import { vim } from '@replit/codemirror-vim';
import { indentUnit } from '@codemirror/language';
import { setDiagnostics, setDiagnosticsEffect } from '@codemirror/lint';
import { Compartment, countColumn, EditorState, Prec } from '@codemirror/state';
import { EditorView, type ViewUpdate } from '@codemirror/view';
import { Mail, PenLine, Send } from 'lucide-react';
import Button from '../shared/Button';
import type { Language, RunResult, TokenizeResult } from './runtime-bridge';
import {
  language as languageFacet,
  revisionClock,
  setTokens,
  tokenState,
  tokenization as tokenizationSupport,
  utf16Offsets,
} from '../../languages/tokenization';
import { simple } from '../../languages/simple';
import { kindly } from '../../languages/kindly';

export type EditorStatus = 'loading' | 'ready' | 'running' | 'error';
export type EditorDiagnostic = { language: Language; source: string; error: RunResult['error'] };

type Props = {
  language: Language;
  source: string;
  onLanguageChange: (language: Language) => void;
  onSourceChange: (source: string) => void;
  status: EditorStatus;
  diagnostic: EditorDiagnostic | null;
  tokenization: TokenizeResult | null;
  onRun: (source: string, subject: string) => void;
};

let revision = 0;
const nextRevision = () => ++revision;

const basicSetup = { foldGutter: false };
const vimMode = new Compartment();
const indentation = new Compartment();

const extensions = [
  revisionClock.of(nextRevision),
  tokenizationSupport,
  vimMode.of([]),
  indentation.of([indentUnit.of('\t'), EditorState.tabSize.of(4)]),
  EditorState.lineSeparator.of('\n'),
  EditorState.transactionExtender.of((transaction) =>
    transaction.docChanged ? { effects: setDiagnosticsEffect.of([]) } : null
  ),
  EditorView.clipboardInputFilter.of((text) => text.replace(/\r\n?/g, '\n')),
  EditorView.contentAttributes.of({ 'aria-label': 'Source code', spellcheck: 'false' }),
];

export default function Editor({
  language,
  source,
  onLanguageChange,
  onSourceChange,
  status,
  diagnostic,
  tokenization,
  onRun,
}: Props) {
  const languageExtensions = useMemo(
    () => [languageFacet.of(language), language === 'kindly' ? kindly() : simple(), ...extensions],
    [language]
  );
  const [subject, setSubject] = useState('A small request');
  const [vimEnabled, setVimEnabled] = useState(false);
  const [tabSize, setTabSize] = useState(4);
  const [position, setPosition] = useState({ line: 1, column: 1 });
  const editor = useRef<ReactCodeMirrorRef>(null);
  const runtimeReady = status === 'ready' || status === 'running';

  useEffect(() => {
    if (!runtimeReady) return;
    const view = editor.current?.view;
    if (!view) return;
    const revision = view.state.field(tokenState).revision;
    const snapshot = view.state.doc.toString();
    const timer = window.setTimeout(() => {
      if (view.state.field(tokenState).revision === revision)
        window.tokenize?.(snapshot, language, revision);
    }, 120);
    return () => window.clearTimeout(timer);
  }, [source, runtimeReady, language]);

  useEffect(() => {
    if (tokenization) editor.current?.view?.dispatch({ effects: setTokens.of(tokenization) });
  }, [tokenization]);

  const handleEditorUpdate = useCallback((update: ViewUpdate) => {
    const head = update.state.selection.main.head;
    const line = update.state.doc.lineAt(head);
    const column =
      countColumn(line.text.slice(0, head - line.from), update.state.facet(EditorState.tabSize)) +
      1;
    setPosition((previous) =>
      previous.line === line.number && previous.column === column
        ? previous
        : { line: line.number, column }
    );
  }, []);

  function toggleVim() {
    const enabled = !vimEnabled;
    editor.current?.view?.dispatch({
      effects: vimMode.reconfigure(enabled ? Prec.high(vim()) : []),
    });
    setVimEnabled(enabled);
  }

  function changeTabSize(size: number) {
    editor.current?.view?.dispatch({
      effects: indentation.reconfigure([indentUnit.of('\t'), EditorState.tabSize.of(size)]),
    });
    setTabSize(size);
  }

  useEffect(() => {
    const view = editor.current?.view;
    if (!view) return;
    if (!diagnostic) {
      view.dispatch(setDiagnostics(view.state, []));
      return;
    }
    const { source, error } = diagnostic;
    if (diagnostic.language !== language || view.state.doc.toString() !== source) return;
    if (!error || error.line < 0 || error.line >= view.state.doc.lines) {
      view.dispatch(setDiagnostics(view.state, []));
      return;
    }

    const line = view.state.doc.line(error.line + 1);
    let from = line.from;
    let to = line.to;
    if (error.start !== undefined && error.length !== undefined) {
      // Godot counts Unicode code points; CodeMirror counts UTF-16 code units.
      const offsets = utf16Offsets(source);
      from = offsets[error.start];
      to = offsets[error.start + error.length];
    }
    view.dispatch(
      setDiagnostics(view.state, [{ from, to, severity: 'error', message: error.message }])
    );
  }, [diagnostic, language]);

  return (
    <section aria-labelledby="source-heading">
      <header>
        <h2 id="source-heading">
          <PenLine aria-hidden="true" /> New message
        </h2>
        <Button
          variant="primary"
          onClick={() => onRun(source, subject)}
          disabled={status !== 'ready'}
          aria-label="Send and run code"
        >
          <Send aria-hidden="true" />
          {status === 'loading'
            ? 'Connecting…'
            : status === 'running'
              ? 'Sending…'
              : status === 'error'
                ? 'Unavailable'
                : 'Send'}
        </Button>
      </header>
      <div className="compose-fields">
        <div>
          <span>To</span>
          <span>Kindly interpreter</span>
          <Mail aria-hidden="true" />
        </div>
        <label>
          <span>Subject</span>
          <input value={subject} onChange={(event) => setSubject(event.target.value)} />
        </label>
      </div>
      <div className="source-body">
        <CodeMirror
          key={language}
          ref={editor}
          className="code-editor"
          value={source}
          onChange={onSourceChange}
          onCreateEditor={(view) =>
            view.dispatch({
              effects: [
                vimMode.reconfigure(vimEnabled ? Prec.high(vim()) : []),
                indentation.reconfigure([indentUnit.of('\t'), EditorState.tabSize.of(tabSize)]),
              ],
            })
          }
          onUpdate={handleEditorUpdate}
          extensions={languageExtensions}
          height="100%"
          indentWithTab
          basicSetup={basicSetup}
        />
      </div>
      <footer>
        <label>
          Language
          <select
            aria-label="Language"
            value={language}
            onChange={(event) => onLanguageChange(event.target.value as Language)}
          >
            <option value="simple">Simple</option>
            <option value="kindly">Kindly</option>
          </select>
        </label>
        <Button
          variant="ghost"
          role="switch"
          aria-label="Vim mode"
          aria-checked={vimEnabled}
          onClick={toggleVim}
        >
          Vim <span aria-hidden="true">{vimEnabled ? 'On' : 'Off'}</span>
        </Button>
        <label>
          Tab size
          <select
            aria-label="Indentation size"
            value={tabSize}
            onChange={(event) => changeTabSize(Number(event.target.value))}
          >
            <option value={2}>2</option>
            <option value={4}>4</option>
            <option value={8}>8</option>
          </select>
        </label>
        <output aria-label="Cursor position">
          Ln {position.line}, Col {position.column}
        </output>
      </footer>
    </section>
  );
}
