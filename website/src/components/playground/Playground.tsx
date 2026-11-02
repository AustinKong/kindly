import { useCallback, useEffect, useRef, useState } from 'react';
import Editor, { type EditorDiagnostic, type EditorStatus } from './Editor';
import Console, { type Reply } from './Console';
import { mountRuntime, type Language, type TokenizeResult } from './runtime-bridge';
import './playground.css';
import Navigation from '../shared/Navigation';
import { initialSource as simpleSource } from '../../languages/simple';
import { initialSource as kindlySource } from '../../languages/kindly';

function urlLanguage(): Language {
  return new URLSearchParams(window.location.search).get('language') === 'simple'
    ? 'simple'
    : 'kindly';
}

export default function Playground() {
  const [language, setLanguage] = useState<Language>('kindly');
  const drafts = useRef({ simple: simpleSource, kindly: kindlySource });
  const handleSourceChange = useCallback(
    (source: string) => {
      drafts.current[language] = source;
    },
    [language]
  );
  useEffect(() => {
    const sync = () => {
      setLanguage(urlLanguage());
      setDiagnostic(null);
      setTokenization(null);
    };
    sync();
    window.addEventListener('popstate', sync);
    return () => window.removeEventListener('popstate', sync);
  }, []);

  function changeLanguage(language: Language) {
    const url = new URL(window.location.href);
    url.searchParams.set('language', language);
    window.history.pushState(null, '', url);
    setLanguage(language);
    setDiagnostic(null);
    setTokenization(null);
  }

  const [status, setStatus] = useState<EditorStatus>('loading');
  const [replies, setReplies] = useState<Reply[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [bridgeError, setBridgeError] = useState('');
  const [diagnostic, setDiagnostic] = useState<EditorDiagnostic | null>(null);
  const [tokenization, setTokenization] = useState<TokenizeResult | null>(null);
  const request = useRef({ id: 0, source: '', subject: '', language: 'kindly' as Language });

  useEffect(
    () =>
      mountRuntime({
        onReady: () => setStatus('ready'),
        onTokens: setTokenization,
        onDone: (result) => {
          const { id, source, subject } = request.current;
          if (result.runId !== id) return;
          setDiagnostic({ source, language: result.language, error: result.error });

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
      language,
      subject: subject.trim() || '(no subject)',
    };
    setDiagnostic(null);
    setStatus('running');
    window.run(source, language, request.current.id);
  }

  function clearInbox() {
    setReplies([]);
    setSelectedId(null);
  }

  return (
    <>
      <Navigation active={language} />
      <div className="playground">
        <Editor
          key={language}
          language={language}
          initialSource={drafts.current[language]}
          onLanguageChange={changeLanguage}
          onSourceChange={handleSourceChange}
          status={status}
          diagnostic={diagnostic}
          tokenization={tokenization}
          onRun={handleRun}
        />
        <Console
          replies={replies}
          selectedId={selectedId}
          bridgeError={bridgeError}
          onSelect={setSelectedId}
          onClear={clearInbox}
        />
      </div>
    </>
  );
}
