//
//  MathEvaluator.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

struct MathEvaluator {
    
    private enum Constants {
        static let maxExpressionLength = 100
        static let mathPattern = #"^[\d+\-*/^().\s]+$"#
    }
    
    static func isMathExpression(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty,
              trimmed.count <= Constants.maxExpressionLength,
              trimmed.rangeOfCharacter(from: .letters) == nil else {
            return false
        }
        
        let hasOperator = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/^")) != nil
        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let matchesPattern = trimmed.range(of: Constants.mathPattern, options: .regularExpression) != nil
        
        return hasOperator && hasDigit && matchesPattern
    }
    
    static func evaluate(_ expression: String) async -> String? {
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
        
        guard isMathExpression(cleanExpression) else {
            return nil
        }
        
        let script = """
        try
            set result to (\(cleanExpression)) as string
            return result
        on error
            return "Error"
        end try
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let output = appleScript?.executeAndReturnError(&error),
                      error == nil,
                      let result = output.stringValue,
                      result != "Error" else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: formatResult(result))
            }
        }
    }
    
    private static func formatResult(_ result: String) -> String {
        if let number = Double(result) {
            if number.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", number)
            } else {
                let formatted = String(format: "%.10f", number).trimmingCharacters(in: CharacterSet(charactersIn: "0"))
                return formatted.hasSuffix(".") ? String(formatted.dropLast()) : formatted
            }
        }
        return result
    }
}