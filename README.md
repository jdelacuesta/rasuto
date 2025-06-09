# Rasuto - Product Price Tracking App

A comprehensive iOS application for tracking product prices across multiple retailers including Amazon, eBay, Walmart, and more.

## Features

- **Multi-Retailer Search**: Search products across Amazon, eBay, Walmart, Home Depot via SerpAPI
- **Price Tracking**: Track price changes and get notifications when prices drop
- **Wishlist Management**: Save and organize favorite products
- **Live Data**: Real-time product information with smart caching
- **Dark Mode Support**: Respects system preferences for light/dark mode
- **Universal Search**: Advanced search with instant results and suggestions

## Tech Stack

- **Swift & SwiftUI**: Native iOS development
- **APIs**: SerpAPI, eBay API, Axesso Amazon API
- **Storage**: Core Data with CloudKit sync
- **Architecture**: MVVM pattern with async/await

## Setup

1. Clone the repository
2. Add API keys via environment variables or update `SecretKeys.swift`
3. Build and run on iOS 16.0+

## API Keys Required

- SerpAPI key for multi-retailer search
- eBay Client ID and Secret for auction data
- Optional: Additional retailer APIs for enhanced coverage

## Demo Mode

The app includes rich demo data and will function without API keys for demonstration purposes.

---

Built for iOS Capstone Project