//
//  ToastView.swift
//  trace
//
//  Created by Claude on 8/8/2025.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    
    enum ToastType {
        case success
        case error
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(type.color)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .opacity(isShowing ? 1 : 0)
        .scaleEffect(isShowing ? 1 : 0.8)
        .animation(.spring(duration: 0.3), value: isShowing)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastView.ToastType
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    Spacer()
                    
                    if isShowing {
                        ToastView(message: message, type: type, isShowing: $isShowing)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
                .animation(.spring(duration: 0.3), value: isShowing)
            )
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, type: ToastView.ToastType = .info) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, type: type))
    }
}