import Foundation

struct APIError: LocalizedError {
    let status: Int
    let code: String?
    let message: String?
    var retryAfterMs: Double? = nil

    var errorDescription: String? {
        if let message, !message.isEmpty { return message }
        switch status {
        case 0: return "No connection. Check your internet and try again."
        case 401: return "Your session has expired. Sign in again."
        case 429: return "Too many requests — wait a minute and try again."
        default: return code ?? "Something went wrong (\(status))."
        }
    }
}

/// Talks to https://api.nxor.ai/v1. Auth is cookie-based (`access_token` 15 min, `refresh_token` 30 days);
/// a 401 triggers one `/auth/refresh` and a retry.
final class APIClient {
    static let shared = APIClient()

    let base = URL(string: "https://api.nxor.ai/v1")!
    let session: URLSession
    let decoder = JSONDecoder()
    private var refreshTask: Task<Bool, Never>?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    var hasSessionCookie: Bool {
        HTTPCookieStorage.shared.cookies(for: base)?.contains { $0.name == "access_token" || $0.name == "refresh_token" } ?? false
    }

    func makeRequest(_ path: String, method: String = "GET", query: [String: String] = [:], body: (any Encodable)? = nil) throws -> URLRequest {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    func data(for request: URLRequest, retryOnAuth: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw APIError(status: 0, code: "network", message: nil)
        }
        let (data, response) = result
        let http = response as? HTTPURLResponse ?? HTTPURLResponse()
        if http.statusCode == 401, retryOnAuth, await refresh() {
            return try await self.data(for: request, retryOnAuth: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(from: data, status: http.statusCode)
        }
        return (data, http)
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await data(for: makeRequest(path, query: query))
        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: (any Encodable)? = nil, as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await data(for: makeRequest(path, method: "POST", body: body))
        return try decoder.decode(T.self, from: data)
    }

    func postVoid(_ path: String, body: (any Encodable)? = nil) async throws {
        _ = try await data(for: makeRequest(path, method: "POST", body: body))
    }

    func refresh() async -> Bool {
        if let task = refreshTask { return await task.value }
        let task = Task<Bool, Never> {
            guard let request = try? self.makeRequest("auth/refresh", method: "POST"),
                  let result = try? await self.session.data(for: request),
                  let http = result.1 as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        }
        refreshTask = task
        let ok = await task.value
        refreshTask = nil
        return ok
    }

    static func error(from data: Data, status: Int) -> APIError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let inner = json?["error"] as? [String: Any] ?? json
        return APIError(
            status: status,
            code: inner?["code"] as? String,
            message: inner?["message"] as? String,
            retryAfterMs: inner?["retryAfterMs"] as? Double ?? json?["retryAfterMs"] as? Double
        )
    }
}

struct EmptyResponse: Decodable {}
