# BestBuyAPIService Migration Plan

## Overview
This document outlines the strategy for migrating BestBuyAPIService from a class-based implementation to a modern actor-based architecture while maintaining backward compatibility.

## Migration Phases

### Phase 1: Infrastructure Integration (Week 1)
**Goal**: Add modern infrastructure without breaking existing functionality

1. **Add New Properties** (alongside existing ones):
   ```swift
   // New infrastructure (add to existing class)
   private let optimizedClient = OptimizedAPIClient.shared
   private let cacheManager = UnifiedCacheManager.shared
   private let globalRateLimiter = GlobalRateLimiter.shared
   private let circuitBreaker = CircuitBreakerManager.shared
   ```

2. **Create Internal Helper Methods**:
   - `performCachedRequest<T>` - Wrapper for cached API calls
   - `performRateLimitedRequest<T>` - Wrapper for rate-limited calls
   - Keep existing methods working as-is

3. **Migrate Individual Endpoints** (one at a time):
   - Start with `getProductPricing` (simpler, isolated)
   - Then `getPopularTerms`
   - Leave hybrid search for last

### Phase 2: Dual Implementation (Week 2)
**Goal**: Create actor-based version alongside class

1. **Create BestBuyAPIActor**:
   ```swift
   actor BestBuyAPIActor: RetailerAPIService {
       // New implementation using modern infrastructure
       // Delegate to shared infrastructure components
   }
   ```

2. **Add Factory Method**:
   ```swift
   extension BestBuyAPIService {
       static func createModern() async -> BestBuyAPIActor {
           // Return actor-based implementation
       }
   }
   ```

3. **Maintain Protocol Conformance**:
   - Both class and actor conform to `RetailerAPIService`
   - Consumers can choose implementation

### Phase 3: Migration Support (Week 3)
**Goal**: Help consumers migrate

1. **Add Deprecation Warnings**:
   ```swift
   @available(*, deprecated, message: "Use BestBuyAPIActor instead")
   class BestBuyAPIService { ... }
   ```

2. **Provide Migration Guide**:
   - Document changes needed
   - Show before/after examples
   - Explain benefits

3. **Add Compatibility Layer**:
   - Wrapper methods for easy migration
   - Async adapters for sync code

### Phase 4: Cleanup (Week 4+)
**Goal**: Remove legacy code

1. **Remove Old Implementation**:
   - After all consumers migrated
   - Keep only actor-based version

2. **Optimize Caching**:
   - Unify all cache keys
   - Remove redundant cache logic

## Critical Components to Preserve

### 1. Hybrid Search Logic
The hybrid search approach MUST be preserved exactly as-is:

```swift
// This mapping is critical for search functionality
private let searchTermToSKUMapping: [String: [String]] = [
    "headphones": ["6501022", "6418599", "6535147", "6464297"],
    // ... rest of mapping
]

// These methods must work identically
private func searchProductsUsingHybridApproach(query: String) async throws -> [ProductItemDTO]
private func getSKUsForSearchTerm(_ query: String) -> [String]
```

### 2. Demo Mode Support
- `isDemoMode` flag behavior
- Mock data responses
- Fallback mechanisms

### 3. Rate Limiting Logic
- Monthly quota tracking
- API call counting
- Protection thresholds

## Implementation Order

1. **Start with Non-Search Methods**:
   - `getCategories()`
   - `getProductPricing()`
   - `getPopularTerms()`

2. **Then Simple Search Methods**:
   - `searchByCategory()`
   - `getTrendingProducts()`

3. **Finally Core Search**:
   - `searchProducts()` (uses hybrid approach)
   - `getProductDetails()`

## Testing Strategy

1. **Unit Tests**:
   - Test both implementations return same results
   - Verify cache behavior matches
   - Check rate limiting works identically

2. **Integration Tests**:
   - Run parallel requests through both
   - Compare response times
   - Verify error handling

3. **Migration Tests**:
   - Test deprecation warnings appear
   - Verify migration path works
   - Check backward compatibility

## Risk Mitigation

1. **Feature Flags**:
   ```swift
   let useModernImplementation = FeatureFlags.useModernBestBuyAPI
   ```

2. **Gradual Rollout**:
   - Start with read-only operations
   - Monitor error rates
   - Roll back if issues

3. **Monitoring**:
   - Track API response times
   - Monitor cache hit rates
   - Watch error frequencies

## Success Criteria

- [ ] All tests pass for both implementations
- [ ] No breaking changes for consumers
- [ ] Performance improves or stays same
- [ ] Error handling remains consistent
- [ ] Cache behavior unchanged
- [ ] Rate limiting still effective