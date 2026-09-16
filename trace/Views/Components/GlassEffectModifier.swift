//
//  GlassEffectModifier.swift
//  trace
//
//  Created by Arjun on 8/17/2025.
//

import SwiftUI

extension View {
    // Containers stay passive; only actionable controls should opt into click effects.
    func liquidGlassEffect(interactive: Bool = false, tint: Color? = nil) -> some View {
        let cornerRadius = self.adaptiveCornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
    }
    
    var adaptiveCornerRadius: CGFloat {
        26
    }
    
    @ViewBuilder
    func liquidGlassContainer<Content: View>(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
    
    @ViewBuilder
    func liquidGlassID<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID
    ) -> some View {
        self.glassEffectID(id, in: namespace)
    }
}

struct LiquidGlassModifier: ViewModifier {
    let interactive: Bool
    
    init(interactive: Bool = false) {
        self.interactive = interactive
    }
    
    func body(content: Content) -> some View {
        content.liquidGlassEffect(interactive: interactive)
    }
}

extension View {
    func liquidGlass(interactive: Bool = false) -> some View {
        modifier(LiquidGlassModifier(interactive: interactive))
    }
}
