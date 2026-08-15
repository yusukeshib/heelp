import AppKit
import CryptoKit
import Foundation
import Network
import Security

@MainActor
enum OpenRouterOAuthClient {
    private static let authorizationEndpoint = URL(string: "https://openrouter.ai/auth")!
    private static let tokenEndpoint = URL(string: "https://openrouter.ai/api/v1/auth/keys")!

    static func signIn() async throws -> String {
        let verifier = try makeCodeVerifier()
        let challenge = makeCodeChallenge(for: verifier)
        let callbackServer = try LoopbackCallbackServer()

        let code = try await callbackServer.receiveCode { port in
            var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "callback_url", value: "http://localhost:\(port)/callback"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "key_label", value: "ppp")
            ]
            guard let url = components.url else { throw OAuthError.invalidAuthorizationURL }
            return url
        }

        return try await exchange(code: code, verifier: verifier)
    }

    private static func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw OAuthError.randomGenerationFailed }
        return base64URL(Data(bytes))
    }

    private static func makeCodeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func exchange(code: String, verifier: String) async throws -> String {
        struct ExchangeRequest: Encodable {
            let code: String
            let codeVerifier: String
            let codeChallengeMethod: String

            enum CodingKeys: String, CodingKey {
                case code
                case codeVerifier = "code_verifier"
                case codeChallengeMethod = "code_challenge_method"
            }
        }

        struct ExchangeResponse: Decodable {
            let key: String
        }

        struct ErrorResponse: Decodable {
            struct Detail: Decodable {
                let message: String?
            }

            let error: Detail?
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ExchangeRequest(
                code: code,
                codeVerifier: verifier,
                codeChallengeMethod: "S256"
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidTokenResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?
                .error?.message
            throw OAuthError.exchangeFailed(status: httpResponse.statusCode, message: message)
        }

        let tokenResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        let key = tokenResponse.key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw OAuthError.invalidTokenResponse }
        return key
    }
}

// All mutable state is confined to `queue`; Network callbacks use that same queue.
private final class LoopbackCallbackServer: @unchecked Sendable {
    private typealias CodeContinuation = CheckedContinuation<String, Error>

    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.yusukeshib.ppp.openrouter-oauth")
    private var continuation: CodeContinuation?
    private var didFinish = false
    private var didOpenBrowser = false

    init() throws {
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "localhost", port: .any)
            listener = try NWListener(using: parameters)
        } catch {
            throw OAuthError.callbackServerFailed(error.localizedDescription)
        }
    }

    func receiveCode(makeAuthorizationURL: @escaping (UInt16) throws -> URL) async throws -> String {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    guard !self.didFinish else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    self.continuation = continuation
                    self.listener.stateUpdateHandler = { [weak self] state in
                        self?.handleListenerState(state, makeAuthorizationURL: makeAuthorizationURL)
                    }
                    self.listener.newConnectionHandler = { [weak self] connection in
                        self?.handleConnection(connection)
                    }
                    self.listener.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 600) { [weak self] in
                        self?.finish(.failure(OAuthError.authorizationTimedOut))
                    }
                }
            }
        }, onCancel: {
            self.queue.async {
                self.finish(.failure(CancellationError()))
            }
        })
    }

    private func handleListenerState(
        _ state: NWListener.State,
        makeAuthorizationURL: @escaping (UInt16) throws -> URL
    ) {
        switch state {
        case .ready:
            guard !didOpenBrowser else { return }
            guard let port = listener.port else {
                finish(.failure(OAuthError.callbackServerFailed("No local port was assigned.")))
                return
            }

            do {
                let authorizationURL = try makeAuthorizationURL(port.rawValue)
                didOpenBrowser = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard NSWorkspace.shared.open(authorizationURL) else {
                        self.queue.async {
                            self.finish(.failure(OAuthError.couldNotOpenBrowser))
                        }
                        return
                    }
                }
            } catch {
                finish(.failure(error))
            }

        case let .failed(error):
            finish(.failure(OAuthError.callbackServerFailed(error.localizedDescription)))

        case .cancelled:
            break

        default:
            break
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) {
            [weak self] content, _, isComplete, error in
            guard let self else { return }

            if error != nil {
                connection.cancel()
                return
            }

            var requestData = accumulated
            if let content {
                requestData.append(content)
            }
            guard requestData.count <= 32_768 else {
                self.sendResponse(
                    on: connection,
                    status: "413 Payload Too Large",
                    body: "Invalid callback request."
                )
                return
            }

            let headerTerminator = Data("\r\n\r\n".utf8)
            if requestData.range(of: headerTerminator) != nil {
                self.processRequest(requestData, on: connection)
            } else if isComplete {
                self.sendResponse(
                    on: connection,
                    status: "400 Bad Request",
                    body: "Invalid callback request."
                )
            } else {
                self.receiveRequest(on: connection, accumulated: requestData)
            }
        }
    }

    private func processRequest(_ data: Data, on connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8),
              let requestLine = request.components(separatedBy: "\r\n").first
        else {
            sendResponse(on: connection, status: "400 Bad Request", body: "Invalid callback request.")
            return
        }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2,
              parts[0] == "GET",
              let components = URLComponents(string: "http://localhost\(parts[1])"),
              components.path == "/callback"
        else {
            sendResponse(on: connection, status: "404 Not Found", body: "Not found.")
            return
        }

        let queryItems = components.queryItems ?? []
        if let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            sendResponse(
                on: connection,
                status: "200 OK",
                body: "OpenRouter is connected. You can close this window.",
                result: .success(code)
            )
            return
        }

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value
            sendResponse(
                on: connection,
                status: "400 Bad Request",
                body: "OpenRouter authorization was not completed. You can close this window.",
                result: .failure(OAuthError.authorizationFailed(description ?? error))
            )
            return
        }

        sendResponse(on: connection, status: "400 Bad Request", body: "Invalid callback request.")
    }

    private func sendResponse(
        on connection: NWConnection,
        status: String,
        body: String,
        result: Result<String, Error>? = nil
    ) {
        let bodyData = Data(body.utf8)
        let headers = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: text/plain; charset=utf-8\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n"
            + "\r\n"
        var response = Data(headers.utf8)
        response.append(bodyData)

        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            if let result {
                self?.finish(result)
            }
        })
    }

    private func finish(_ result: Result<String, Error>) {
        guard !didFinish else { return }
        didFinish = true
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

private enum OAuthError: LocalizedError {
    case randomGenerationFailed
    case invalidAuthorizationURL
    case callbackServerFailed(String)
    case couldNotOpenBrowser
    case authorizationTimedOut
    case authorizationFailed(String)
    case invalidTokenResponse
    case exchangeFailed(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return "Could not create a secure OpenRouter sign-in request."
        case .invalidAuthorizationURL:
            return "Could not create the OpenRouter sign-in URL."
        case let .callbackServerFailed(message):
            return "Could not receive the OpenRouter callback: \(message)"
        case .couldNotOpenBrowser:
            return "Could not open the OpenRouter sign-in page."
        case .authorizationTimedOut:
            return "OpenRouter sign-in timed out."
        case let .authorizationFailed(message):
            return "OpenRouter authorization failed: \(message)"
        case .invalidTokenResponse:
            return "OpenRouter returned an invalid sign-in response."
        case let .exchangeFailed(status, message):
            if let message, !message.isEmpty {
                return "OpenRouter sign-in failed (HTTP \(status)): \(message)"
            }
            return "OpenRouter sign-in failed (HTTP \(status))."
        }
    }
}
