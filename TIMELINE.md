# Rasuto Project Timeline

## Overview
This timeline outlines the development plan for Rasuto, an iOS app for tracking product availability. The timeline is structured to achieve an MVP by early June, focusing on three core functionalities: Wishlist/Saved Collections, Alerts/Notifications, and Stock Monitoring/Add Item functionality.


## Phase 1: Planning & Setup (April 15 - April 28)
**Milestone 1.1: Project Setup & Architecture Design** (April 15 - April 21)
- [x] Create GitHub repository and initial project structure
- [x] Set up development environment with Xcode
- [x] Configure SwiftData with CloudKit integration
- [x] Design database schema for product information
- [x] Research and document API/web scraping approaches for target retailers
- [x] Create technical specification document for data handling
- [x] Set up project management tools (issue tracking, Git workflow)


**Milestone 1.2: UI Framework & Base Navigation** (April 22 - April 28)
- [x] Implement basic app navigation structure
- [x] Create reusable UI components matching Figma designs
- [x] Implement splash screen with animation and UserDefaults storage
- [x] Set up color schemes and typography system
- [x] Implement base tab bar navigation
- [x] Create skeleton screens for main app sections


## Phase 2: Core Data & Basic Functionality (April 29 - May 12)
**Milestone 2.1: Data Models & API Integration** (April 29 - May 5)
- [x] Implement SwiftData models for products, wishlists, and user preferences
- [x] Create service layer for API calls to retailers
- [x] Implement data parsing and normalization
- [x] Set up error handling and offline capabilities
- [x] Create mock data for development


**Milestone 2.2: Add Item Functionality** (May 6 - May 12)
- [x] Implement "Add Item" screen matching Figma mockup
- [ ] Build URL parsing functionality for product links
- [ ] Create product preview generation
- [ ] Implement collection/wishlist selection or creation
- [ ] Build product metadata extraction
- [ ] Create unit tests for Add Item functionality
- [ ] Implement initial smart filtering/tags system

## Phase 3: Core MVP Features (May 13 - May 26)
**Milestone 3.1: Wishlist & Collections** (May 13 - May 19)
- [ ] Implement wishlist view and collection management
- [ ] Create collection viewing and editing functionality
- [ ] Build list/grid view toggle
- [ ] Implement sorting and filtering options
- [ ] Create wishlist sharing functionality (social integration)
- [ ] Add swipe actions for wishlist items
- [ ] Implement Natural Language Filtering

**Milestone 3.2: Stock Monitoring & Notifications** (May 20 - May 26)
- [ ] Build background fetch for stock monitoring
- [ ] Implement notification permission request flow
- [ ] Create notification management system
- [ ] Build stock status display in product views
- [ ] Implement notification settings screen
- [ ] Create local and push notification handlers
- [ ] Build stock history tracking (basic)


## Phase 4: Polish & Additional Features (May 27 - June 9)
**Milestone 4.1: Voice Search & Advanced Filtering** (May 27 - June 2)
- [ ] Implement Voice Search integration
- [ ] Enhance smart filtering system
- [ ] Build advanced tag management
- [ ] Create search history functionality
- [ ] Implement search suggestions
- [ ] Add accessibility features
- [ ] Create onboarding flow for smart features


**Milestone 4.2: Final Polish & Testing** (June 3 - June 9)
- [ ] Perform UI/UX refinements based on testing
- [ ] Optimize performance
- [ ] Conduct comprehensive testing across devices
- [ ] Fix identified bugs and issues
- [ ] Implement analytics for usage tracking
- [ ] Create app store assets
- [ ] Prepare documentation for submission


## Phase 5: Launch Preparation & Future Planning (June 10 - June 16)
**Milestone 5.1: MVP Launch** (June 10 - June 13)
- [ ] Finalize app store listing
- [ ] Create marketing materials
- [ ] Prepare for TestFlight distribution
- [ ] Create user guide/documentation
- [ ] Conduct final quality assurance


**Milestone 5.2: Future Development Planning** (June 14 - June 16)
- [ ] Document lessons learned
- [ ] Plan post-MVP feature roadmap
- [ ] Identify potential performance improvements
- [ ] Create backlog for future development
- [ ] Outline strategy for user feedback collection


## Technical Considerations & Notes


### Data Storage Strategy
- SwiftData with CloudKit integration for cross-device functionality
- Local caching for offline access
- Efficient storage of product metadata and images


### API & Web Scraping
- Build modular scrapers for each supported retailer
- Implement rate limiting and retry mechanisms
- Create fallback strategies for when APIs change


### Notification Strategy
- Request permissions contextually when user adds first item
- Implement smart notification grouping
- Allow fine-grained control over notification types


### Performance Considerations
- Background fetch optimization to minimize battery impact
- Efficient image caching and loading
- Pagination for large collections


### Next.js Integration
- Server-side components for web scraping
- API endpoints for stock checking
- Secure communication between iOS app and Next.js server
