import SwiftUI

struct CappedDynamicTypeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.dynamicTypeSize(.xSmall ... .xxxLarge)
    }
}

extension View {
    func cappedDynamicType() -> some View {
        modifier(CappedDynamicTypeModifier())
    }
}
