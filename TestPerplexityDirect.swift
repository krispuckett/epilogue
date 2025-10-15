import Foundation

// DIRECT TEST - Run this to verify Perplexity API works
@MainActor
class DirectPerplexityTest {
    static func testDirectAPI() async {
        #if DEBUG
        print("🧪 Testing DIRECT Perplexity API call...")
        #endif
        
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
                #if DEBUG
                print("📊 Status Code: \(httpResponse.statusCode)")
                #endif
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #if DEBUG
                print("✅ Response JSON: \(json)")
                #endif
                
                if let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    #if DEBUG
                    print("🎯 Answer: \(content)")
                    #endif
                } else {
                    #if DEBUG
                    print("❌ Could not parse response")
                    #endif
                }
            } else {
                #if DEBUG
                print("❌ Invalid JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("❌ Request failed: \(error)")
            #endif
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