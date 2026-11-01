import { useCallback, useEffect, useRef, useState } from 'react';
import CodeMirror, { type ReactCodeMirrorRef } from '@uiw/react-codemirror';
import { vim } from '@replit/codemirror-vim';
import { indentUnit } from '@codemirror/language';
import { setDiagnostics, setDiagnosticsEffect } from '@codemirror/lint';
import { Compartment, countColumn, EditorState, Prec } from '@codemirror/state';
import { EditorView, type ViewUpdate } from '@codemirror/view';
import { Mail, PenLine, Send } from 'lucide-react';
import Button from '../shared/Button';
import type { RunResult } from './runtime-bridge';

export type EditorStatus = 'loading' | 'ready' | 'running' | 'error';
export type EditorDiagnostic = { source: string; error: RunResult['error'] };

type Props = {
  status: EditorStatus;
  diagnostic: EditorDiagnostic | null;
  onRun: (source: string, subject: string) => void;
};

const initialSource = 'var message = "Hello, Kindly!"\nprint(message)\n';

const basicSetup = { foldGutter: false, autocompletion: false };
const vimMode = new Compartment();
const indentation = new Compartment();

const extensions = [
  vimMode.of([]),
  indentation.of([indentUnit.of('\t'), EditorState.tabSize.of(4)]),
  EditorState.lineSeparator.of('\n'),
  EditorState.transactionExtender.of((transaction) =>
    transaction.docChanged ? { effects: setDiagnosticsEffect.of([]) } : null
  ),
  EditorView.clipboardInputFilter.of((text) => text.replace(/\r\n?/g, '\n')),
  EditorView.contentAttributes.of({ 'aria-label': 'Source code', spellcheck: 'false' }),
];

export default function Editor({ status, diagnostic, onRun }: Props) {
  const [source, setSource] = useState(initialSource);
  const [subject, setSubject] = useState('A small request');
  const [vimEnabled, setVimEnabled] = useState(false);
  const [tabSize, setTabSize] = useState(4);
  const [position, setPosition] = useState({ line: 1, column: 1 });
  const editor = useRef<ReactCodeMirrorRef>(null);

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
    if (view.state.doc.toString() !== source) return;
    if (!error || error.line < 0 || error.line >= view.state.doc.lines) {
      view.dispatch(setDiagnostics(view.state, []));
      return;
    }

    const line = view.state.doc.line(error.line + 1);
    let from = line.from;
    let to = line.to;
    if (error.start !== undefined && error.length !== undefined) {
      // Godot counts Unicode code points; CodeMirror counts UTF-16 code units.
      const characters = Array.from(source);
      from = characters.slice(0, error.start).join('').length;
      to = characters.slice(0, error.start + error.length).join('').length;
    }
    view.dispatch(
      setDiagnostics(view.state, [{ from, to, severity: 'error', message: error.message }])
    );
  }, [diagnostic]);

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
          {status === 'loading' ? 'Connecting…' : status === 'running' ? 'Sending…' : 'Send'}
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
          ref={editor}
          className="code-editor"
          value={source}
          onChange={setSource}
          onUpdate={handleEditorUpdate}
          extensions={extensions}
          height="100%"
          indentWithTab
          basicSetup={basicSetup}
        />
      </div>
      <footer>
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
