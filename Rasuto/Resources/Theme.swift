//
//  Theme.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

enum Theme {
    static let primaryColor = Color("PrimaryColor")
    static let backgroundColor = Color(.systemBackground)
    static let secondaryBackgroundColor = Color(.secondarySystemBackground)
    static let textColor = Color(.label)
    static let secondaryTextColor = Color(.secondaryLabel)
    
    enum Typography {
        static let titleFont = Font.title.bold()
        static let headlineFont = Font.headline
        static let bodyFont = Font.body
        static let captionFont = Font.caption
    }
    
    enum Layout {
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largeCornerRadius: CGFloat = 12
        static let standardCornerRadius: CGFloat = 8
    }
}
