import type { HTMLAttributes } from 'react';
import type { BadgeTone } from './ui-types';

type Props = HTMLAttributes<HTMLSpanElement> & { tone?: BadgeTone };

export default function Badge({ tone = 'neutral', className = '', ...props }: Props) {
  return <span {...props} className={`ui-badge ${className}`} data-tone={tone} />;
}
