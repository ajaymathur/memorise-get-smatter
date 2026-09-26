import SwiftUI

/// Three skippable screens (REQ-UX-01): what it is, honest science note, optional Game Center.
struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Skip", action: finish).padding()
            }
            TabView(selection: $page) {
                OnboardingPage(
                    symbol: "brain.head.profile", title: "Welcome to Get Smarter",
                    text:
                        "Four quick memory games based on classic psychology experiments, each with Beginner, Advanced and Expert levels."
                ).tag(0)
                OnboardingPage(
                    symbol: "books.vertical", title: "Honest science",
                    text:
                        "Each game is based on published research, and you'll find the sources inside. Practice makes you better at these tasks. Whether it helps everyday memory is still debated. This app is for fun and learning, not medical use."
                ).tag(1)
                OnboardingPage(
                    symbol: "trophy", title: "Play your way",
                    text:
                        "Everything works offline, with no account. If you use Game Center, you can choose to post scores to leaderboards later."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Button {
                if page < 2 { withAnimation { page += 1 } } else { finish() }
            } label: {
                Text(page < 2 ? "Next" : "Get started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .frame(maxWidth: 500)
        }
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(title).font(.system(.title, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                Text(text).multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }
}
