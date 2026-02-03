import SwiftUI

struct Headers: View {
    let title: String
    let subtitle: String
    
    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
    
    init<T: IHeaderConfiguration>(_ configurationType: T.Type) {
        self.title = configurationType.title
        self.subtitle = configurationType.subtitle
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview("Custom") {
    Headers(title: "Custom Title", subtitle: "Custom Subtitle")
}

