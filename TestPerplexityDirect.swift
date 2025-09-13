import Foundation

// DIRECT TEST - Run this to verify Perplexity API works
@MainActor
class DirectPerplexityTest {
    static func testDirectAPI() async {
        print("🧪 Testing DIRECT Perplexity API call...")
        
        let request = """
        {
            "model": "sonar",
            "messages": [
                {"role": "user", "content": "What is 2+2? Answer in 5 words or less."}
            ],
            "stream": false,
            "max_tokens": 50
        }
        """
        
        var urlRequest = URLRequest(url: URL(string: "https://epilogue-proxy.kris-puckett.workers.dev")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("epilogue_testflight_2025_secret", forHTTPHeaderField: "X-Epilogue-Auth")
        urlRequest.setValue("test-user", forHTTPHeaderField: "X-User-ID")
        urlRequest.httpBody = request.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status Code: \(httpResponse.statusCode)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Response JSON: \(json)")
                
                if let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("🎯 Answer: \(content)")
                } else {
                    print("❌ Could not parse response")
                }
            } else {
                print("❌ Invalid JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
            }
            
        } catch {
            print("❌ Request failed: \(error)")
        }
    }
    
    // Call this from anywhere to test
    static func runTest() {
        Task {
            await testDirectAPI()
        }
    }
}

// Add this temporary test button to your AmbientModeView:
/*
Button("TEST API") {
    DirectPerplexityTest.runTest()
}
.padding()
.background(Color.red)
.foregroundColor(.white)
.cornerRadius(8)
*/