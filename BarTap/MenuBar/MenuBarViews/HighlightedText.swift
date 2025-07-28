//
//  HighlightedText.swift
//  BarTap
//

import SwiftUI

struct HighlightedText: View {
    let text: String
    let searchText: String
    let font: Font
    let foregroundColor: Color
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
        } else {
            Text(highlightedAttributedString)
                .font(font)
        }
    }
    
    private var highlightedAttributedString: AttributedString {
        var attributedString = AttributedString(text)
        
        // Find all ranges of the search text (case-insensitive)
        let ranges = text.ranges(of: searchText, options: .caseInsensitive)
        
        for range in ranges.reversed() { // Reverse to maintain correct indices
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let endIndex = text.distance(from: text.startIndex, to: range.upperBound)
            
            let attributedRange = Range(
                NSRange(location: startIndex, length: endIndex - startIndex),
                in: attributedString
            )
            
            if let attributedRange = attributedRange {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = foregroundColor
            }
        }
        
        // Set default color for non-highlighted text
        attributedString.foregroundColor = foregroundColor
        
        return attributedString
    }
}
