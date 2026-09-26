import SwiftUI

struct GameScreen: View {
    let game: GameKind
    let tier: Tier

    var body: some View {
        switch game {
        case .pairMatch: PairMatchScreen(tier: tier)
        case .sequenceEcho: SequenceEchoScreen(tier: tier)
        default: ContentUnavailableView("Coming soon", systemImage: game.symbol)
        }
    }
}
