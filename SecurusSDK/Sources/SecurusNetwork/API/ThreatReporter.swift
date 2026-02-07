// ============================================================================
// ThreatReporter.swift
// SecurusNetwork
//
// Batches threat events and reports them to the Securus backend.
// Events are queued in memory and flushed every 30 seconds or when
// the queue reaches 10 items, whichever comes first. Rate-limited
// to prevent flooding the backend during a sustained attack.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - ThreatReporter

/// Batches and reports `ThreatEvent`s to the Securus backend API.
///
/// ## Batching Strategy
///
/// Events are accumulated in an in-memory queue and flushed to the
/// backend in one of two conditions:
///
/// 1. The queue reaches the **batch threshold** (default: 10 events).
/// 2. The **flush interval** (default: 30 seconds) elapses.
///
/// ## Rate Limiting
///
/// To protect both the device and the backend from excessive reporting
/// during a sustained attack, the reporter enforces a minimum interval
/// of 5 seconds between consecutive flush operations.
///
/// ## Thread Safety
///
/// All queue mutations and flush operations are serialized on a
/// dedicated dispatch queue.
public final class ThreatReporter: @unchecked Sendable {

    // MARK: - Configuration

    /// Maximum number of events to accumulate before triggering a flush.
    public var batchThreshold: Int = 10

    /// Interval in seconds between automatic flush attempts.
    public var flushInterval: TimeInterval = 30.0

    /// Minimum interval between consecutive flushes (rate limiting).
    public var minimumFlushInterval: TimeInterval = 5.0

    /// Maximum number of events retained in the queue. Oldest events
    /// are discarded when this limit is exceeded to bound memory usage.
    public var maxQueueSize: Int = 200

    // MARK: - Properties

    private let apiClient: APIClient
    private var eventQueue: [ThreatEvent] = []
    private var flushTimer: DispatchSourceTimer?
    private var lastFlushTime: Date = .distantPast
    private var isFlushing = false
    private let queue = DispatchQueue(label: "com.securus.threatReporter")
    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a threat reporter backed by the given API client.
    ///
    /// - Parameter apiClient: The API client used for HTTP communication
    ///   with the Securus backend.
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        flushTimer?.cancel()
    }

    // MARK: - Enqueue

    /// Adds a threat event to the reporting queue.
    ///
    /// If the queue reaches the batch threshold after enqueuing, an
    /// immediate flush is triggered (subject to rate limiting).
    ///
    /// - Parameter event: The threat event to report.
    public func enqueue(_ event: ThreatEvent) {
        queue.async { [weak self] in
            guard let self else { return }

            // Enforce maximum queue size to bound memory
            if self.eventQueue.count >= self.maxQueueSize {
                let overflow = self.eventQueue.count - self.maxQueueSize + 1
                self.eventQueue.removeFirst(overflow)
                self.logger.warning(
                    "Threat reporter queue overflow — dropped \(overflow) oldest event(s)",
                    subsystem: "Reporter"
                )
            }

            self.eventQueue.append(event)
            self.logger.debug(
                "Enqueued threat event \(event.threat_id.prefix(8))... "
                + "(queue size: \(self.eventQueue.count))",
                subsystem: "Reporter"
            )

            // Flush if batch threshold is reached
            if self.eventQueue.count >= self.batchThreshold {
                self.performFlush()
            }
        }
    }

    /// Returns the number of events currently in the queue.
    public var pendingCount: Int {
        queue.sync { eventQueue.count }
    }

    // MARK: - Flush Timer

    /// Starts the periodic flush timer.
    ///
    /// Called automatically by `SecurusNetworkModule.startMonitoring()`.
    /// Idempotent.
    public func startFlushing() {
        queue.async { [weak self] in
            guard let self, self.flushTimer == nil else { return }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(
                deadline: .now() + self.flushInterval,
                repeating: self.flushInterval
            )
            timer.setEventHandler { [weak self] in
                self?.performFlush()
            }
            timer.resume()
            self.flushTimer = timer

            self.logger.info(
                "Threat reporter flush timer started (interval: \(self.flushInterval)s)",
                subsystem: "Reporter"
            )
        }
    }

    /// Stops the periodic flush timer.
    ///
    /// Does **not** flush remaining events. Call `flushNow()` first
    /// if you need to drain the queue before stopping.
    public func stopFlushing() {
        queue.async { [weak self] in
            guard let self else { return }
            self.flushTimer?.cancel()
            self.flushTimer = nil
            self.logger.info("Threat reporter flush timer stopped", subsystem: "Reporter")
        }
    }

    /// Synchronously triggers a flush of all queued events, ignoring
    /// the rate limiter. Intended for use during SDK shutdown.
    public func flushNow() {
        queue.sync {
            performFlush(ignoreRateLimit: true)
        }
    }

    // MARK: - Private: Flush Logic

    /// Drains the event queue and sends a batched report to the backend.
    ///
    /// - Parameter ignoreRateLimit: If `true`, bypasses the minimum flush
    ///   interval. Used during forced/shutdown flushes.
    ///
    /// Must be called on `queue`.
    private func performFlush(ignoreRateLimit: Bool = false) {
        guard !eventQueue.isEmpty else { return }
        guard !isFlushing else {
            logger.debug("Flush already in progress — skipping", subsystem: "Reporter")
            return
        }

        // Rate limiting check
        if !ignoreRateLimit {
            let elapsed = Date().timeIntervalSince(lastFlushTime)
            if elapsed < minimumFlushInterval {
                logger.debug(
                    "Rate limited — \(String(format: "%.1f", minimumFlushInterval - elapsed))s "
                    + "until next flush allowed",
                    subsystem: "Reporter"
                )
                return
            }
        }

        // Drain the queue
        let batch = eventQueue
        eventQueue.removeAll()
        isFlushing = true
        lastFlushTime = Date()

        logger.info("Flushing \(batch.count) threat event(s) to backend", subsystem: "Reporter")

        // Send asynchronously. On failure, re-enqueue the events.
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.apiClient.reportBatch(batch)
                self.queue.async {
                    self.isFlushing = false
                    self.logger.info(
                        "Successfully reported \(batch.count) event(s)",
                        subsystem: "Reporter"
                    )
                }
            } catch {
                self.queue.async {
                    self.isFlushing = false
                    // Re-enqueue failed events at the front of the queue
                    self.eventQueue.insert(contentsOf: batch, at: 0)
                    // Trim if we exceed max queue size
                    if self.eventQueue.count > self.maxQueueSize {
                        let excess = self.eventQueue.count - self.maxQueueSize
                        self.eventQueue.removeLast(excess)
                    }
                    self.logger.warning(
                        "Failed to report batch: \(error.localizedDescription). "
                        + "Re-enqueued \(batch.count) event(s) (queue: \(self.eventQueue.count))",
                        subsystem: "Reporter"
                    )
                }
            }
        }
    }
}
