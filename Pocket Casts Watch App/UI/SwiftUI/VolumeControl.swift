import SwiftUI

struct VolumeControl: WKInterfaceObjectRepresentable {
    var tint: Color

    func makeWKInterfaceObject(context: Self.Context) -> WKInterfaceVolumeControl {
        let view = WKInterfaceVolumeControl(origin: .companion)
        view.focus()
        view.setTintColor(UIColor(tint))
        return view
    }

    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: WKInterfaceObjectRepresentableContext<VolumeControl>) {
        wkInterfaceObject.setTintColor(UIColor(tint))
    }
}
