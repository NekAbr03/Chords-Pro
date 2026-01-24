import Flutter
import UIKit

class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return LiquidGlassView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
}

class LiquidGlassView: NSObject, FlutterPlatformView {
    private var _view: UIVisualEffectView

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger?
    ) {
        // ИСПОЛЬЗУЕМ .systemUltraThinMaterial ДЛЯ ПРЕМИУМ ЭФФЕКТА
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        _view = UIVisualEffectView(effect: blurEffect)
        _view.frame = frame
        _view.layer.cornerRadius = 20
        _view.clipsToBounds = true
        super.init()
    }

    func view() -> UIView {
        return _view
    }
}