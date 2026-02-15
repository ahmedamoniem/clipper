import SwiftUI

struct ClipboardRowView: View {
    let title: String
    let store: Store // Added store parameter
    
    var body: some View {
        // Your existing code... 
        // Fixing async imageData call with proper await handling
        // 1. Use async/await to fetch image data
        Task {
            do {
                let imageData = try await fetchData() // Adjusted for proper await
                // Handle imageData
            } catch {
                print("Error fetching image data: \(error)")
            }
        }
    }
}