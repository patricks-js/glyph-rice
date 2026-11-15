import QtQuick
import qs

// Números e palavras em destaque: Space Grotesk Bold.
Text {
    textFormat: Text.PlainText
    readonly property real lead: -0.175 * font.pixelSize
    font { family: Theme.dot; pixelSize: 44; weight: Font.Bold }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
