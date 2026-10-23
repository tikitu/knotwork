import SwiftUI
import UI

/// The whole screen: the knot, under the app's title.
public struct RootView: View {
    let model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        NavigationStack {
            KnotView(model: model).padding(20).navigationTitle("Knotwork")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview { RootView(model: AppModel()) }
