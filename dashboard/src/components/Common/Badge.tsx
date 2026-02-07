import React from 'react';
import { Severity } from '@/types';

interface BadgeProps {
  severity: Severity;
  label?: string;
  size?: 'sm' | 'md';
}

const colorMap: Record<
  Severity,
  { bg: string; text: string; border: string }
> = {
  [Severity.CRITICAL]: {
    bg: 'rgba(239, 68, 68, 0.12)',
    text: '#f87171',
    border: 'rgba(239, 68, 68, 0.25)',
  },
  [Severity.HIGH]: {
    bg: 'rgba(249, 115, 22, 0.12)',
    text: '#fb923c',
    border: 'rgba(249, 115, 22, 0.25)',
  },
  [Severity.MEDIUM]: {
    bg: 'rgba(245, 158, 11, 0.12)',
    text: '#fbbf24',
    border: 'rgba(245, 158, 11, 0.25)',
  },
  [Severity.LOW]: {
    bg: 'rgba(59, 130, 246, 0.12)',
    text: '#60a5fa',
    border: 'rgba(59, 130, 246, 0.25)',
  },
};

const Badge: React.FC<BadgeProps> = ({ severity, label, size = 'sm' }) => {
  const colors = colorMap[severity];
  const text = label || severity.charAt(0).toUpperCase() + severity.slice(1);

  const style: React.CSSProperties = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '5px',
    padding: size === 'sm' ? '2px 8px' : '4px 12px',
    borderRadius: '20px',
    fontSize: size === 'sm' ? '11px' : '12px',
    fontWeight: 600,
    letterSpacing: '0.02em',
    backgroundColor: colors.bg,
    color: colors.text,
    border: `1px solid ${colors.border}`,
    textTransform: 'uppercase' as const,
    lineHeight: 1.4,
    whiteSpace: 'nowrap' as const,
  };

  const dotStyle: React.CSSProperties = {
    width: size === 'sm' ? 5 : 6,
    height: size === 'sm' ? 5 : 6,
    borderRadius: '50%',
    backgroundColor: colors.text,
    flexShrink: 0,
  };

  return (
    <span style={style}>
      <span style={dotStyle} />
      {text}
    </span>
  );
};

export default Badge;
