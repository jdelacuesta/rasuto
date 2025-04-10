# Rasuto
Rasuto is an iOS app that helps shoppers track product availability in online stores and notifies them when items are low in stock or about to sell out. Using web scraping and retailer APIs, it monitors inventory levels in real-time, ensuring users never miss must-have products. Built with SwiftUI for a seamless experience.


# App Ethos:

  **“Rasuto”** is derived from the Japanese phonetic spelling of the English word “Last” (ラスト). In Japanese pop culture and retail, **“Rasuto”** often refers to the **last available item**, the **final chance**, or the **ultimate edition** — creating urgency, significance, and emotional value.

It evokes a mindset of:

- **Exclusivity** — “The last one. Just for you.”
- **Timeliness** — “Now or never.”
- **Mindful collecting** — “Cherish what matters before it disappears.”

Rasuto isn’t just about counting stock. It’s about helping **collectors, enthusiasts, and deal hunters** capture fleeting opportunities before they vanish — whether that’s the final size 10 in a grail sneaker drop or a rare colorway of tech gear.


# Project Overview

In today’s fast-moving e-commerce landscape, popular products often sell out quickly — Rasuto gives shoppers an edge. With a focus on reliability and simplicity, the app allows users to build personalized watchlists, filter by categories, and receive timely, actionable alerts. Whether you’re waiting for a restock or tracking limited releases, Rasuto empowers smarter, faster purchasing decisions.


# Key Features

- 🛍️ **Product Tracking** – Add product links from supported retailers to monitor availability.
- 📦 **Stock Monitoring** – Automatically checks inventory levels in real-time or at intervals.
- 🚨 **Low Stock Alerts** – Get notified when an item is about to sell out (customizable thresholds).
- ❤️ **Wishlist & Favorites** – Save and organize products for ongoing tracking.
- 🔍 **Search & Filtering** – Find tracked products easily by category, retailer, or stock status.
- 📊 **Historical Stock Data** – (Optional) View past inventory changes to spot trends.
- 🔌 **Retailer API Support** – Integrates with major online stores for reliable data.
- 🧠 **SwiftUI-Powered UI** – Clean, native interface built for a seamless iOS experience.


# Target Audience

- Budget-conscious shoppers
- Consumers planning major purchases
- Tech enthusiasts who want to track market prices for electronics
- Gift buyers who want ot maximize their budget
- Deal hunters
- Fashion/Sneaker enthusiasts
- Toy & art collectors

# Technology Stack

- **Language:** Swift, SwiftUI
    
- **Data Persistence:** SwiftData or UserDefaults for storing user preferences and tracked items
    
- **Networking:** URLSession for fetching stock data from retailer APIs
    
- **Concurrency:** Async/Await for handling stock checks in the background
    
- **Notifications:** Local notifications & push notifications for stock alerts
    
- **API Integration:** Attempt integration with known retailer APIs (Amazon, Best Buy, Walmart)
    
- **Web Scraping (if APIs unavailable):** Use SwiftSoup or a server-side function to extract stock data
    

# Required Capstone Deliverables

✅ **Splash Screen & Custom App Icon** – Branding with a sleek, modern UI

✅ **Data Persistence** – Save tracked products locally

✅ **Proper Layout & Navigation** – Well-structured UI using SwiftUI

✅ **Concurrency** – Background stock checks using async/await

✅ **URLSession API Calls** – Fetch stock data from online sources

✅ **Error Handling** – Graceful handling of network failures

# Challenges & Considerations

- Some retailers may **not provide stock APIs** (might require web scraping).
    
- Frequent stock checks could trigger rate limits—must **optimize API calls**.
    
- **Data accuracy** is crucial—if stock counts are unreliable, notifications might misfire.
    
- If scraping is needed, an **intermediate server** might be required.

- Possible Vapor Integration:
  - Create a backend service for web scraping retailers that don't offer APIs
  - Store historical stock data off-device
  - Manage rate limiting for API calls
  - Handle push notifications more efficiently
  - Create a shared database if you later want to expand to multiple platforms
 
# Xcode Project Structure

<pre lang="markdown">
## 📁 Project Structure

```
Rasuto/
├── App/                    # App entry point
├── Views/                  # SwiftUI views
│   ├── Products/           # Product listing and detail views
│   ├── Tracking/           # Tracking management views
│   ├── Notifications/      # Notification settings
│   └── Settings/           # App settings
├── Models/                 # Data models
├── Services/               # API and web scraping services
├── Utilities/              # Helper functions
├── Resources/              # Images, colors, and other resources
└── Config/                 # Configuration files (excluding API keys)
```
</pre>


# 📁 Figma Setup for Rasuto UI

| Feature                     | Frame                        | Notes                                                  |
|-----------------------------|------------------------------|--------------------------------------------------------|
| **Splash Screen**           | iPhone 15 Pro – 393×852pt    | Logo fade-in, tagline, loading animation               |
| **Login/Onboarding (Optional)** | Same frame                  | Optional for Checkpoint 1, helps with flow             |
| **Main Interface**          | iPhone 15 Pro                | Tabs: Home, Watchlist, Favorites, History              |
| **Product Detail View**     | iPhone 15 Pro                | Stock graph, alert button, wishlist toggle             |
| **Search + Filter UI**      | iPhone 15 Pro                | Top search bar, filters by brand/category              |
| **Wishlist/Alerts View**    | iPhone 15 Pro                | Focus on saved items, with stock alerts                |
| **Settings/About (Optional)** | iPhone 15 Pro              | Shows version, support, etc.                           |

 
# Accessibility Implementation

1. **Dynamic Type** support for all text elements
2. **VoiceOver optimization** with clear, descriptive labels
3. **Reduced Motion** option for animations
4. **Color blindness considerations** in your stock indicators (use patterns plus colors)
5. **Haptic feedback** for critical alerts
6. **Include an Accessibility section** in app settings

# Privacy and Security Features

1. **Local data storage** with encryption
2. **Keychain integration** for secure storage of API keys
3. **App Transport Security** for secure network communication
4. **Private relay compatibility** for anonymized tracking
5. **Privacy policy** linked in the app
6. **Transparency about data collection** (what is tracked and why)
7. **Add a "Privacy Dashboard"** showing what data is stored and where

# Apple Ecosystem Integration

Deep integration opportunities:

1. **Home Screen Widgets** showing critical items
2. **Lock Screen complications** for iOS 16+ showing count of low-stock items
3. **App Clips** for quick scanning of items to track
4. **Siri Shortcuts** for adding items or checking status
5. **Handoff** support between iOS and macOS
6. **App Intents** for Siri integration
7. **Share extensions** for sending items to colleagues
8. **Spotlight integration** for searching tracked items

# Light/Dark Mode Implementation

1. **Color assets** with light/dark variants
2. **Asset catalogs** for all images with dark mode alternatives
3. **System-respecting theme** with manual override option
4. **Color scheme detection** using SwiftUI's colorScheme environment value
5. **Preview both themes** in SwiftUI previews during development

# API Recommendations for Versatility

1. **Best Buy API**: Comprehensive electronics inventory (documented, fairly accessible)
2. **Home Depot API**: For construction/design materials
3. **Etsy API**: For handmade, vintage items
4. **Shopify Storefront API**: For smaller retailers
5. **eBay API**: For varied inventory across categories

Consider creating a protocol-based service layer that standardizes how your app interacts with different APIs to showcase good architecture.

# Swift Architecture Patterns

1. **MVVM pattern** (Model-View-ViewModel) for clean separation of concerns
2. **@Published properties** and **ObservableObject** for reactive UI updates
3. **Generics** for flexible API response handling
4. **Protocols** for defining service interfaces
5. **Structs** for your data models (Item, Alert, StockLevel)
6. **Enums with associated values** for stock status and error states
7. **Property wrappers** (@State, @Binding, @EnvironmentObject)
8. **Swift Concurrency** (async/await) for network calls
9. **Actors** for thread-safe data access
10. **Swift Package Manager** for modularizing features

# Standout Features to Include

1. **Collaborative Wishlists**
    - Allow users to invite others to view or edit a wishlist
    - Perfect for gift registries, shared shopping, etc.
2. **Price Change Notifications**
    - Visual indicators showing price history
    - Mini price graph on item cards
    - Color coding (green for price drops, red for increases)
3. **Smart Filtering**
    - Customizable tags system for organizing items across wishlists
    - Voice search for finding saved items
    - Natural language filtering ("show me items under $50")
4. **Contextual Actions**
    - Swipe to compare similar items
    - Option to set "purchase by" dates with reminders
    - Priority indicators (must-have, nice-to-have, etc.)
5. **AI-Enhanced Organization** (for future implementation or possible paid version)
    - Suggest wishlist groupings based on user behavior
    - Recommend optimal time to purchase based on price history
    - Auto-categorization of new items
6. **Duplicate Detection**
    - Alert users when they try to add the same item to multiple wishlists
    - Offer to consolidate or keep separate with one-tap action
  
# UI Mockups (Figma)

### Splash Screens:
![Splash Screens](https://github.com/user-attachments/assets/4ea3f07e-d01e-4887-b911-9df852c33dc3)

### Onboarding Flow:
![Onboarding Flow](https://github.com/user-attachments/assets/c75770bd-8168-4663-b03e-7d340e993996)

### Home Screen:
![Home Screen](https://github.com/user-attachments/assets/c30dc621-bb76-4918-8699-c592c49d1247)

### Search Functionality:
![Search Functionality - Modal Pop Up](https://github.com/user-attachments/assets/292f222b-d4e8-4103-b7ad-4d2bf2bf14a9)

### Add/Save Item Functionality:
![Add Item Functionality - Modal Pop Up](https://github.com/user-attachments/assets/e5b30442-62ef-44b0-8d66-522ff1e7763f)

### Saved & Settings Tab Intial Design:
![Saved   Settings Tab UI Designs](https://github.com/user-attachments/assets/a3cbab02-7781-4626-8c30-0e56fb6f9fcc)


# Technologies for Historical Trend Data (If time permits)

1. **Core Data or SwiftData** for local storage of historical pricing and availability
2. **Charts framework** introduced in iOS 16 for visualizing trends
3. **Combine** for reactive updates to trend data
4. **Background Tasks framework** to periodically fetch updates
5. **CloudKit** (optional) for syncing historical data across devices

# License
This project is licensed under the MIT License - see the LICENSE file for details.

