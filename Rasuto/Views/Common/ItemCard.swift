//
//  ItemCard.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct ItemCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .frame(height: 100)
            .overlay(
                Text("Item")
                    .foregroundColor(.primary)
            )
            .padding(.horizontal)
    }
}

#Preview {
    ItemCard()
}
