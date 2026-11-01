export type RunResult = {
  runId: number;
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
  language: 'simple';
  revision: number;
  tokens: { start: number; length: number; kind: TokenKind }[];
};

declare global {
  interface Window {
    run?: (source: string, runId: number) => void;
    tokenize?: (source: string, language: 'simple', revision: number) => void;
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
      callbacks.onBridgeError('Unable to read the execution result.');
    }
  };
  window.onBridgeError = callbacks.onBridgeError;
  window.onTokens = (json) => {
    try {
      callbacks.onTokens(JSON.parse(json) as TokenizeResult);
    } catch {
      callbacks.onBridgeError('Unable to read the tokenization result.');
    }
  };

  // Check first: a missing iframe document otherwise looks like an endless load.
  fetch('/runtime/index.html', { signal: controller.signal })
    .then((response) => {
      if (!response.ok) throw new Error('Unable to load the runtime. Reload to try again.');

      frame.src = '/runtime/index.html';
      document.body.append(frame);
    })
    .catch((error: unknown) => {
      if (!controller.signal.aborted) {
        callbacks.onBridgeError(
          error instanceof Error ? error.message : 'Unable to load the runtime.'
        );
      }
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
