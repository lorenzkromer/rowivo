import Foundation
import Observation
import RowivoCore
@preconcurrency import WatchConnectivity

/// WatchConnectivity delivers delegate callbacks off the main thread. UI/state work stays on MainActor.
@MainActor @Observable final class WatchTransport: NSObject, WCSessionDelegate {
    private(set) var isReachable = false
    private(set) var isPaired = false
    private(set) var isInstalled = false
    private(set) var isActivated = false
    private(set) var activationFailed = false
    @ObservationIgnored var onStatus: (() -> Void)?
    @ObservationIgnored var onSnapshot: ((Data) -> Void)?
    @ObservationIgnored var onRequest: ((Data) -> Data)?
    @ObservationIgnored private var session: WCSession?

    func activate() {
        guard WCSession.isSupported() else { return }
        session = .default; session?.delegate = self; session?.activate()
    }

    func publish(_ data: Data, background: Bool) {
        guard let session, isActivated, isInstalled else { return }
        if background { try? session.updateApplicationContext([WatchWire.contextKey: data]) }
        if session.isReachable { session.sendMessageData(data, replyHandler: nil, errorHandler: nil) }
    }

    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        guard let session, isActivated, session.isReachable else {
            completion(.failure(WatchTransportError.unreachable)); return
        }
        // Explicitly Sendable: WC invokes these closures on its own queue. Without this,
        // Swift 6 infers MainActor isolation from send() and traps before reaching Task.
        session.sendMessageData(data) { @Sendable reply in
            Task { @MainActor in completion(.success(reply)) }
        } errorHandler: { @Sendable error in
            Task { @MainActor in completion(.failure(error)) }
        }
    }

    private func refreshStatus() {
        guard let session else { return }
        isActivated = session.activationState == .activated
        isReachable = isActivated && session.isReachable
        #if os(iOS)
        isPaired = isActivated && session.isPaired
        isInstalled = isActivated && session.isWatchAppInstalled
        #else
        isPaired = isActivated
        isInstalled = isActivated && session.isCompanionAppInstalled
        #endif
        if isActivated, let data = session.receivedApplicationContext[WatchWire.contextKey] as? Data { onSnapshot?(data) }
        onStatus?()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let failed = error != nil
        Task { @MainActor in self.activationFailed = failed; self.refreshStatus() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshStatus() }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchWire.contextKey] as? Data else { return }
        Task { @MainActor in self.onSnapshot?(data) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in self.onSnapshot?(messageData) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        let reply = WatchReplyDelivery(deliver: replyHandler)
        Task { @MainActor in reply.deliver(self.onRequest?(messageData) ?? Data()) }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.refreshStatus() }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in self.refreshStatus(); self.session?.activate() }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshStatus() }
    }
    #endif
}

enum WatchTransportError: Error { case unreachable }
/// A framework reply closure is transferred once to MainActor and invoked exactly once there.
private struct WatchReplyDelivery: @unchecked Sendable { let deliver: (Data) -> Void }
