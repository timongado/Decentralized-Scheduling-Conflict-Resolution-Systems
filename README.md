# Decentralized Scheduling Conflict Resolution System

A blockchain-based system for resolving scheduling conflicts in a decentralized manner using Stacks and Clarity smart contracts.

## System Overview

This system provides a decentralized approach to scheduling conflict resolution, eliminating the need for centralized scheduling authorities. It uses smart contracts to detect conflicts, coordinate resolutions, and optimize scheduling decisions.

## Architecture

### Core Components

1. **Conflict Resolver Verification** - Validates and manages conflict resolvers
2. **Conflict Detection** - Identifies scheduling conflicts between events
3. **Resolution Coordination** - Manages the conflict resolution process
4. **Priority Management** - Handles scheduling priorities and hierarchies
5. **Optimization Algorithm** - Optimizes conflict resolution decisions

## Smart Contracts

### conflict-resolver-verification.clar
Manages the verification and reputation of conflict resolvers.

**Key Functions:**
- \`register-resolver\` - Register a new conflict resolver
- \`verify-resolver\` - Verify resolver credentials
- \`update-reputation\` - Update resolver reputation scores

### conflict-detection.clar
Detects and identifies scheduling conflicts between events.

**Key Functions:**
- \`register-event\` - Register a new scheduling event
- \`detect-conflict\` - Check for conflicts with existing events
- \`get-conflicts\` - Retrieve all conflicts for a time period

### resolution-coordination.clar
Coordinates the resolution process for detected conflicts.

**Key Functions:**
- \`initiate-resolution\` - Start conflict resolution process
- \`submit-resolution\` - Submit a resolution proposal
- \`finalize-resolution\` - Complete the resolution process

### priority-management.clar
Manages scheduling priorities and hierarchies.

**Key Functions:**
- \`set-priority\` - Set priority level for events
- \`get-priority\` - Retrieve priority information
- \`compare-priorities\` - Compare priority levels

### optimization-algorithm.clar
Optimizes conflict resolution using algorithmic approaches.

**Key Functions:**
- \`optimize-schedule\` - Optimize scheduling decisions
- \`calculate-efficiency\` - Calculate scheduling efficiency
- \`suggest-alternatives\` - Suggest alternative scheduling options

## Usage

### Basic Workflow

1. **Register Resolvers**: Conflict resolvers register and get verified
2. **Schedule Events**: Users register events with time slots and priorities
3. **Detect Conflicts**: System automatically detects scheduling conflicts
4. **Resolve Conflicts**: Verified resolvers propose and implement solutions
5. **Optimize Schedule**: Algorithm optimizes the final schedule

### Example Usage

\`\`\`clarity
;; Register a new event
(contract-call? .conflict-detection register-event
u1234567890 ;; start-time
u1234568890 ;; end-time
"Meeting Room A" ;; resource
u5) ;; priority

;; Detect conflicts
(contract-call? .conflict-detection detect-conflict u1234567890 u1234568890 "Meeting Room A")

;; Initiate resolution if conflict found
(contract-call? .resolution-coordination initiate-resolution conflict-id)
\`\`\`

## Testing

Run the test suite using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover:
- Individual contract functionality
- Cross-contract interactions
- Edge cases and error conditions
- Performance and security scenarios

## Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts to Stacks testnet/mainnet

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details
</Md>

Now let's create the smart contracts. First, the conflict resolver verification contract:

```clarity file="contracts/conflict-resolver-verification.clar"
;; Conflict Resolver Verification Contract
;; Manages verification and reputation of conflict resolvers

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-RESOLVER-EXISTS (err u101))
(define-constant ERR-RESOLVER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-REPUTATION (err u103))

;; Data Variables
(define-data-var next-resolver-id uint u1)

;; Data Maps
(define-map resolvers
  { resolver-id: uint }
  {
    owner: principal,
    reputation: uint,
    total-resolutions: uint,
    successful-resolutions: uint,
    verified: bool,
    registration-block: uint
  }
)

(define-map resolver-by-principal
  { owner: principal }
  { resolver-id: uint }
)

;; Public Functions

;; Register a new conflict resolver
(define-public (register-resolver)
  (let
    (
      (resolver-id (var-get next-resolver-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? resolver-by-principal { owner: caller })) ERR-RESOLVER-EXISTS)
    
    (map-set resolvers
      { resolver-id: resolver-id }
      {
        owner: caller,
        reputation: u100,
        total-resolutions: u0,
        successful-resolutions: u0,
        verified: false,
        registration-block: block-height
      }
    )
    
    (map-set resolver-by-principal
      { owner: caller }
      { resolver-id: resolver-id }
    )
    
    (var-set next-resolver-id (+ resolver-id u1))
    (ok resolver-id)
  )
)

;; Verify a resolver (only contract owner)
(define-public (verify-resolver (resolver-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? resolvers { resolver-id: resolver-id })
      resolver-data
      (begin
        (map-set resolvers
          { resolver-id: resolver-id }
          (merge resolver-data { verified: true })
        )
        (ok true)
      )
      ERR-RESOLVER-NOT-FOUND
    )
  )
)

;; Update resolver reputation
(define-public (update-reputation (resolver-id uint) (successful bool))
  (match (map-get? resolvers { resolver-id: resolver-id })
    resolver-data
    (let
      (
        (new-total (+ (get total-resolutions resolver-data) u1))
        (new-successful (if successful 
                         (+ (get successful-resolutions resolver-data) u1)
                         (get successful-resolutions resolver-data)))
        (new-reputation (if (> new-total u0)
                         (/ (* new-successful u100) new-total)
                         u100))
      )
      (map-set resolvers
        { resolver-id: resolver-id }
        (merge resolver-data {
          total-resolutions: new-total,
          successful-resolutions: new-successful,
          reputation: new-reputation
        })
      )
      (ok new-reputation)
    )
    ERR-RESOLVER-NOT-FOUND
  )
)

;; Read-only Functions

;; Get resolver information
(define-read-only (get-resolver (resolver-id uint))
  (map-get? resolvers { resolver-id: resolver-id })
)

;; Get resolver by principal
(define-read-only (get-resolver-by-principal (owner principal))
  (match (map-get? resolver-by-principal { owner: owner })
    resolver-ref
    (map-get? resolvers { resolver-id: (get resolver-id resolver-ref) })
    none
  )
)

;; Check if resolver is verified
(define-read-only (is-resolver-verified (resolver-id uint))
  (match (map-get? resolvers { resolver-id: resolver-id })
    resolver-data
    (get verified resolver-data)
    false
  )
)
