;; Decentralized Rent Escrow Contract

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))

;; Data Maps
(define-map properties 
    principal 
    {
        tenant: (optional principal),
        rent-amount: uint,
        deposit: uint,
        is-maintained: bool
    }
)

(define-map escrow-balance principal uint)

;; Public Functions
(define-public (register-property (rent-amount uint) (deposit uint))
    (let ((sender tx-sender))
        (ok (map-set properties sender {
            tenant: none,
            rent-amount: rent-amount,
            deposit: deposit,
            is-maintained: true
        }))))

(define-public (pay-rent (landlord principal))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (payment (get rent-amount property))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
                (map-set escrow-balance landlord (+ (default-to u0 (map-get? escrow-balance landlord)) payment))
                (ok true))
            ERR-NOT-AUTHORIZED)))

(define-public (release-rent (tenant principal))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
        (balance (default-to u0 (map-get? escrow-balance tx-sender)))
    )
        (if (and (is-eq (some tenant) (get tenant property)) (get is-maintained property))
            (begin 
                (try! (as-contract (stx-transfer? balance tx-sender tx-sender)))
                (map-set escrow-balance tx-sender u0)
                (ok true))
            ERR-NOT-AUTHORIZED)))

;; Read Only Functions
(define-read-only (get-property-details (landlord principal))
    (map-get? properties landlord))

(define-read-only (get-escrow-balance (landlord principal))
    (default-to u0 (map-get? escrow-balance landlord)))


(define-public (assign-tenant (new-tenant principal))
    (let ((property (unwrap! (map-get? properties tx-sender) (err u103))))
        (ok (map-set properties tx-sender 
            (merge property { tenant: (some new-tenant) })))))



;; Add to Data Maps
(define-map maintenance-requests 
    { property: principal, request-id: uint } 
    {
        description: (string-ascii 256),
        status: (string-ascii 20),
        timestamp: uint
    }
)

(define-data-var request-counter uint u0)

;; Add Public Function
(define-public (submit-maintenance-request (landlord principal) (description (string-ascii 256)))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (request-id (+ (var-get request-counter) u1))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (var-set request-counter request-id)
                (ok (map-set maintenance-requests 
                    { property: landlord, request-id: request-id }
                    {
                        description: description,
                        status: "pending",
                        timestamp: stacks-block-height
                    })))
            ERR-NOT-AUTHORIZED)))


;; Add to Data Maps
(define-map payment-history
    { landlord: principal, tenant: principal }
    (list 50 {
        amount: uint,
        timestamp: uint
    })
)

;; Add to pay-rent function
(define-public (record-payment (landlord principal) (amount uint))
    (let (
        (current-history (default-to (list) (map-get? payment-history { landlord: landlord, tenant: tx-sender })))
        (new-entry { amount: amount, timestamp: stacks-block-height })
    )
        (ok (map-set payment-history 
            { landlord: landlord, tenant: tx-sender }
            (if (>= (len current-history) u50)
                (unwrap-panic (as-max-len? (append current-history new-entry) u50))
                (unwrap-panic (as-max-len? (append current-history new-entry) u50)))))))



;; Add to Data Maps
(define-map property-ratings
    principal
    {
        total-score: uint,
        num-ratings: uint,
        average: uint
    }
)

(define-public (rate-property (landlord principal) (score uint))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (current-rating (default-to { total-score: u0, num-ratings: u0, average: u0 } 
                        (map-get? property-ratings landlord)))
    )
        (if (and (is-eq (some tx-sender) (get tenant property)) (<= score u5))
            (ok (map-set property-ratings landlord
                {
                    total-score: (+ (get total-score current-rating) score),
                    num-ratings: (+ (get num-ratings current-rating) u1),
                    average: (/ (+ (get total-score current-rating) score) 
                              (+ (get num-ratings current-rating) u1))
                }))
            ERR-NOT-AUTHORIZED)))



;; Add to Properties Map
(define-map late-payments
    principal
    {
        due-date: uint,
        penalty-rate: uint,
        grace-period: uint
    }
)

(define-public (set-payment-terms (due-date uint) (penalty-rate uint) (grace-period uint))
    (let ((sender tx-sender))
        (ok (map-set late-payments sender
            {
                due-date: due-date,
                penalty-rate: penalty-rate,
                grace-period: grace-period
            }))))


;; Add to Data Maps
(define-map deposit-claims
    principal
    {
        amount: uint,
        reason: (string-ascii 256),
        status: (string-ascii 20)
    }
)

(define-public (claim-deposit (tenant principal) (amount uint) (reason (string-ascii 256)))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
    )
        (if (is-eq (some tenant) (get tenant property))
            (ok (map-set deposit-claims tx-sender
                {
                    amount: amount,
                    reason: reason,
                    status: "pending"
                }))
            ERR-NOT-AUTHORIZED)))



;; Add to Data Maps
(define-map landlord-properties
    principal
    (list 20 principal)
)

(define-public (add-property (property-id principal))
    (let (
        (current-properties (default-to (list) (map-get? landlord-properties tx-sender)))
    )
        (ok (map-set landlord-properties tx-sender
            (unwrap-panic (as-max-len? (append current-properties property-id) u20))))))
