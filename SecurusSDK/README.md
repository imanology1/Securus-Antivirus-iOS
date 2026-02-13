# Securus iOS SDK

A modular, privacy-first mobile security SDK for iOS. Provides on-device AI anomaly detection, network traffic monitoring, and runtime integrity verification.

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 5.10+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/imanology1/Secaurus-Antivirus-iOS.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and paste the repository URL.

### Modules

| Module | Description |
|--------|-------------|
| `SecurusSDK` | Full SDK (includes all modules) |
| `SecurusCore` | Core engine, models, AI, storage |
| `SecurusNetwork` | Network anomaly detection |
| `SecurusRuntime` | Jailbreak, debugger, integrity checks |

## Quick Start

```swift
import SecurusCore

// In your App init or AppDelegate
SecurusAgent.shared.configure(apiKey: "your-api-key")
SecurusAgent.shared.start()
```

### Custom Configuration

```swift
var config = SecurusConfiguration(apiKey: "your-api-key")
config.enableNetworkMonitoring = true
config.enableRuntimeProtection = true
config.learningPeriodDuration = 86400  // 24 hours
config.logLevel = .info

SecurusAgent.shared.configure(configuration: config)
SecurusAgent.shared.start()
```

### Receiving Threat Callbacks

```swift
class MyDelegate: SecurusAgentDelegate {
    func securusAgent(_ agent: SecurusAgent, didDetectThreat event: ThreatEvent) {
        print("Threat: \(event.threat_type) — Severity: \(event.severity)")
    }
}

SecurusAgent.shared.delegate = MyDelegate()
```

## Architecture

```
SecurusCore
├── SecurusAgent          — Singleton entry point, fail-safe lifecycle
├── AnomalyDetectionEngine — Core ML model inference (Neural Engine optimized)
├── TokenGenerator         — Anonymous device token via SHA-256
├── SecureStorage          — iOS Keychain wrapper
└── PerformanceMonitor     — CPU/memory budget enforcement

SecurusNetwork
├── SecurusNetworkModule   — Learning phase → Protection phase
├── NetworkTrafficMonitor  — URLProtocol-based interception
├── BaselineManager        — Normal behavior profiling
├── AnomalyScorer          — Deviation scoring via ML engine
├── APIClient              — TLS 1.3 HTTPS reporting
└── ThreatReporter         — Batched, rate-limited event reporting

SecurusRuntime
├── SecurusRuntimeModule   — Periodic integrity checks
├── JailbreakDetector      — 6 redundant detection methods
├── DebuggerDetector       — sysctl, ptrace, timing analysis
├── IntegrityChecker       — Code signature & provisioning verification
└── MetricsCollector       — Runtime analytics aggregation
```

## Performance Budget

| Metric | Target |
|--------|--------|
| CPU Impact | < 1% average |
| Memory Footprint | < 15 MB |
| Network Latency Overhead | < 25ms per call |

## Privacy

- **Zero PII**: No personal data is ever collected
- **On-device AI**: Anomaly detection runs locally on the Neural Engine
- **Anonymized reporting**: All identifiers are SHA-256 hashed before transmission
- **Apple Privacy Manifest**: Ships with complete `PrivacyInfo.xcprivacy`

## Running Tests

```bash
swift test
```

## License

See [LICENSE](../LICENSE) for details.
