import React from 'react';

interface StatCardProps {
  title: string;
  value: string;
  subtitle?: string;
  trend?: number;
  icon?: string;
  sparklineData?: number[];
}

const styles: Record<string, React.CSSProperties> = {
  card: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px solid #1e293b',
    padding: '24px',
    flex: 1,
    minWidth: 0,
    transition: 'border-color 200ms ease, box-shadow 200ms ease',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: '16px',
  },
  titleRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  icon: {
    fontSize: '18px',
    lineHeight: 1,
  },
  title: {
    fontSize: '13px',
    fontWeight: 500,
    color: '#94a3b8',
    letterSpacing: '0.01em',
  },
  trendBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '3px',
    fontSize: '12px',
    fontWeight: 600,
    padding: '3px 8px',
    borderRadius: '20px',
  },
  value: {
    fontSize: '32px',
    fontWeight: 700,
    color: '#f1f5f9',
    letterSpacing: '-0.025em',
    lineHeight: 1.1,
    marginBottom: '8px',
  },
  bottom: {
    display: 'flex',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    gap: '16px',
  },
  subtitle: {
    fontSize: '12px',
    color: '#64748b',
    lineHeight: 1.4,
  },
  sparklineContainer: {
    flexShrink: 0,
    width: '80px',
    height: '32px',
  },
};

function buildSparklinePath(data: number[], width: number, height: number): string {
  if (data.length < 2) return '';
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const padding = 2;
  const usableHeight = height - padding * 2;
  const step = width / (data.length - 1);

  return data
    .map((v, i) => {
      const x = i * step;
      const y = padding + usableHeight - ((v - min) / range) * usableHeight;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  subtitle,
  trend,
  icon,
  sparklineData,
}) => {
  const [hovered, setHovered] = React.useState(false);

  const trendColor = trend !== undefined
    ? trend >= 0
      ? { bg: 'rgba(16, 185, 129, 0.12)', text: '#10b981', border: 'rgba(16, 185, 129, 0.25)' }
      : { bg: 'rgba(239, 68, 68, 0.12)', text: '#ef4444', border: 'rgba(239, 68, 68, 0.25)' }
    : null;

  const sparklineSvgWidth = 80;
  const sparklineSvgHeight = 32;
  const sparklinePoints = sparklineData
    ? buildSparklinePath(sparklineData, sparklineSvgWidth, sparklineSvgHeight)
    : '';

  const sparklineLineColor = trend !== undefined && trend < 0 ? '#ef4444' : '#3b82f6';

  return (
    <div
      style={{
        ...styles.card,
        borderColor: hovered ? '#334155' : '#1e293b',
        boxShadow: hovered
          ? '0 8px 24px rgba(0, 0, 0, 0.3)'
          : '0 2px 8px rgba(0, 0, 0, 0.15)',
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div style={styles.header}>
        <div style={styles.titleRow}>
          {icon && <span style={styles.icon}>{icon}</span>}
          <span style={styles.title}>{title}</span>
        </div>
        {trend !== undefined && trendColor && (
          <span
            style={{
              ...styles.trendBadge,
              backgroundColor: trendColor.bg,
              color: trendColor.text,
              border: `1px solid ${trendColor.border}`,
            }}
          >
            {trend >= 0 ? '\u2191' : '\u2193'}{' '}
            {Math.abs(trend).toFixed(1)}%
          </span>
        )}
      </div>

      <div style={styles.value}>{value}</div>

      <div style={styles.bottom}>
        {subtitle && <span style={styles.subtitle}>{subtitle}</span>}
        {sparklineData && sparklineData.length >= 2 && (
          <div style={styles.sparklineContainer}>
            <svg
              width={sparklineSvgWidth}
              height={sparklineSvgHeight}
              viewBox={`0 0 ${sparklineSvgWidth} ${sparklineSvgHeight}`}
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <defs>
                <linearGradient id={`spark-grad-${title.replace(/\s/g, '')}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={sparklineLineColor} stopOpacity="0.3" />
                  <stop offset="100%" stopColor={sparklineLineColor} stopOpacity="0" />
                </linearGradient>
              </defs>
              {/* Gradient fill area */}
              <polygon
                points={`0,${sparklineSvgHeight} ${sparklinePoints} ${sparklineSvgWidth},${sparklineSvgHeight}`}
                fill={`url(#spark-grad-${title.replace(/\s/g, '')})`}
              />
              {/* Line */}
              <polyline
                points={sparklinePoints}
                stroke={sparklineLineColor}
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                fill="none"
              />
            </svg>
          </div>
        )}
      </div>
    </div>
  );
};

export default StatCard;
