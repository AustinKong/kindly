import { ArrowLeft } from 'lucide-react';
import type { Language } from '../playground/runtime-bridge';
import './navigation.css';

type Props = { active?: Language | 'standard-library' };

export default function Navigation({ active }: Props) {
  return (
    <nav className="page-nav" aria-label="Main navigation">
      <a href="/">
        <ArrowLeft size={16} aria-hidden="true" /> Home
      </a>
      <div>
        <a
          href="/docs/kindly"
          className="ui-button"
          data-variant={active === 'kindly' ? 'primary' : 'secondary'}
        >
          Kindly docs
        </a>
        <a
          href="/docs/simple"
          className="ui-button"
          data-variant={active === 'simple' ? 'primary' : 'secondary'}
        >
          Simple docs
        </a>
        <a
          href="/docs/standard-library"
          className="ui-button"
          data-variant={active === 'standard-library' ? 'primary' : 'secondary'}
        >
          Standard library
        </a>
      </div>
    </nav>
  );
}
