import type { ButtonHTMLAttributes } from 'react';
import type { ButtonVariant } from './ui-types';

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant };

export default function Button({
  variant = 'secondary',
  className = '',
  type = 'button',
  ...props
}: Props) {
  return (
    <button {...props} type={type} className={`ui-button ${className}`} data-variant={variant} />
  );
}
