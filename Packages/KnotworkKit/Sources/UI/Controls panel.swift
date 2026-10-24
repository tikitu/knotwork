import SwiftUI

/// The controls: what a drag does, clearing or filling the whole knot, which
/// tiles, and whether the knot's corners come to a point. Small, and shown
/// beside the knot rather than over it or on a screen of its own, so that
/// every change shows at once.
public struct ControlsPanel: View {
    @Bindable
    var model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        // Bound to the model's settings, whose setters perform commands
        // (`AppModel.tileStyleSetting`), and the buttons perform commands, so
        // that a script can do all this too.
        VStack(spacing: 12) {
            Picker("Drag", selection: $model.dragModeSetting) {
                ForEach(DragMode.allCases) { mode in Text(mode.name).tag(mode) }
            }.pickerStyle(.segmented)
            HStack {
                Button("Clear All", systemImage: "square.dashed") { model.attempt(.clearAll) }
                    .frame(maxWidth: .infinity)
                Button("Fill All", systemImage: "square.grid.2x2.fill") { model.attempt(.fillAll) }
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.bordered)
            Divider()
            Picker("Tiles", selection: $model.tileStyleSetting) {
                ForEach(TileStyle.allCases) { style in Text(style.name).tag(style) }
            }.pickerStyle(.segmented)
            Toggle("Pointed corners", isOn: $model.pointedCornersSetting).disabled(
                model.tileStyle == .original)
        }.padding().frame(maxWidth: 420).glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview { ControlsPanel(model: AppModel()).padding() }
