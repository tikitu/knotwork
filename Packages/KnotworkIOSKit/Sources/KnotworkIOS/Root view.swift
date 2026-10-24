import SwiftUI
import UI

/// The whole screen: the knot, under the app's title, with the controls
/// below it when they are showing. The knot gets smaller to make
/// room for them, rather than being covered.
public struct RootView: View {
    let model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        NavigationStack {
            KnotView(model: model).padding(20).safeAreaInset(edge: .bottom) {
                if model.isShowingSettings {
                    ControlsPanel(model: model).padding(.horizontal).transition(
                        .move(edge: .bottom).combined(with: .opacity))
                }
            }.animation(.default, value: model.isShowingSettings).navigationTitle("Knotwork")
                .navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Controls", systemImage: "paintpalette", action: toggleSettings)
                            .symbolVariant(model.isShowingSettings ? .fill : .none)
                    }
                }
        }
    }

    private func toggleSettings() { model.attempt(.showSettings(!model.isShowingSettings)) }
}

#Preview { RootView(model: AppModel()) }
