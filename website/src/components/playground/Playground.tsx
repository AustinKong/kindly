import { useEffect, useRef, useState } from 'react';
import Editor, { type EditorDiagnostic, type EditorStatus } from './Editor';
import Console, { type Reply } from './Console';
import { mountRuntime } from './runtime-bridge';
import './playground.css';

export default function Playground() {
  const [status, setStatus] = useState<EditorStatus>('loading');
  const [replies, setReplies] = useState<Reply[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [bridgeError, setBridgeError] = useState('');
  const [diagnostic, setDiagnostic] = useState<EditorDiagnostic | null>(null);
  const request = useRef({ id: 0, source: '', subject: '' });

  useEffect(
    () =>
      mountRuntime({
        onReady: () => setStatus('ready'),
        onDone: (result) => {
          const { id, source, subject } = request.current;
          if (result.runId !== id) return;
          setDiagnostic({ source, error: result.error });

          const lines = [...result.output];
          if (result.error) {
            lines.push(`Line ${result.error.line + 1}: ${result.error.message}`);
            lines.push(...result.error.stackTrace.map((frame) => `  ${frame}`));
          }
          setReplies((previous) => [
            {
              id: result.runId,
              subject,
              output: lines.join('\n'),
              ok: result.ok,
              receivedAt: new Date().toISOString(),
            },
            ...previous,
          ]);
          setSelectedId(result.runId);
          setStatus('ready');
        },
        onBridgeError: (message) => {
          setBridgeError(message);
          setStatus('error');
        },
      }),
    []
  );

  function handleRun(source: string, subject: string) {
    if (status !== 'ready' || !window.run) return;
    request.current = {
      id: request.current.id + 1,
      source,
      subject: subject.trim() || '(no subject)',
    };
    setDiagnostic(null);
    setStatus('running');
    window.run(source, request.current.id);
  }

  function clearInbox() {
    setReplies([]);
    setSelectedId(null);
  }

  return (
    <div className="playground">
      <Editor status={status} diagnostic={diagnostic} onRun={handleRun} />
      <Console
        replies={replies}
        selectedId={selectedId}
        bridgeError={bridgeError}
        onSelect={setSelectedId}
        onClear={clearInbox}
      />
    </div>
  );
}
