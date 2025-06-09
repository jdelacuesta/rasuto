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
    
    enum Colors {
        static let background = Color(UIColor.systemBackground)
        static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
        static let accent = Color.blue
        static let error = Color.red
        static let primaryText = Color(UIColor.label)
        static let secondaryText = Color(UIColor.secondaryLabel)
    }
    
    enum Typography {
        static let titleFont = Font.title.bold()
        static let headlineFont = Font.headline
        static let bodyFont = Font.body
        static let captionFont = Font.caption
        static let subheadFont = Font.headline
    }
    
    enum Layout {
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largeCornerRadius: CGFloat = 12
        static let standardCornerRadius: CGFloat = 8
    }
}

//MARK: - Extensions

extension EdgeInsets {
    static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}
