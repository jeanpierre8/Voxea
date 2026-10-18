import AppKit
import WebKit

final class Fixture: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 470), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Voxea — essai local d’insertion"
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        let editItem = NSMenuItem(); main.addItem(editItem); let edit = NSMenu(title: "Édition"); editItem.submenu = edit
        edit.addItem(withTitle: "Tout sélectionner", action: Selector(("selectAll:")), keyEquivalent: "a")
        edit.addItem(withTitle: "Copier", action: Selector(("copy:")), keyEquivalent: "c")
        edit.addItem(withTitle: "Coller", action: Selector(("paste:")), keyEquivalent: "v")
        NSApp.mainMenu = main
        let web = WKWebView(frame: window.contentView!.bounds)
        web.autoresizingMask = [.width, .height]; window.contentView!.addSubview(web)
        web.loadHTMLString("""
        <!doctype html><html lang="fr"><meta charset="utf-8"><style>
        body{font:17px -apple-system;padding:24px;background:#f5f6fa} [contenteditable],input{display:block;padding:12px;border:2px solid #3478aa;background:white;margin:15px 0;min-height:36px;width:94%} button{padding:8px} #result{white-space:pre-wrap}
        </style><h2>Champ web local de test</h2>
        <div id="editor" contenteditable="true" role="textbox" aria-label="Champ web de test">Avant : </div>
        <input aria-label="Autre champ" placeholder="Autre champ" />
        <input type="password" aria-label="Champ protégé" placeholder="Champ protégé" />
        <p id="result" aria-live="polite">Événements de saisie : 0</p>
        <script>let count=0; document.getElementById('editor').addEventListener('input',()=>{document.getElementById('result').textContent='Événements de saisie : '+(++count)+' · Texte : '+document.getElementById('editor').textContent;});</script>
        </html>
        """, baseURL: nil)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = Fixture(); application.delegate = delegate
application.run()
