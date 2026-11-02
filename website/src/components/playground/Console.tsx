import { useEffect, useRef } from 'react';
import { Check, CircleAlert, Inbox, Mail, Trash2 } from 'lucide-react';
import Button from '../shared/Button';
import Badge from '../shared/Badge';

export type Reply = {
  id: number;
  subject: string;
  output: string;
  ok: boolean;
  receivedAt: string;
};

type Props = {
  replies: Reply[];
  selectedId: number | null;
  bridgeError: string;
  onSelect: (id: number) => void;
  onClear: () => void;
};

export default function Console({ replies, selectedId, bridgeError, onSelect, onClear }: Props) {
  const inbox = useRef<HTMLUListElement>(null);
  const newestReplyId = replies[0]?.id;
  useEffect(() => {
    if (inbox.current) inbox.current.scrollTop = 0;
  }, [newestReplyId]);
  const selected = replies.find((reply) => reply.id === selectedId);
  return (
    <section aria-labelledby="console-heading">
      <header>
        <h2 id="console-heading">
          <Inbox aria-hidden="true" /> Inbox <Badge tone="info">{replies.length}</Badge>
        </h2>
        <Button
          variant="ghost"
          aria-label="Clear inbox"
          title="Clear inbox"
          disabled={replies.length === 0}
          onClick={onClear}
        >
          <Trash2 aria-hidden="true" />
        </Button>
      </header>
      {bridgeError && <p role="alert">{bridgeError}</p>}
      {replies.length > 0 && (
        <ul ref={inbox} className="inbox-messages" aria-label="Execution replies">
          {replies.map((reply) => (
            <li key={reply.id}>
              <Button
                variant="ghost"
                aria-pressed={reply.id === selectedId}
                onClick={() => onSelect(reply.id)}
              >
                {reply.ok ? <Check aria-hidden="true" /> : <CircleAlert aria-hidden="true" />}
                <strong>Kindly</strong>
                <span>Re: {reply.subject}</span>
                <time dateTime={reply.receivedAt}>
                  {new Date(reply.receivedAt).toLocaleTimeString([], {
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </time>
              </Button>
            </li>
          ))}
        </ul>
      )}
      {selected ? (
        <article key={selected.id} className="reply" aria-label="Selected execution reply">
          <header>
            <span className="avatar">
              <Mail aria-hidden="true" />
            </span>
            <div>
              <strong>Kindly interpreter</strong>
              <span>to you</span>
            </div>
            <Badge tone={selected.ok ? 'info' : 'warning'}>
              {selected.ok ? <Check aria-hidden="true" /> : <CircleAlert aria-hidden="true" />}
              {selected.ok ? 'Received' : 'Action required'}
            </Badge>
          </header>
          <pre className="console-output" role="log" aria-label="Program output" aria-live="polite">
            {selected.output || 'Your request was completed without printed output.'}
          </pre>
        </article>
      ) : (
        <div className="empty-inbox" role="status">
          <Inbox aria-hidden="true" />
          <h3>No correspondence yet.</h3>
          <p>Send your code to receive a reply.</p>
        </div>
      )}
    </section>
  );
}
