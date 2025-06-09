//
//  ItemCard.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct ProductCard: View {
    let product: ProductItemDTO
    
    var body: some View {
        VStack(alignment: .leading) {
            // Product Image
            ZStack(alignment: .topTrailing) {
                if let imageURL = product.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                    }
                    .frame(height: 150)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                // Source Tag (eBay, Walmart, Best Buy)
                Text(RetailerType.displayName(for: product.source))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(sourceBackgroundColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(8)
            }
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(product.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(formattedPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // In stock indicator
                    HStack(spacing: 3) {
                        Circle()
                            .fill(product.isInStock ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(product.isInStock ? "In Stock" : "Out of Stock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var sourceBackgroundColor: Color {
        switch RetailerType.displayName(for: product.source).lowercased() {
        case "ebay": return Color.blue
        case "best buy": return Color.yellow
        case "walmart": return Color.blue
        case "google shopping": return Color.green
        case "home depot": return Color.orange
        case "amazon": return Color.orange
        default: return Color.gray
        }
    }
    
    private var formattedPrice: String {
        if let price = product.price, let currency = product.currency {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            
            return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
        }
        return "N/A"
    }
}

#Preview {
    ProductCard(product: ProductItemDTO(
        sourceId: "sample-123",
        name: "Sample Product",
        productDescription: "A sample description",
        price: 99.99,
        currency: "USD",
        imageURL: URL(string: "https://example.com/image.jpg"),
        imageUrls: ["https://example.com/image.jpg"],
        thumbnailUrl: "https://example.com/thumbnail.jpg",
        brand: "Sample Brand",
        source: "eBay",
        category: "Electronics",
        isInStock: true,
        rating: 4.5,
        reviewCount: 123
    ))
}
