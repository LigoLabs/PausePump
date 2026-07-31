import SwiftUI
import WatchKit

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

/// Mesures adaptées au boîtier.
///
/// Les tailles sont écrites pour un 45 mm (198 pt de large) puis mises à
/// l'échelle : sans ça, un bouton confortable sur Ultra déborde sur un 40 mm,
/// et un bouton calibré pour le 40 mm paraît minuscule sur Ultra. Le facteur
/// est borné pour que l'écart reste discret.
enum PPMetrics {
    /// Largeur utile du boîtier, en points.
    static let width: CGFloat = WKInterfaceDevice.current().screenBounds.width

    /// Facteur d'échelle relatif au 45 mm, borné à ±14 %.
    static let scale: CGFloat = min(max(width / 198, 0.86), 1.14)

    /// Met une mesure de référence (45 mm) à l'échelle du boîtier courant.
    static func s(_ value: CGFloat) -> CGFloat { (value * scale).rounded() }

    /// Hauteur du bouton d'action principal.
    static var buttonHeight: CGFloat { s(34) }
    /// Hauteur d'un bouton secondaire / d'une tuile de durée.
    static var tileHeight: CGFloat { s(31) }

    /// Marge latérale commune à tous les écrans.
    ///
    /// C'est ELLE qui fixe la largeur des boutons : ils sont en
    /// `maxWidth: .infinity`, donc ils s'arrêtent à cette gouttière. Un seul
    /// réglage ici aligne boutons, pastilles de mode et tuiles de durée, et
    /// évite les boutons qui touchent les bords du boîtier.
    static var gutter: CGFloat { s(14) }
}

/// Bouton d'action principal : pleine largeur, fond coloré.
///
/// Volontairement compact — sur un boîtier de montre, un bouton trop haut
/// mange l'écran sans rien apporter : c'est la LARGEUR (pleine) qui fait le
/// hit-target, pas la hauteur.
struct PPFilledButtonStyle: ButtonStyle {
    var color: Color = PPColor.accent
    var minHeight: CGFloat = PPMetrics.buttonHeight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PPMetrics.s(14), weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundColor(PPColor.bg)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Petit bouton rond posé en surimpression dans un coin.
///
/// Utilisé pour le retour à l'accueil pendant une séance : en `overlay`, il
/// ne consomme aucune hauteur de mise en page — ce qui compte quand la zone
/// utile de la montre ne fait que ~157 pt.
struct PPCornerButton: View {
    let symbol: String
    var tint: Color = PPColor.textDim
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PPMetrics.s(11), weight: .bold))
                .foregroundColor(tint)
                .frame(width: PPMetrics.s(24), height: PPMetrics.s(24))
                .background(Circle().fill(PPColor.bgElev2.opacity(0.9)))
        }
        .buttonStyle(.plain)
        // Décollé du bord : la dalle est arrondie dans les angles, un bouton
        // posé à ras y paraît coincé et devient moins facile à viser.
        .padding(.leading, PPMetrics.s(8))
    }
}

extension View {
    /// Place un `PPCornerButton` en haut à gauche, AU-DESSUS de la zone sûre.
    ///
    /// watchOS réserve 53 pt en haut pour l'heure — mais celle-ci est calée à
    /// DROITE : le coin haut-gauche est libre. Rester sous cette marge posait
    /// le bouton trop bas, très loin du bord et collé au contenu. On remonte
    /// donc dedans, en s'arrêtant juste avant l'arrondi du boîtier.
    /// L'ORDRE COMPTE : le décalage doit être appliqué AVANT `ignoresSafeArea`.
    /// Placé après, il pousse tout le bloc déjà étendu vers le BAS au lieu de
    /// positionner le bouton depuis le haut de l'écran.
    func ppTopLeftCorner() -> some View {
        self
            .padding(.top, PPMetrics.s(26))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea(edges: .top)
    }
}

/// Bouton d'action circulaire et compact — le « GO » de l'accueil.
///
/// Un bouton pleine largeur y était disproportionné : l'accueil n'a qu'une
/// seule action, elle n'a pas besoin de barrer l'écran pour être trouvée.
/// Une pastille ronde centrée se vise aussi bien et rend l'écran plus calme.
struct PPGoButtonStyle: ButtonStyle {
    var color: Color = PPColor.accent
    var diameter: CGFloat = PPMetrics.s(56)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PPMetrics.s(19), weight: .heavy, design: .rounded))
            .foregroundColor(PPColor.bg)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(color))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Bouton secondaire : même gabarit, fond sourd, texte clair.
struct PPQuietButtonStyle: ButtonStyle {
    var minHeight: CGFloat = PPMetrics.tileHeight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PPMetrics.s(14), weight: .medium, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundColor(PPColor.text)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PPColor.bgElev2))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
