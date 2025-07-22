import Foundation

struct GeminiService {
    struct GeminiRequest: Codable { let contents: [Content]; let generationConfig: GenerationConfig? }
    struct Content: Codable { let parts: [Part] }
    struct Part: Codable { let text: String }
    struct GenerationConfig: Codable { let responseMimeType: String }
    struct GeminiResponse: Codable {
        struct Candidate: Codable { let content: Content }
        let candidates: [Candidate]?
        let error: APIError?
    }
    struct AppSearchResponse: Codable { let apps: [String] }
    struct APIError: Codable, Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let apiKey = "YOUR_API_KEY"
    private let urlSession = URLSession.shared

    func findAppsWithAI(query: String, appNames: [String], retries: Int = 3, completion: @escaping (Result<[String], Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { completion(.failure(NSError(domain: "InvalidURL", code: 0))); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let prompt = """
        Você é uma API de busca inteligente. Sua tarefa é encontrar aplicativos em uma lista fornecida que correspondam à pesquisa do usuário.
        Pesquisa do usuário: "\(query)"
        Lista de aplicativos disponíveis: \(appNames.joined(separator: ", "))
        Responda APENAS com um objeto JSON no formato {"apps": ["AppName1", "AppName2", ...]} contendo os nomes dos aplicativos correspondentes da lista. Se nenhum aplicativo corresponder, retorne um array vazio.
        """
        let body = GeminiRequest(contents: [Content(parts: [Part(text: prompt)])], generationConfig: GenerationConfig(responseMimeType: "application/json"))
        do { request.httpBody = try JSONEncoder().encode(body) } catch { completion(.failure(error)); return }
        urlSession.dataTask(with: request) { data, response, error in
            let retryNeeded = error != nil || ((response as? HTTPURLResponse)?.statusCode ?? 200) >= 500
            if retryNeeded && retries > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                }
                return
            }
            DispatchQueue.main.async {
                if let error = error { completion(.failure(error)); return }
                guard let data = data else { completion(.failure(NSError(domain: "NoData", code: 0))); return }
                do {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    if let apiError = decoded.error { completion(.failure(apiError)); return }
                    if let text = decoded.candidates?.first?.content.parts.first?.text,
                       let jsonData = text.data(using: .utf8) {
                        let appResponse = try JSONDecoder().decode(AppSearchResponse.self, from: jsonData)
                        completion(.success(appResponse.apps))
                        return
                    }
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0)))
                } catch {
                    if retries > 0 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func sendChatMessage(message: String, retries: Int = 3, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { completion(.failure(NSError(domain: "InvalidURL", code: 0))); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let prompt = """
        Você é um assistente prestativo especializado em recomendar aplicativos para macOS.
        Sua conversa com o usuário é privada e não será salva.
        O usuário irá descrever uma necessidade. Sua tarefa é sugerir um ou mais aplicativos que atendam a essa necessidade.
        Para cada sugestão, forneça o nome do aplicativo em negrido (ex: **Nome do App**) e uma breve descrição do que ele faz.
        Se você não souber um aplicativo, diga que não conseguiu encontrar uma recomendação.

        Necessidade do usuário: "\(message)"

        Sugestões:
        """
        let body = GeminiRequest(contents: [Content(parts: [Part(text: prompt)])], generationConfig: nil)
        do { request.httpBody = try JSONEncoder().encode(body) } catch { completion(.failure(error)); return }
        urlSession.dataTask(with: request) { data, response, error in
            let retryNeeded = error != nil || ((response as? HTTPURLResponse)?.statusCode ?? 200) >= 500
            if retryNeeded && retries > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                }
                return
            }
            DispatchQueue.main.async {
                if let error = error { completion(.failure(error)); return }
                guard let data = data else { completion(.failure(NSError(domain: "NoData", code: 0))); return }
                do {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    if let apiError = decoded.error { completion(.failure(apiError)); return }
                    if let text = decoded.candidates?.first?.content.parts.first?.text {
                        completion(.success(text)); return
                    }
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0)))
                } catch {
                    if retries > 0 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
