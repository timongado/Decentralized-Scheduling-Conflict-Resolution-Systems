;; Resolution Coordination Contract
;; Coordinates conflict resolution process

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-RESOLUTION-NOT-FOUND (err u301))
(define-constant ERR-ALREADY-RESOLVED (err u302))
(define-constant ERR-INVALID-PROPOSAL (err u303))

;; Data Variables
(define-data-var next-resolution-id uint u1)

;; Data Maps
(define-map resolutions
  { resolution-id: uint }
  {
    conflict-id: uint,
    resolver: principal,
    proposal: (string-ascii 256),
    status: (string-ascii 16),
    created-at: uint,
    resolved-at: (optional uint),
    votes-for: uint,
    votes-against: uint
  }
)

(define-map resolution-votes
  { resolution-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

;; Public Functions

;; Initiate conflict resolution
(define-public (initiate-resolution (conflict-id uint) (proposal (string-ascii 256)))
  (let
    (
      (resolution-id (var-get next-resolution-id))
    )
    ;; Verify resolver is authorized (simplified check)
    (map-set resolutions
      { resolution-id: resolution-id }
      {
        conflict-id: conflict-id,
        resolver: tx-sender,
        proposal: proposal,
        status: "pending",
        created-at: block-height,
        resolved-at: none,
        votes-for: u0,
        votes-against: u0
      }
    )

    (var-set next-resolution-id (+ resolution-id u1))
    (ok resolution-id)
  )
)

;; Submit a resolution proposal
(define-public (submit-resolution (resolution-id uint) (new-proposal (string-ascii 256)))
  (match (map-get? resolutions { resolution-id: resolution-id })
    resolution-data
    (if (is-eq (get resolver resolution-data) tx-sender)
      (begin
        (map-set resolutions
          { resolution-id: resolution-id }
          (merge resolution-data {
            proposal: new-proposal,
            status: "updated"
          })
        )
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
    ERR-RESOLUTION-NOT-FOUND
  )
)

;; Vote on a resolution
(define-public (vote-resolution (resolution-id uint) (vote bool))
  (match (map-get? resolutions { resolution-id: resolution-id })
    resolution-data
    (let
      (
        (existing-vote (map-get? resolution-votes { resolution-id: resolution-id, voter: tx-sender }))
      )
      (if (is-none existing-vote)
        (begin
          (map-set resolution-votes
            { resolution-id: resolution-id, voter: tx-sender }
            { vote: vote, voted-at: block-height }
          )

          (map-set resolutions
            { resolution-id: resolution-id }
            (merge resolution-data {
              votes-for: (if vote (+ (get votes-for resolution-data) u1) (get votes-for resolution-data)),
              votes-against: (if vote (get votes-against resolution-data) (+ (get votes-against resolution-data) u1))
            })
          )
          (ok true)
        )
        (err u400) ;; Already voted
      )
    )
    ERR-RESOLUTION-NOT-FOUND
  )
)

;; Finalize resolution
(define-public (finalize-resolution (resolution-id uint))
  (match (map-get? resolutions { resolution-id: resolution-id })
    resolution-data
    (if (is-eq (get resolver resolution-data) tx-sender)
      (let
        (
          (votes-for (get votes-for resolution-data))
          (votes-against (get votes-against resolution-data))
          (final-status (if (> votes-for votes-against) "approved" "rejected"))
        )
        (map-set resolutions
          { resolution-id: resolution-id }
          (merge resolution-data {
            status: final-status,
            resolved-at: (some block-height)
          })
        )
        (ok final-status)
      )
      ERR-NOT-AUTHORIZED
    )
    ERR-RESOLUTION-NOT-FOUND
  )
)

;; Read-only Functions

;; Get resolution information
(define-read-only (get-resolution (resolution-id uint))
  (map-get? resolutions { resolution-id: resolution-id })
)

;; Get vote information
(define-read-only (get-vote (resolution-id uint) (voter principal))
  (map-get? resolution-votes { resolution-id: resolution-id, voter: voter })
)

;; Check resolution status
(define-read-only (is-resolution-approved (resolution-id uint))
  (match (map-get? resolutions { resolution-id: resolution-id })
    resolution-data
    (is-eq (get status resolution-data) "approved")
    false
  )
)
