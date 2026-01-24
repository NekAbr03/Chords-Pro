import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // РЕГИСТРАЦИЯ ФАБРИКИ СТЕКЛА
    weak var registrar = self.registrar(forPlugin: "liquid-glass")
    let factory = LiquidGlassFactory(messenger: registrar!.messenger())
    self.registrar(forPlugin: "liquid-glass")!.register(factory, withId: "liquid-glass-view")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}