import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  @objc func openClientSource(_ sender: Any?) {
    if let url = URL(string: "https://github.com/hoststend/stend-mobile") {
        NSWorkspace.shared.open(url)
    }
  }
  @objc func openServerSource(_ sender: Any?) {
    if let url = URL(string: "https://github.com/hoststend/stend-api") {
        NSWorkspace.shared.open(url)
    }
  }

  @objc func openClientDocs(_ sender: Any?) {
    if let url = URL(string: "https://stend.johanstick.fr/mobile-docs/intro/?ref=stendmenubar") {
        NSWorkspace.shared.open(url)
    }
  }
  @objc func openServerDocs(_ sender: Any?) {
    if let url = URL(string: "https://stend.johanstick.fr/api-docs/intro/?ref=stendmenubar") {
        NSWorkspace.shared.open(url)
    }
  }

  @objc func openDevPortfolio(_ sender: Any?) {
    if let url = URL(string: "https://johanstick.fr/?ref=stendmenubar") {
        NSWorkspace.shared.open(url)
    }
  }
  @objc func openDevDonation(_ sender: Any?) {
    if let url = URL(string: "https://johanstick.fr/donate?ref=stendmenubar") {
        NSWorkspace.shared.open(url)
    }
  }
}
