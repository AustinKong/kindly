import { useEffect, useRef, useState } from 'react';
import CodeMirror from '@uiw/react-codemirror';
import { indentUnit } from '@codemirror/language';
import { EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';

import { mountRuntime } from './runtime-bridge';
import './playground.css';

type Status = 'loading' | 'ready' | 'running' | 'error';

const initialSource = 'var message = "Hello, Kindly!"\nprint(message)\n';

const extensions = [
  indentUnit.of('\t'),
  EditorState.tabSize.of(4),
  EditorState.lineSeparator.of('\n'),
  EditorView.clipboardInputFilter.of((text) => text.replace(/\r\n?/g, '\n')),
  EditorView.contentAttributes.of({ 'aria-label': 'Source code', spellcheck: 'false' }),
];

export default function Playground() {
  const [source, setSource] = useState(initialSource);
  const [status, setStatus] = useState<Status>('loading');
  const [output, setOutput] = useState('');

  const activeRun = useRef(0);

  useEffect(
    () =>
      mountRuntime({
        onReady: () => setStatus('ready'),
        onDone: (result) => {
          if (result.runId !== activeRun.current) return;

          const lines = [...result.output];
          if (result.error) {
            lines.push(`Line ${result.error.line + 1}: ${result.error.message}`);
            lines.push(...result.error.stackTrace.map((frame) => `  ${frame}`));
          }

          setOutput(lines.join('\n'));
          setStatus('ready');
        },
        onBridgeError: (message) => {
          setOutput(message);
          setStatus('error');
        },
      }),
    []
  );

  function handleRun() {
    if (status !== 'ready' || !window.run) return;

    activeRun.current += 1;
    setOutput('');
    setStatus('running');

    window.run(source, activeRun.current);
  }

  return (
    <div className="playground">
      <section className="playground-panel" aria-labelledby="source-heading">
        <header className="panel-heading">
          <h2 id="source-heading">Source</h2>
          <button
            type="button"
            className="run-button"
            onClick={handleRun}
            disabled={status !== 'ready'}
          >
            {status === 'loading' ? 'Loading…' : status === 'running' ? 'Running…' : 'Run'}
          </button>
        </header>
        <div className="source-body">
          <CodeMirror
            className="code-editor"
            value={source}
            onChange={setSource}
            extensions={extensions}
            height="100%"
            indentWithTab
            basicSetup={{ foldGutter: false, autocompletion: false }}
          />
        </div>
      </section>

      <section className="playground-panel console-panel" aria-labelledby="console-heading">
        <header className="panel-heading">
          <h2 id="console-heading">Console</h2>
        </header>
        <pre className="console-output" role="log" aria-label="Console output" aria-live="polite">
          {output || <span className="console-placeholder">No output yet.</span>}
        </pre>
      </section>
    </div>
  );
}
