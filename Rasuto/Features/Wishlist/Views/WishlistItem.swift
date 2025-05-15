//
//  WishlistItem.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct WishlistItem: View {
    var name: String
    var price: Double
    var imageURL: String?
    
    init(name: String = "Product Name", price: Double = 129.99, imageURL: String? = nil) {
        self.name = name
        self.price = price
        self.imageURL = imageURL
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Image placeholder or actual image
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
            
            Text(name)
                .font(.subheadline)
                .foregroundColor(.black)
                .lineLimit(2)
            
            Text("$\(String(format: "%.2f", price))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
    }
}

struct WishlistItem_Previews: PreviewProvider {
    static var previews: some View {
        WishlistItem()
    }
}
