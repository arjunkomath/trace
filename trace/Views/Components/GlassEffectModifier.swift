//
//  GlassEffectModifier.swift
//  trace
//
//  Created by Arjun on 8/17/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassEffect(
        interactive: Bool = true,
        isEnabled: Bool = true
    ) -> some View {
        let cornerRadius = self.adaptiveCornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape, isEnabled: isEnabled)
            } else {
                self.glassEffect(.regular, in: shape, isEnabled: isEnabled)
            }
        } else {
            self.background(
                shape
                    .fill(.regularMaterial)
            )
        }
    }
    
    var adaptiveCornerRadius: CGFloat {
        if #available(macOS 26.0, *) {
            return 26
        } else {
            return 16
        }
    }
    
    @ViewBuilder
    func liquidGlassContainer<Content: View>(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
    
    @ViewBuilder
    func liquidGlassID<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

struct LiquidGlassModifier: ViewModifier {
    let interactive: Bool
    let shape: AnyShape
    let isEnabled: Bool
    
    init<S: Shape>(interactive: Bool = true, in shape: S = RoundedRectangle(cornerRadius: 16), isEnabled: Bool = true) {
        self.interactive = interactive
        self.shape = AnyShape(shape)
        self.isEnabled = isEnabled
    }
    
    func body(content: Content) -> some View {
        content.liquidGlassEffect(
            interactive: interactive,
            isEnabled: isEnabled
        )
    }
}

extension View {
    func liquidGlass<S: Shape>(
        interactive: Bool = true,
        in shape: S = RoundedRectangle(cornerRadius: 16),
        isEnabled: Bool = true
    ) -> some View {
        modifier(LiquidGlassModifier(interactive: interactive, in: shape, isEnabled: isEnabled))
    }
}