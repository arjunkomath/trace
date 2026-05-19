//
//  GlassEffectModifier.swift
//  trace
//
//  Created by Arjun on 8/17/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassEffect(interactive: Bool = true) -> some View {
        let cornerRadius = self.adaptiveCornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if interactive {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
        }
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
    
    init(interactive: Bool = true) {
        self.interactive = interactive
    }
    
    func body(content: Content) -> some View {
        content.liquidGlassEffect(interactive: interactive)
    }
}

extension View {
    func liquidGlass(interactive: Bool = true) -> some View {
        modifier(LiquidGlassModifier(interactive: interactive))
    }
}
