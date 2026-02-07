import React, { useMemo, useRef } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import type { TimelineDataPoint } from '@/types';

/* ── Chart.js registration ── */
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
);

interface TimeSeriesChartProps {
  data: TimelineDataPoint[];
  timeRange: '24h' | '7d' | '30d';
}

function formatLabel(timestamp: string, range: '24h' | '7d' | '30d'): string {
  const d = new Date(timestamp);
  if (range === '24h') {
    return d.toLocaleTimeString('en-US', { hour: 'numeric', hour12: true });
  }
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

const TimeSeriesChart: React.FC<TimeSeriesChartProps> = ({ data, timeRange }) => {
  const chartRef = useRef<ChartJS<'line'>>(null);

  const chartData = useMemo(() => {
    const labels = data.map((d) => formatLabel(d.timestamp, timeRange));
    const values = data.map((d) => d.count);

    return {
      labels,
      datasets: [
        {
          label: 'Threats Detected',
          data: values,
          borderColor: '#3b82f6',
          backgroundColor: (context: { chart: ChartJS }) => {
            const chart = context.chart;
            const { ctx, chartArea } = chart;
            if (!chartArea) return 'rgba(59, 130, 246, 0.1)';
            const gradient = ctx.createLinearGradient(
              0,
              chartArea.top,
              0,
              chartArea.bottom,
            );
            gradient.addColorStop(0, 'rgba(59, 130, 246, 0.25)');
            gradient.addColorStop(0.5, 'rgba(59, 130, 246, 0.08)');
            gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');
            return gradient;
          },
          borderWidth: 2,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: '#3b82f6',
          pointHoverBorderColor: '#fff',
          pointHoverBorderWidth: 2,
          tension: 0.35,
          fill: true,
        },
      ],
    };
  }, [data, timeRange]);

  const options = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index' as const,
        intersect: false,
      },
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
          displayColors: false,
          callbacks: {
            title: (items: Array<{ label: string }>) =>
              items[0]?.label ?? '',
            label: (item: { parsed: { y: number } }) =>
              `${item.parsed.y} threats detected`,
          },
        },
      },
      scales: {
        x: {
          grid: {
            color: 'rgba(30, 41, 59, 0.5)',
            drawBorder: false,
          },
          ticks: {
            color: '#64748b',
            font: { size: 11 },
            maxTicksLimit: 12,
            maxRotation: 0,
          },
          border: {
            display: false,
          },
        },
        y: {
          grid: {
            color: 'rgba(30, 41, 59, 0.5)',
            drawBorder: false,
          },
          ticks: {
            color: '#64748b',
            font: { size: 11 },
            padding: 8,
          },
          border: {
            display: false,
          },
          beginAtZero: true,
        },
      },
    }),
    [],
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
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '16px',
        }}
      >
        <span
          style={{
            fontSize: '15px',
            fontWeight: 600,
            color: '#f1f5f9',
          }}
        >
          Threat Activity
        </span>
        <span
          style={{
            fontSize: '12px',
            color: '#64748b',
          }}
        >
          {timeRange === '24h'
            ? 'Last 24 hours'
            : timeRange === '7d'
              ? 'Last 7 days'
              : 'Last 30 days'}
        </span>
      </div>
      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
        <Line ref={chartRef} data={chartData} options={options} />
      </div>
    </div>
  );
};

export default TimeSeriesChart;
