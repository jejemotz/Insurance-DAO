(define-constant contract-owner tx-sender)

(define-constant err-owner-only (err u100))
(define-constant err-pool-exists (err u101))
(define-constant err-pool-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-claim-not-found (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-claim-expired (err u106))
(define-constant err-not-pool-member (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-claim-period-active (err u109))

(define-data-var next-pool-id uint u1)
(define-data-var next-claim-id uint u1)

(define-map insurance-pools
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    premium-rate: uint,
    max-coverage: uint,
    total-staked: uint,
    active-until: uint,
    creator: principal,
    min-stake: uint
  }
)

(define-map pool-members
  { pool-id: uint, member: principal }
  {
    stake-amount: uint,
    joined-at: uint,
    last-claim: uint
  }
)

(define-map insurance-claims
  uint
  {
    pool-id: uint,
    claimant: principal,
    amount: uint,
    evidence: (string-ascii 500),
    submitted-at: uint,
    expires-at: uint,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    status: (string-ascii 20)
  }
)

(define-map claim-votes
  { claim-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

(define-map pool-stats
  uint
  {
    total-claims: uint,
    paid-claims: uint,
    total-payouts: uint
  }
)

(define-public (create-pool 
  (name (string-ascii 50))
  (description (string-ascii 200))
  (premium-rate uint)
  (max-coverage uint)
  (duration-blocks uint)
  (min-stake uint))
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (> premium-rate u0) err-invalid-amount)
    (asserts! (> max-coverage u0) err-invalid-amount)
    (asserts! (> min-stake u0) err-invalid-amount)
    (map-set insurance-pools pool-id {
      name: name,
      description: description,
      premium-rate: premium-rate,
      max-coverage: max-coverage,
      total-staked: u0,
      active-until: (+ stacks-block-height duration-blocks),
      creator: tx-sender,
      min-stake: min-stake
    })
    (map-set pool-stats pool-id {
      total-claims: u0,
      paid-claims: u0,
      total-payouts: u0
    })
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
  )
)

(define-public (stake-tokens (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? insurance-pools pool-id) err-pool-not-found))
    (existing-member (map-get? pool-members { pool-id: pool-id, member: tx-sender }))
  )
    (asserts! (>= stacks-block-height (get active-until pool)) err-claim-period-active)
    (asserts! (>= amount (get min-stake pool)) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (match existing-member
      member (map-set pool-members 
        { pool-id: pool-id, member: tx-sender }
        {
          stake-amount: (+ (get stake-amount member) amount),
          joined-at: (get joined-at member),
          last-claim: (get last-claim member)
        })
      (map-set pool-members 
        { pool-id: pool-id, member: tx-sender }
        {
          stake-amount: amount,
          joined-at: stacks-block-height,
          last-claim: u0
        })
    )
    (map-set insurance-pools pool-id
      (merge pool { total-staked: (+ (get total-staked pool) amount) })
    )
    (ok amount)
  )
)

(define-public (submit-claim 
  (pool-id uint) 
  (amount uint) 
  (evidence (string-ascii 500)))
  (let (
    (pool (unwrap! (map-get? insurance-pools pool-id) err-pool-not-found))
    (member (unwrap! (map-get? pool-members { pool-id: pool-id, member: tx-sender }) err-not-pool-member))
    (claim-id (var-get next-claim-id))
    (stats (unwrap! (map-get? pool-stats pool-id) err-pool-not-found))
  )
    (asserts! (<= amount (get max-coverage pool)) err-invalid-amount)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (< stacks-block-height (get active-until pool)) err-claim-period-active)
    (map-set insurance-claims claim-id {
      pool-id: pool-id,
      claimant: tx-sender,
      amount: amount,
      evidence: evidence,
      submitted-at: stacks-block-height,
      expires-at: (+ stacks-block-height u1008),
      votes-for: u0,
      votes-against: u0,
      total-voters: u0,
      status: "pending"
    })
    (map-set pool-stats pool-id
      (merge stats { total-claims: (+ (get total-claims stats) u1) })
    )
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (vote-on-claim (claim-id uint) (approve bool))
  (let (
    (claim (unwrap! (map-get? insurance-claims claim-id) err-claim-not-found))
    (member (unwrap! (map-get? pool-members { pool-id: (get pool-id claim), member: tx-sender }) err-not-pool-member))
    (existing-vote (map-get? claim-votes { claim-id: claim-id, voter: tx-sender }))
  )
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (< stacks-block-height (get expires-at claim)) err-claim-expired)
    (asserts! (is-eq (get status claim) "pending") err-claim-expired)
    (map-set claim-votes { claim-id: claim-id, voter: tx-sender }
      { vote: approve, voted-at: stacks-block-height })
    (if approve
      (map-set insurance-claims claim-id
        (merge claim { 
          votes-for: (+ (get votes-for claim) u1),
          total-voters: (+ (get total-voters claim) u1)
        }))
      (map-set insurance-claims claim-id
        (merge claim { 
          votes-against: (+ (get votes-against claim) u1),
          total-voters: (+ (get total-voters claim) u1)
        }))
    )
    (ok true)
  )
)

(define-public (process-claim (claim-id uint))
  (let (
    (claim (unwrap! (map-get? insurance-claims claim-id) err-claim-not-found))
    (pool (unwrap! (map-get? insurance-pools (get pool-id claim)) err-pool-not-found))
    (stats (unwrap! (map-get? pool-stats (get pool-id claim)) err-pool-not-found))
  )
    (asserts! (or 
      (>= stacks-block-height (get expires-at claim))
      (>= (get total-voters claim) u3)) err-claim-expired)
    (asserts! (is-eq (get status claim) "pending") err-claim-expired)
    (if (> (get votes-for claim) (get votes-against claim))
      (begin
        (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get claimant claim))))
        (map-set insurance-claims claim-id
          (merge claim { status: "approved" }))
        (map-set pool-stats (get pool-id claim)
          (merge stats { 
            paid-claims: (+ (get paid-claims stats) u1),
            total-payouts: (+ (get total-payouts stats) (get amount claim))
          }))
        (ok "approved")
      )
      (begin
        (map-set insurance-claims claim-id
          (merge claim { status: "rejected" }))
        (ok "rejected")
      )
    )
  )
)

(define-public (withdraw-stake (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? insurance-pools pool-id) err-pool-not-found))
    (member (unwrap! (map-get? pool-members { pool-id: pool-id, member: tx-sender }) err-not-pool-member))
  )
    (asserts! (>= stacks-block-height (get active-until pool)) err-claim-period-active)
    (asserts! (<= amount (get stake-amount member)) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (if (is-eq amount (get stake-amount member))
      (map-delete pool-members { pool-id: pool-id, member: tx-sender })
      (map-set pool-members { pool-id: pool-id, member: tx-sender }
        (merge member { stake-amount: (- (get stake-amount member) amount) }))
    )
    (map-set insurance-pools pool-id
      (merge pool { total-staked: (- (get total-staked pool) amount) })
    )
    (ok amount)
  )
)

(define-read-only (get-pool (pool-id uint))
  (map-get? insurance-pools pool-id)
)

(define-read-only (get-pool-member (pool-id uint) (member principal))
  (map-get? pool-members { pool-id: pool-id, member: member })
)

(define-read-only (get-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-claim-vote (claim-id uint) (voter principal))
  (map-get? claim-votes { claim-id: claim-id, voter: voter })
)

(define-read-only (get-pool-stats (pool-id uint))
  (map-get? pool-stats pool-id)
)

(define-read-only (get-next-pool-id)
  (var-get next-pool-id)
)

(define-read-only (get-next-claim-id)
  (var-get next-claim-id)
)

(define-read-only (calculate-premium (pool-id uint) (coverage-amount uint))
  (match (map-get? insurance-pools pool-id)
    pool (ok (/ (* coverage-amount (get premium-rate pool)) u10000))
    err-pool-not-found
  )
)
