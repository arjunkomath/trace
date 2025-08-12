//
//  ToastView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void
    
    @State private var isShowing = false
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 20))
                .foregroundColor(type.iconColor)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 320)
        .offset(y: isShowing ? 0 : -100)
        .offset(dragOffset)
        .opacity(isShowing ? 1 : 0)
        .scaleEffect(isShowing ? 1 : 0.8)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isShowing)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dragOffset)
        .onAppear {
            withAnimation {
                isShowing = true
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if isShowing {
                    dismiss()
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        isDragging = true
                    }
                }
                .onEnded { value in
                    if value.translation.height < -20 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                    isDragging = false
                }
        )
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isShowing = false
            dragOffset = CGSize(width: 0, height: -100)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
