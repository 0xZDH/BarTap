//
//  String+Extensions.swift
//  BarTap
//

import SwiftUI

extension String {
    /// Convert a four-character string into the `OSType` format required by Carbon
    var fourCharCode: FourCharCode {
        return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
    
    /// String extension of range()
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = startIndex..<endIndex
        
        while let range = range(of: searchString, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<endIndex
        }
        
        return ranges
    }
}
