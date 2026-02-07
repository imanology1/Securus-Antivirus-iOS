import React, { useMemo } from 'react';
import type { ThreatEvent } from '@/types';
import { Severity } from '@/types';

interface ThreatMapProps {
  threats: ThreatEvent[];
}

/* ── Severity colors ── */
const severityColor: Record<Severity, string> = {
  [Severity.CRITICAL]: '#ef4444',
  [Severity.HIGH]: '#f97316',
  [Severity.MEDIUM]: '#eab308',
  [Severity.LOW]: '#3b82f6',
};

/* ── Geo to SVG coordinate conversion (equirectangular, viewBox 0 0 1000 500) ── */
function geoToSvg(lat: number, lng: number): { x: number; y: number } {
  return {
    x: (lng + 180) * (1000 / 360),
    y: (90 - lat) * (500 / 180),
  };
}

/* ── Simplified continent SVG paths (equirectangular projection, 1000x500 viewBox) ── */
const continentPaths: string[] = [
  /* North America */
  'M 89 58 L 62 67 L 42 75 L 33 83 L 55 86 L 80 86 L 100 81 L 119 81 L 131 86 ' +
  'L 150 83 L 161 92 L 167 100 L 158 111 L 156 125 L 161 133 L 158 147 L 175 153 ' +
  'L 183 164 L 194 172 L 206 186 L 219 192 L 228 200 L 242 206 L 253 211 L 261 222 ' +
  'L 269 225 L 275 219 L 269 208 L 258 197 L 253 189 L 264 183 L 272 175 L 278 172 ' +
  'L 281 181 L 278 186 L 283 178 L 289 164 L 292 153 L 294 142 L 297 133 L 300 125 ' +
  'L 306 128 L 314 122 L 325 119 L 336 119 L 347 117 L 353 114 L 344 106 L 339 97 ' +
  'L 333 92 L 322 89 L 308 86 L 294 83 L 281 83 L 267 81 L 264 86 L 258 86 L 258 81 ' +
  'L 242 78 L 231 75 L 222 75 L 214 72 L 200 69 L 189 64 L 175 61 L 161 58 L 147 56 ' +
  'L 131 53 L 114 53 L 100 56 Z',

  /* South America */
  'M 272 233 L 278 236 L 289 233 L 300 228 L 314 225 L 328 228 L 342 233 ' +
  'L 358 239 L 372 244 L 383 250 L 392 258 L 397 267 L 400 278 L 400 289 ' +
  'L 397 300 L 392 311 L 383 322 L 375 333 L 367 342 L 358 350 L 350 356 ' +
  'L 342 364 L 333 372 L 325 381 L 319 389 L 314 397 L 308 403 L 303 406 ' +
  'L 300 400 L 297 392 L 294 383 L 292 375 L 292 364 L 294 353 L 297 342 ' +
  'L 300 331 L 300 319 L 297 308 L 294 297 L 289 286 L 283 275 L 278 264 ' +
  'L 275 253 L 272 244 Z',

  /* Europe */
  'M 472 103 L 469 111 L 472 119 L 478 128 L 475 136 L 478 142 L 483 147 ' +
  'L 489 144 L 494 147 L 500 144 L 508 139 L 514 139 L 519 142 L 525 139 ' +
  'L 531 136 L 536 133 L 542 131 L 547 128 L 553 125 L 558 122 L 564 119 ' +
  'L 569 117 L 572 119 L 575 125 L 578 128 L 572 131 L 569 136 L 572 139 ' +
  'L 578 136 L 583 131 L 586 125 L 589 119 L 586 111 L 581 103 L 575 97 ' +
  'L 569 92 L 561 89 L 553 86 L 544 83 L 536 81 L 528 78 L 519 75 L 511 72 ' +
  'L 503 69 L 497 72 L 492 78 L 489 86 L 486 92 L 481 97 L 475 100 Z',

  /* Africa */
  'M 472 153 L 469 158 L 464 164 L 458 172 L 453 178 L 450 186 L 450 194 ' +
  'L 453 203 L 456 211 L 461 219 L 467 225 L 475 231 L 483 233 L 492 233 ' +
  'L 500 231 L 508 228 L 517 225 L 525 222 L 533 219 L 542 217 L 550 219 ' +
  'L 558 222 L 564 228 L 572 233 L 578 239 L 583 244 L 589 253 L 594 261 ' +
  'L 600 269 L 603 278 L 608 289 L 611 297 L 611 308 L 608 319 L 603 328 ' +
  'L 597 336 L 589 344 L 581 350 L 572 353 L 564 353 L 556 350 L 547 347 ' +
  'L 542 342 L 536 336 L 531 328 L 528 319 L 525 308 L 522 297 L 519 286 ' +
  'L 517 275 L 514 264 L 511 253 L 506 244 L 500 236 L 492 231 L 483 228 ' +
  'L 478 222 L 475 214 L 472 203 L 469 194 L 467 183 L 469 172 L 472 161 Z',

  /* Asia */
  'M 583 136 L 589 133 L 597 131 L 606 128 L 614 128 L 622 131 L 631 131 ' +
  'L 639 133 L 647 136 L 656 142 L 664 147 L 672 153 L 678 161 L 686 169 ' +
  'L 694 175 L 700 181 L 706 189 L 711 197 L 717 206 L 725 214 L 731 211 ' +
  'L 736 203 L 742 197 L 750 192 L 758 192 L 764 197 L 769 203 L 775 206 ' +
  'L 783 208 L 792 206 L 800 200 L 808 194 L 817 189 L 825 183 L 831 175 ' +
  'L 839 167 L 844 158 L 850 150 L 856 144 L 864 139 L 872 136 L 878 136 ' +
  'L 883 139 L 889 144 L 894 147 L 897 142 L 894 133 L 889 125 L 883 117 ' +
  'L 878 108 L 872 100 L 864 94 L 856 89 L 847 86 L 836 83 L 825 81 L 814 78 ' +
  'L 800 75 L 786 72 L 772 69 L 758 67 L 744 64 L 728 61 L 711 58 L 694 56 ' +
  'L 678 53 L 661 53 L 647 53 L 633 56 L 622 58 L 611 61 L 603 67 L 597 72 ' +
  'L 592 78 L 589 86 L 586 94 L 583 103 L 581 111 L 581 119 L 581 128 Z',

  /* Australia */
  'M 817 289 L 822 283 L 831 278 L 842 275 L 853 275 L 864 278 L 875 281 ' +
  'L 886 286 L 897 292 L 906 300 L 911 308 L 917 317 L 919 325 L 919 333 ' +
  'L 917 342 L 911 350 L 906 356 L 897 361 L 889 364 L 878 364 L 867 361 ' +
  'L 856 358 L 847 353 L 839 347 L 831 342 L 825 336 L 819 328 L 817 319 ' +
  'L 814 308 L 814 297 Z',

  /* Indonesia / Maritime Southeast Asia */
  'M 778 233 L 783 228 L 792 225 L 800 225 L 808 228 L 814 231 L 817 236 ' +
  'L 814 242 L 808 244 L 800 244 L 792 242 L 786 239 L 781 236 Z ' +
  'M 825 239 L 831 236 L 839 236 L 847 239 L 853 242 L 856 247 L 853 253 ' +
  'L 847 256 L 839 256 L 831 253 L 825 250 L 822 244 Z',

  /* Greenland */
  'M 306 36 L 300 42 L 297 50 L 300 58 L 306 64 L 314 67 L 322 69 L 331 69 ' +
  'L 339 67 L 347 64 L 353 58 L 356 50 L 353 42 L 347 36 L 339 33 L 331 31 ' +
  'L 322 31 L 314 33 Z',

  /* Japan */
  'M 875 131 L 878 136 L 881 142 L 883 150 L 886 156 L 889 161 L 892 156 ' +
  'L 892 147 L 889 139 L 886 133 L 881 128 Z',

  /* UK / Ireland */
  'M 478 92 L 481 86 L 486 83 L 492 83 L 497 86 L 497 92 L 494 97 L 489 100 ' +
  'L 483 100 L 478 97 Z ' +
  'M 469 89 L 472 86 L 475 89 L 475 94 L 472 97 L 469 94 Z',
];

/* ── Pre-positioned threat dot locations (major world cities) ── */
const defaultDotPositions: Array<{
  lat: number;
  lng: number;
  severity: Severity;
  delay: number;
}> = [
  { lat: 40.7, lng: -74, severity: Severity.HIGH, delay: 0 },
  { lat: 34, lng: -118, severity: Severity.MEDIUM, delay: 0.5 },
  { lat: 51.5, lng: -0.1, severity: Severity.CRITICAL, delay: 1.0 },
  { lat: 48.9, lng: 2.35, severity: Severity.LOW, delay: 1.5 },
  { lat: 55.8, lng: 37.6, severity: Severity.HIGH, delay: 0.3 },
  { lat: 35.7, lng: 139.7, severity: Severity.CRITICAL, delay: 0.8 },
  { lat: 39.9, lng: 116.4, severity: Severity.HIGH, delay: 1.2 },
  { lat: 19, lng: 73, severity: Severity.MEDIUM, delay: 0.6 },
  { lat: -23.6, lng: -46.6, severity: Severity.LOW, delay: 1.8 },
  { lat: 6.5, lng: 3.4, severity: Severity.HIGH, delay: 0.2 },
  { lat: 37.6, lng: 127, severity: Severity.MEDIUM, delay: 1.4 },
  { lat: -33.9, lng: 151.2, severity: Severity.LOW, delay: 0.9 },
];

const ThreatMap: React.FC<ThreatMapProps> = ({ threats }) => {
  /* Build dot positions from real threat data or fallback to defaults */
  const dots = useMemo(() => {
    if (threats.length > 0) {
      const threatDots = threats
        .filter((t) => t.latitude != null && t.longitude != null)
        .slice(0, 20)
        .map((t, i) => ({
          ...geoToSvg(t.latitude!, t.longitude!),
          color: severityColor[t.severity],
          delay: (i * 0.3) % 3,
          key: t.id,
        }));

      if (threatDots.length >= 6) return threatDots;
    }

    /* Fallback default dots */
    return defaultDotPositions.map((d, i) => {
      const pos = geoToSvg(d.lat, d.lng);
      return {
        ...pos,
        color: severityColor[d.severity],
        delay: d.delay,
        key: `default-${i}`,
      };
    });
  }, [threats]);

  return (
    <div
      style={{
        backgroundColor: '#0a0e17',
        borderRadius: '16px',
        border: '1px solid #1e293b',
        overflow: 'hidden',
        height: '100%',
        position: 'relative',
      }}
    >
      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '18px 20px',
          borderBottom: '1px solid #1e293b',
        }}
      >
        <span
          style={{
            fontSize: '15px',
            fontWeight: 600,
            color: '#f1f5f9',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <circle cx="12" cy="12" r="10" />
            <line x1="2" y1="12" x2="22" y2="12" />
            <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z" />
          </svg>
          Global Threat Map
        </span>
        <span
          style={{
            fontSize: '11px',
            color: '#64748b',
          }}
        >
          {dots.length} active threat{dots.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Map SVG */}
      <div style={{ padding: '8px 12px 16px' }}>
        <svg
          viewBox="0 0 1000 500"
          xmlns="http://www.w3.org/2000/svg"
          style={{
            width: '100%',
            height: 'auto',
            display: 'block',
          }}
        >
          <defs>
            {/* Pulse animation styles */}
            <style>{`
              @keyframes map-pulse-ring {
                0% { r: 3; opacity: 0.9; }
                70% { r: 14; opacity: 0; }
                100% { r: 14; opacity: 0; }
              }
              @keyframes map-pulse-ring-outer {
                0% { r: 3; opacity: 0.5; }
                70% { r: 22; opacity: 0; }
                100% { r: 22; opacity: 0; }
              }
              .threat-pulse-ring {
                animation: map-pulse-ring 2.5s ease-out infinite;
              }
              .threat-pulse-ring-outer {
                animation: map-pulse-ring-outer 2.5s ease-out infinite;
              }
              @keyframes map-dot-glow {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.7; }
              }
              .threat-dot-core {
                animation: map-dot-glow 2.5s ease-in-out infinite;
              }
            `}</style>

            {/* Subtle grid pattern */}
            <pattern id="map-grid" width="50" height="50" patternUnits="userSpaceOnUse">
              <path
                d="M 50 0 L 0 0 0 50"
                fill="none"
                stroke="#1e293b"
                strokeWidth="0.3"
                opacity="0.4"
              />
            </pattern>

            {/* Glow filter */}
            <filter id="dot-glow" x="-200%" y="-200%" width="500%" height="500%">
              <feGaussianBlur stdDeviation="3" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>

          {/* Ocean background */}
          <rect width="1000" height="500" fill="#0a0e17" />

          {/* Grid overlay */}
          <rect width="1000" height="500" fill="url(#map-grid)" />

          {/* Latitude lines */}
          {[83, 139, 194, 250, 306, 361, 417].map((y) => (
            <line
              key={`lat-${y}`}
              x1="0"
              y1={y}
              x2="1000"
              y2={y}
              stroke="#1e293b"
              strokeWidth="0.3"
              opacity="0.3"
              strokeDasharray="4 8"
            />
          ))}

          {/* Longitude lines */}
          {[139, 278, 417, 556, 694, 833].map((x) => (
            <line
              key={`lng-${x}`}
              x1={x}
              y1="0"
              x2={x}
              y2="500"
              stroke="#1e293b"
              strokeWidth="0.3"
              opacity="0.3"
              strokeDasharray="4 8"
            />
          ))}

          {/* Continents */}
          <g>
            {continentPaths.map((d, i) => (
              <path
                key={i}
                d={d}
                fill="#1e293b"
                stroke="#334155"
                strokeWidth="0.8"
                strokeLinejoin="round"
                opacity="0.85"
              />
            ))}
          </g>

          {/* Connection lines between nearby threats */}
          <g opacity="0.15">
            {dots.length > 1 &&
              dots.slice(0, -1).map((dot, i) => {
                const next = dots[(i + 1) % dots.length];
                const dist = Math.sqrt(
                  (dot.x - next.x) ** 2 + (dot.y - next.y) ** 2
                );
                if (dist > 300) return null;
                return (
                  <line
                    key={`conn-${i}`}
                    x1={dot.x}
                    y1={dot.y}
                    x2={next.x}
                    y2={next.y}
                    stroke={dot.color}
                    strokeWidth="0.5"
                    strokeDasharray="3 5"
                  />
                );
              })}
          </g>

          {/* Threat dots with pulse animation */}
          {dots.map((dot) => (
            <g key={dot.key} filter="url(#dot-glow)">
              {/* Outer pulse ring */}
              <circle
                cx={dot.x}
                cy={dot.y}
                r="3"
                fill="none"
                stroke={dot.color}
                strokeWidth="0.5"
                opacity="0"
                className="threat-pulse-ring-outer"
                style={{ animationDelay: `${dot.delay}s` }}
              />
              {/* Inner pulse ring */}
              <circle
                cx={dot.x}
                cy={dot.y}
                r="3"
                fill="none"
                stroke={dot.color}
                strokeWidth="1"
                opacity="0"
                className="threat-pulse-ring"
                style={{ animationDelay: `${dot.delay}s` }}
              />
              {/* Dot core */}
              <circle
                cx={dot.x}
                cy={dot.y}
                r="3"
                fill={dot.color}
                className="threat-dot-core"
                style={{ animationDelay: `${dot.delay}s` }}
              />
              {/* White highlight */}
              <circle
                cx={dot.x - 0.8}
                cy={dot.y - 0.8}
                r="1"
                fill="white"
                opacity="0.4"
              />
            </g>
          ))}
        </svg>
      </div>

      {/* Legend */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '20px',
          padding: '0 20px 16px',
        }}
      >
        {Object.entries(severityColor).map(([sev, color]) => (
          <div
            key={sev}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              fontSize: '11px',
              color: '#64748b',
            }}
          >
            <div
              style={{
                width: 6,
                height: 6,
                borderRadius: '50%',
                backgroundColor: color,
                boxShadow: `0 0 4px ${color}60`,
              }}
            />
            {sev.charAt(0).toUpperCase() + sev.slice(1)}
          </div>
        ))}
      </div>
    </div>
  );
};

export default ThreatMap;
