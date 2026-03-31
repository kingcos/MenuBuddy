import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: CompanionStore

    var body: some View {
        CompanionView(store: store)
            .background(Color(NSColor.windowBackgroundColor))
    }
}
