import SwiftUI

// Palette sombre de la marque PausePump — mêmes valeurs hex que le web
// (css/styles.css) et que l'app Flutter. Toute couleur de l'app watch
// doit passer par ici, jamais de Color littérale dans les vues.

/// Couleurs de la marque.
enum PPColor {
    /// Fond principal (#0F1219).
    static let bg = Color(red: 0x0F / 255, green: 0x12 / 255, blue: 0x19 / 255)
    /// Surface élevée (#171B26).
    static let bgElev = Color(red: 0x17 / 255, green: 0x1B / 255, blue: 0x26 / 255)
    /// Surface encore plus élevée (#1F2533).
    static let bgElev2 = Color(red: 0x1F / 255, green: 0x25 / 255, blue: 0x33 / 255)
    /// Accent teal — phase pause (#22D3A7).
    static let accent = Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xA7 / 255)
    /// Ambre — phase effort (#F59E0B).
    static let effort = Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
    /// Rouge danger — dernières secondes (#EF4444).
    static let danger = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    /// Texte principal (#E9F0F5).
    static let text = Color(red: 0xE9 / 255, green: 0xF0 / 255, blue: 0xF5 / 255)
    /// Texte secondaire (#93A0B0).
    static let textDim = Color(red: 0x93 / 255, green: 0xA0 / 255, blue: 0xB0 / 255)
    /// Piste de l'anneau de progression (#2A3142).
    static let track = Color(red: 0x2A / 255, green: 0x31 / 255, blue: 0x42 / 255)
}

/// Bouton d'action principal : pleine largeur, fond coloré, gros hit-target
/// (pensé pour être tapé sans regarder, en pleine série).
struct PPFilledButtonStyle: ButtonStyle {
    var color: Color = PPColor.accent
    var minHeight: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundColor(PPColor.bg)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: 14).fill(color))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
