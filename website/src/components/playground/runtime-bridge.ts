export type Language = 'simple' | 'kindly';

export type RunResult = {
  runId: number;
  language: Language;
  ok: boolean;
  output: string[];
  error: {
    phase: 'scan' | 'compile' | 'runtime';
    message: string;
    line: number;
    start?: number;
    length?: number;
    stackTrace: string[];
  } | null;
};

export type TokenKind =
  | 'keyword'
  | 'identifier'
  | 'definition'
  | 'function'
  | 'builtin'
  | 'number'
  | 'string'
  | 'bool'
  | 'null'
  | 'operator'
  | 'punctuation'
  | 'comment'
  | 'invalid';

export type TokenizeResult = {
  language: Language;
  revision: number;
  tokens: { start: number; length: number; kind: TokenKind }[];
};

declare global {
  interface Window {
    run?: (source: string, language: Language, runId: number) => void;
    tokenize?: (source: string, language: Language, revision: number) => void;
    onTokens?: (resultJson: string) => void;
    onReady?: () => void;
    onDone?: (resultJson: string) => void;
    onBridgeError?: (message: string) => void;
  }
}

export function mountRuntime(callbacks: {
  onReady: () => void;
  onDone: (result: RunResult) => void;
  onTokens: (result: TokenizeResult) => void;
  onBridgeError: (message: string) => void;
}) {
  const controller = new AbortController();
  const reportConnectionError = () =>
    callbacks.onBridgeError('Unable to connect to the interpreter. Reload the page to try again.');

  const frame = document.createElement('iframe');
  frame.className = 'runtime-frame';
  frame.title = 'Runtime';
  frame.tabIndex = -1;
  frame.setAttribute('aria-hidden', 'true');

  window.onReady = callbacks.onReady;
  window.onDone = (json) => {
    try {
      callbacks.onDone(JSON.parse(json) as RunResult);
    } catch {
      reportConnectionError();
    }
  };
  window.onBridgeError = reportConnectionError;
  window.onTokens = (json) => {
    try {
      callbacks.onTokens(JSON.parse(json) as TokenizeResult);
    } catch {
      reportConnectionError();
    }
  };

  // Check first: a missing iframe document otherwise looks like an endless load.
  fetch('/runtime/index.html', { signal: controller.signal })
    .then((response) => {
      if (!response.ok) throw new Error('Unable to load the runtime. Reload to try again.');

      frame.src = '/runtime/index.html';
      document.body.append(frame);
    })
    .catch(() => {
      if (!controller.signal.aborted) reportConnectionError();
    });

  // Return cleanup function for React's useEffect.
  return () => {
    controller.abort();
    frame.remove();

    delete window.run;
    delete window.tokenize;
    delete window.onTokens;
    delete window.onReady;
    delete window.onDone;
    delete window.onBridgeError;
  };
}
