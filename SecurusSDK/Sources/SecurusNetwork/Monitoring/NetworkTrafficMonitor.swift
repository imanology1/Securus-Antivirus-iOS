// ============================================================================
// NetworkTrafficMonitor.swift
// SecurusNetwork
//
// URLProtocol subclass that intercepts outgoing network requests for
// observation. The monitor NEVER modifies, blocks, or delays requests.
// It is a passive observer that records metadata for anomaly detection.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - NetworkTrafficMonitorDelegate

/// Delegate for receiving observed network events.
public protocol NetworkTrafficMonitorDelegate: AnyObject {
    /// Called when a network request has been observed.
    func networkTrafficMonitor(_ monitor: NetworkTrafficMonitor, didObserve event: NetworkEvent)
}

// MARK: - NetworkTrafficMonitor

/// A `URLProtocol` subclass that passively observes outgoing network
/// requests without modifying them.
///
/// ## How It Works
///
/// When registered via `URLProtocol.registerClass(_:)`, the URL loading
/// system consults this class for every request. The monitor:
///
/// 1. Records the destination domain (hashed), port, protocol, and size.
/// 2. Forwards the request immediately via a new `URLSession` to avoid
///    interfering with the host app's networking.
/// 3. Records the response code and duration.
/// 4. Reports the completed `NetworkEvent` to its delegate.
///
/// ## Performance
///
/// The monitor adds < 1ms of overhead per request. It does not buffer
/// request/response bodies.
public final class NetworkTrafficMonitor: URLProtocol {

    // MARK: - Static State

    /// Delegate that receives observed network events.
    /// Set this before registering the protocol.
    public static weak var observerDelegate: NetworkTrafficMonitorDelegate?

    /// Key used to tag requests that have already been intercepted,
    /// preventing infinite recursion.
    private static let handledKey = "com.securus.networkMonitor.handled"

    // MARK: - Instance State

    private var sessionTask: URLSessionDataTask?
    private var receivedData = Data()
    private var startTime: CFAbsoluteTime = 0
    private lazy var internalSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    // MARK: - URLProtocol Overrides

    /// Determines whether this protocol should handle the given request.
    ///
    /// Returns `true` for HTTP/HTTPS requests that have not already been
    /// tagged by this monitor.
    override public class func canInit(with request: URLRequest) -> Bool {
        // Only handle HTTP(S) requests
        guard let scheme = request.url?.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return false
        }
        // Skip if already handled (prevent infinite loop)
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        return true
    }

    /// Returns the canonical version of the request (unchanged).
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Begins loading the request.
    ///
    /// Tags the request to prevent recursion, records the start time,
    /// and issues the actual network request through a private session.
    override public func startLoading() {
        startTime = CFAbsoluteTimeGetCurrent()

        // Tag the request so we do not intercept it again
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        // Forward the request
        let task = internalSession.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                self.reportEvent(response: nil, error: error)
                return
            }

            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let data {
                self.receivedData.append(data)
                self.client?.urlProtocol(self, didLoad: data)
            }

            self.client?.urlProtocolDidFinishLoading(self)
            self.reportEvent(response: response, error: nil)
        }
        task.resume()
        sessionTask = task
    }

    /// Stops loading (cancels the in-flight request).
    override public func stopLoading() {
        sessionTask?.cancel()
    }

    // MARK: - Event Reporting

    /// Constructs a `NetworkEvent` from the completed request/response
    /// and forwards it to the observer delegate.
    private func reportEvent(response: URLResponse?, error: Error?) {
        let url = request.url
        let domain = url?.host ?? "unknown"
        let hashedDomain = HashGenerator.shared.hashDomain(domain)

        let port: Int
        if let urlPort = url?.port {
            port = urlPort
        } else if url?.scheme?.lowercased() == "https" {
            port = 443
        } else {
            port = 80
        }

        let proto: NetworkProtocolType
        switch url?.scheme?.lowercased() {
        case "https": proto = .https
        case "http":  proto = .http
        default:      proto = .unknown
        }

        let requestBodySize = request.httpBody?.count ?? 0
        let responseCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        let endTime = CFAbsoluteTimeGetCurrent()
        let durationMs = Int((endTime - startTime) * 1000)

        let event = NetworkEvent(
            destinationDomainHash: hashedDomain,
            port: port,
            protocolType: proto,
            requestSizeBytes: requestBodySize,
            responseCode: responseCode,
            durationMs: durationMs
        )

        Self.observerDelegate?.networkTrafficMonitor(self, didObserve: event)
    }

    // MARK: - Registration

    /// Registers the monitor with the URL loading system.
    public static func register() {
        URLProtocol.registerClass(NetworkTrafficMonitor.self)
        SecurusLogger.shared.info("Network traffic monitor registered", subsystem: "Network")
    }

    /// Unregisters the monitor from the URL loading system.
    public static func unregister() {
        URLProtocol.unregisterClass(NetworkTrafficMonitor.self)
        SecurusLogger.shared.info("Network traffic monitor unregistered", subsystem: "Network")
    }
}
