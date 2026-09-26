import SwiftUI

struct GameScreen: View {
    let game: GameKind
    let tier: Tier

    var body: some View {
        switch game {
        case .pairMatch: PairMatchScreen(tier: tier)
        case .sequenceEcho: SequenceEchoScreen(tier: tier)
        case .nBack: NBackScreen(tier: tier)
        case .wordRecall: WordRecallScreen(tier: tier)
        }
    }
}
