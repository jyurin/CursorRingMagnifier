import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var permissions: PermissionsModel

    init(model: AppModel) {
        self._settingsStore = ObservedObject(wrappedValue: model.settingsStore)
        self._permissions = ObservedObject(wrappedValue: model.permissions)
    }

    var body: some View {
        TabView {
            tabContainer {
                appearanceTab
            }
            .tabItem { Text("見た目") }

            tabContainer {
                magnifierTab
            }
            .tabItem { Text("拡大鏡") }

            tabContainer {
                behaviorTab
            }
            .tabItem { Text("操作") }

            tabContainer {
                aboutTab
            }
            .tabItem { Text("制作") }
        }
        .padding(18)
        .frame(width: 760, height: 680)
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "リング表示") {
                Toggle("マウスリングを表示", isOn: binding(\.highlightEnabled))

                Picker("リングサイズ", selection: binding(\.ringSize)) {
                    ForEach(RingSizePreset.allCases) { preset in
                        Text(ringSizeLabel(preset)).tag(preset)
                    }
                }

                if settingsStore.settings.ringSize == .custom {
                    sliderRow(
                        title: "カスタムサイズ",
                        value: binding(\.ringCustomSize),
                        range: 24...220,
                        valueText: "\(Int(settingsStore.settings.ringCustomSize))px"
                    )
                }

                Picker("線の太さ", selection: binding(\.borderWeight)) {
                    ForEach(BorderWeightPreset.allCases) { preset in
                        Text(borderWeightLabel(preset)).tag(preset)
                    }
                }

                if settingsStore.settings.borderWeight == .custom {
                    sliderRow(
                        title: "カスタム太さ",
                        value: binding(\.borderCustomWidth),
                        range: 1...20,
                        valueText: String(format: "%.1fpx", settingsStore.settings.borderCustomWidth)
                    )
                }

                sliderRow(
                    title: "線の透明度",
                    value: binding(\.ringOpacity),
                    range: 0.1...1.0,
                    valueText: percent(settingsStore.settings.ringOpacity)
                )
            }

            sectionCard(title: "色") {
                ColorPaletteRow(title: "リング色", selected: binding(\.ringColor))
                Toggle("内側を塗りつぶす", isOn: binding(\.fillEnabled))

                if settingsStore.settings.fillEnabled {
                    sliderRow(
                        title: "塗りの透明度",
                        value: binding(\.fillOpacity),
                        range: 0.05...1.0,
                        valueText: percent(settingsStore.settings.fillOpacity)
                    )
                    ColorPaletteRow(title: "塗り色", selected: binding(\.fillColor))
                }
            }
        }
    }

    private var magnifierTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "拡大鏡の表示") {
                Picker("拡大率", selection: binding(\.magnifierScale)) {
                    ForEach(MagnifierScalePreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }

                Picker("レンズサイズ", selection: binding(\.magnifierSize)) {
                    ForEach(MagnifierSizePreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }

                Picker("レンズ形状", selection: binding(\.magnifierShape)) {
                    ForEach(MagnifierShapePreset.allCases) { preset in
                        Text(magnifierShapeLabel(preset)).tag(preset)
                    }
                }
            }

            sectionCard(title: "ショートカット") {
                HStack {
                    Text("現在の設定")
                    Spacer()
                    Text("\(modifierLabel(settingsStore.settings.magnifierHoldModifier)) を押している間")
                        .foregroundStyle(.secondary)
                }

                Picker("押し続けキー", selection: binding(\.magnifierHoldModifier)) {
                    ForEach(ModifierKeyPreset.allCases) { preset in
                        Text(modifierLabel(preset)).tag(preset)
                    }
                }
            }

            sectionCard(title: "権限") {
                permissionRow(
                    title: "画面収録",
                    granted: permissions.screenRecordingGranted,
                    action: permissions.requestScreenRecording
                )
                Text("未許可の場合は拡大鏡のみ無効になります。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var behaviorTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "クリックフィードバック") {
                Toggle("クリック時の視覚フィードバック", isOn: binding(\.clickFeedbackEnabled))

                sliderRow(
                    title: "クリック時の縮小率",
                    value: binding(\.clickShrinkAmount),
                    range: 0.7...0.95,
                    valueText: percent(settingsStore.settings.clickShrinkAmount)
                )

                sliderRow(
                    title: "演出時間",
                    value: binding(\.clickDuration),
                    range: 0.08...0.25,
                    valueText: milliseconds(settingsStore.settings.clickDuration)
                )

                ColorPaletteRow(title: "1本指クリック色", selected: binding(\.normalClickColor))
                ColorPaletteRow(title: "2本指クリック色", selected: binding(\.secondaryClickColor))
            }

            sectionCard(title: "ショートカット") {
                HStack {
                    Text("リング表示切り替え")
                    Spacer()
                    Text("\(modifierLabel(settingsStore.settings.toggleShortcutModifier)) + \(settingsStore.settings.toggleShortcutKey.label)")
                        .foregroundStyle(.secondary)
                }

                Picker("修飾キー", selection: binding(\.toggleShortcutModifier)) {
                    ForEach(ModifierKeyPreset.allCases) { preset in
                        Text(modifierLabel(preset)).tag(preset)
                    }
                }

                Picker("文字キー", selection: binding(\.toggleShortcutKey)) {
                    ForEach(LetterKeyPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
            }

            sectionCard(title: "起動と権限") {
                Toggle("ログイン時に自動起動", isOn: binding(\.startAtLogin))

                permissionRow(
                    title: "アクセシビリティ",
                    granted: permissions.accessibilityGranted,
                    action: permissions.requestAccessibility
                )

                Text("未許可の場合、クリックフィードバックとショートカットが使えません。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !permissions.accessibilityGranted {
                    Text("初回のみ設定が必要です: 「許可を開く」を押し、システム設定 > プライバシーとセキュリティ > アクセシビリティでこのアプリをONにしてください。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "このアプリについて") {
                HStack(alignment: .top, spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cursor Ring & Magnifier")
                            .font(.title3.weight(.semibold))
                        Text("画面共有や操作説明のためのカーソル強調ツール")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            sectionCard(title: "制作") {
                labeledValueRow(label: "ブランド", value: "ミリョク・ラボ")
                labeledValueRow(label: "制作者", value: "Yoshimoto Jyurin")
                labeledValueRow(label: "更新日", value: "2026/02/14")
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        } label: {
            Text(title)
                .font(.headline)
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range)
            Text(valueText)
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
            Spacer()
        }
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(granted ? "許可済み" : "未許可")
                .foregroundStyle(granted ? .green : .red)
            if !granted {
                Button("許可を開く") {
                    action()
                }
            }
        }
    }

    private func tabContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { settingsStore.settings[keyPath: keyPath] = $0 }
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func milliseconds(_ value: Double) -> String {
        "\(Int(value * 1000))ms"
    }

    private func modifierLabel(_ modifier: ModifierKeyPreset) -> String {
        switch modifier {
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        case .shift: return "Shift"
        }
    }

    private func ringSizeLabel(_ size: RingSizePreset) -> String {
        switch size {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .custom: return "カスタム"
        }
    }

    private func borderWeightLabel(_ weight: BorderWeightPreset) -> String {
        switch weight {
        case .thin: return "細い"
        case .regular: return "標準"
        case .bold: return "太い"
        case .custom: return "カスタム"
        }
    }

    private func magnifierShapeLabel(_ shape: MagnifierShapePreset) -> String {
        switch shape {
        case .circle: return "円形"
        case .wideRectangle: return "長方形（横長）"
        }
    }
}

private struct ColorPaletteRow: View {
    let title: String
    @Binding var selected: RGBAColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            HStack(alignment: .top, spacing: 10) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(22), spacing: 8), count: 8),
                    spacing: 8
                ) {
                    ForEach(Array(RGBAColor.presets.enumerated()), id: \.offset) { _, color in
                        ColorChip(color: color, isSelected: color == selected) {
                            selected = color
                        }
                    }
                }
                AppKitColorWell(selected: $selected)
                    .frame(width: 36, height: 24)
            }
        }
    }
}

private struct ColorChip: View {
    let color: RGBAColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color.nsColor))
                .frame(width: 20, height: 20)
                .overlay {
                    Circle().stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct AppKitColorWell: NSViewRepresentable {
    @Binding var selected: RGBAColor

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.color = selected.nsColor
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = selected.nsColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selected: $selected)
    }

    final class Coordinator: NSObject {
        @Binding var selected: RGBAColor

        init(selected: Binding<RGBAColor>) {
            self._selected = selected
        }

        @MainActor
        @objc
        func changed(_ sender: NSColorWell) {
            selected = RGBAColor(nsColor: sender.color)
        }
    }
}
