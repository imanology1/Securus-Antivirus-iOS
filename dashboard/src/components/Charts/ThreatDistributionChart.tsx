import React, { useMemo } from 'react';
import {
  Chart as ChartJS,
  ArcElement,
  Tooltip,
  Legend,
} from 'chart.js';
import { Doughnut } from 'react-chartjs-2';
import type { ThreatDistribution } from '@/types';
import { ThreatType } from '@/types';

/* ── Chart.js registration ── */
ChartJS.register(ArcElement, Tooltip, Legend);

interface ThreatDistributionChartProps {
  data: ThreatDistribution[];
}

/* ── Color mapping for threat types ── */
const threatTypeColors: Record<string, string> = {
  [ThreatType.NETWORK_INTRUSION]: '#3b82f6',
  [ThreatType.MALWARE]: '#ef4444',
  [ThreatType.PHISHING]: '#f97316',
  [ThreatType.JAILBREAK]: '#ef4444',
  [ThreatType.DATA_EXFILTRATION]: '#8b5cf6',
  [ThreatType.MAN_IN_THE_MIDDLE]: '#06b6d4',
  [ThreatType.CODE_INJECTION]: '#f97316',
  [ThreatType.PRIVILEGE_ESCALATION]: '#eab308',
  [ThreatType.RANSOMWARE]: '#ec4899',
  [ThreatType.SPYWARE]: '#14b8a6',
};

/* ── Human-readable labels ── */
const threatTypeLabels: Record<string, string> = {
  [ThreatType.NETWORK_INTRUSION]: 'Network Anomaly',
  [ThreatType.MALWARE]: 'Malware',
  [ThreatType.PHISHING]: 'Phishing',
  [ThreatType.JAILBREAK]: 'Jailbreak',
  [ThreatType.DATA_EXFILTRATION]: 'Data Exfiltration',
  [ThreatType.MAN_IN_THE_MIDDLE]: 'MitM Attack',
  [ThreatType.CODE_INJECTION]: 'Code Injection',
  [ThreatType.PRIVILEGE_ESCALATION]: 'Privilege Escalation',
  [ThreatType.RANSOMWARE]: 'Ransomware',
  [ThreatType.SPYWARE]: 'Spyware',
};

const fallbackColors = [
  '#3b82f6', '#ef4444', '#f97316', '#8b5cf6', '#06b6d4',
  '#eab308', '#ec4899', '#14b8a6', '#6366f1', '#f43f5e',
];

const ThreatDistributionChart: React.FC<ThreatDistributionChartProps> = ({
  data,
}) => {
  const chartData = useMemo(() => {
    const labels = data.map(
      (d) => threatTypeLabels[d.threatType] || d.threatType,
    );
    const values = data.map((d) => d.count);
    const colors = data.map(
      (d, i) => threatTypeColors[d.threatType] || fallbackColors[i % fallbackColors.length],
    );

    return {
      labels,
      datasets: [
        {
          data: values,
          backgroundColor: colors.map((c) => `${c}cc`),
          borderColor: colors,
          borderWidth: 1.5,
          hoverBackgroundColor: colors,
          hoverBorderColor: '#fff',
          hoverBorderWidth: 2,
          spacing: 2,
          borderRadius: 3,
        },
      ],
    };
  }, [data]);

  const totalThreats = useMemo(
    () => data.reduce((sum, d) => sum + d.count, 0),
    [data],
  );

  const options = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      cutout: '68%',
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          backgroundColor: '#1a1f2e',
          titleColor: '#f1f5f9',
          bodyColor: '#94a3b8',
          borderColor: '#334155',
          borderWidth: 1,
          cornerRadius: 8,
          padding: 12,
          titleFont: {
            size: 13,
            weight: 600 as const,
          },
          bodyFont: {
            size: 12,
          },
          callbacks: {
            label: (item: { label: string; parsed: number }) =>
              `${item.label}: ${item.parsed} (${((item.parsed / totalThreats) * 100).toFixed(1)}%)`,
          },
        },
      },
    }),
    [totalThreats],
  );

  return (
    <div
      style={{
        backgroundColor: '#1a1f2e',
        borderRadius: '16px',
        border: '1px solid #1e293b',
        padding: '20px',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <span
        style={{
          fontSize: '15px',
          fontWeight: 600,
          color: '#f1f5f9',
          marginBottom: '16px',
        }}
      >
        Threat Distribution
      </span>

      {/* Chart with center label */}
      <div
        style={{
          position: 'relative',
          flex: 1,
          minHeight: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div style={{ width: '100%', maxWidth: 220, aspectRatio: '1', position: 'relative' }}>
          <Doughnut data={chartData} options={options} />
          {/* Center label */}
          <div
            style={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
              textAlign: 'center',
              pointerEvents: 'none',
            }}
          >
            <div
              style={{
                fontSize: '22px',
                fontWeight: 700,
                color: '#f1f5f9',
                lineHeight: 1.1,
              }}
            >
              {totalThreats.toLocaleString()}
            </div>
            <div
              style={{
                fontSize: '11px',
                color: '#64748b',
                marginTop: '2px',
              }}
            >
              total
            </div>
          </div>
        </div>
      </div>

      {/* Legend */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '8px 16px',
          marginTop: '16px',
          paddingTop: '16px',
          borderTop: '1px solid #1e293b',
        }}
      >
        {data.slice(0, 6).map((d) => {
          const color =
            threatTypeColors[d.threatType] || '#64748b';
          const label =
            threatTypeLabels[d.threatType] || d.threatType;

          return (
            <div
              key={d.threatType}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '12px',
                color: '#94a3b8',
              }}
            >
              <div
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: '2px',
                  backgroundColor: color,
                  flexShrink: 0,
                }}
              />
              <span
                style={{
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {label}
              </span>
              <span
                style={{
                  marginLeft: 'auto',
                  color: '#64748b',
                  fontSize: '11px',
                  flexShrink: 0,
                }}
              >
                {d.percentage.toFixed(0)}%
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default ThreatDistributionChart;
