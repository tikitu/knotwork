import SwiftUI

/// The appearance settings: which tiles, and whether the knot's corners come
/// to a point. Small, and shown beside the knot rather than over it or on a
/// screen of its own, so that every change shows at once.
public struct AppearanceSettings: View {
    @Bindable
    var model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        // Bound to the model's settings, whose setters perform commands
        // (`AppModel.tileStyleSetting`), so that a script can do all this too.
        VStack(spacing: 12) {
            Picker("Tiles", selection: $model.tileStyleSetting) {
                ForEach(TileStyle.allCases) { style in Text(style.name).tag(style) }
            }.pickerStyle(.segmented)
            Toggle("Pointed corners", isOn: $model.pointedCornersSetting).disabled(
                model.tileStyle == .original)
        }.padding().frame(maxWidth: 420).glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview { AppearanceSettings(model: AppModel()).padding() }
