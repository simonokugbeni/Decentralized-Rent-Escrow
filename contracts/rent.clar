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


;; Add to Data Maps
(define-map property-inspections
    { property: principal, inspection-id: uint }
    {
        inspector: principal,
        date: uint,
        passed: bool,
        notes: (string-ascii 256)
    }
)

(define-data-var inspection-counter uint u0)

;; Request inspection function
(define-public (request-inspection (landlord principal) (notes (string-ascii 256)))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (inspection-id (+ (var-get inspection-counter) u1))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (var-set inspection-counter inspection-id)
                (ok (map-set property-inspections
                    { property: landlord, inspection-id: inspection-id }
                    {
                        inspector: landlord,
                        date: stacks-block-height,
                        passed: false,
                        notes: notes
                    })))
            ERR-NOT-AUTHORIZED)))

;; Record inspection results
(define-public (record-inspection-result (inspection-id uint) (passed bool) (notes (string-ascii 256)))
    (let (
        (inspection (unwrap! (map-get? property-inspections { property: tx-sender, inspection-id: inspection-id }) (err u104)))
    )
        (ok (map-set property-inspections
            { property: tx-sender, inspection-id: inspection-id }
            (merge inspection { passed: passed, notes: notes })))))

;; Get inspection details
(define-read-only (get-inspection-details (property principal) (inspection-id uint))
    (map-get? property-inspections { property: property, inspection-id: inspection-id }))


;; Add to Data Maps
(define-map rent-increases
    { property: principal, increase-id: uint }
    {
        current-amount: uint,
        new-amount: uint,
        effective-date: uint,
        acknowledged: bool
    }
)

(define-data-var increase-counter uint u0)

;; Propose rent increase
(define-public (propose-rent-increase (new-amount uint) (effective-block-height uint))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
        (increase-id (+ (var-get increase-counter) u1))
        (current-amount (get rent-amount property))
    )
        (begin
            (var-set increase-counter increase-id)
            (ok (map-set rent-increases
                { property: tx-sender, increase-id: increase-id }
                {
                    current-amount: current-amount,
                    new-amount: new-amount,
                    effective-date: effective-block-height,
                    acknowledged: false
                })))))

;; Acknowledge rent increase
(define-public (acknowledge-rent-increase (landlord principal) (increase-id uint))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (increase (unwrap! (map-get? rent-increases { property: landlord, increase-id: increase-id }) (err u105)))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (map-set rent-increases
                    { property: landlord, increase-id: increase-id }
                    (merge increase { acknowledged: true }))
                
                ;; Update rent amount if effective date has passed
                (if (>= stacks-block-height (get effective-date increase))
                    (map-set properties landlord
                        (merge property { rent-amount: (get new-amount increase) }))
                    true)
                (ok true))
            ERR-NOT-AUTHORIZED)))

;; Get rent increase details
(define-read-only (get-rent-increase (property principal) (increase-id uint))
    (map-get? rent-increases { property: property, increase-id: increase-id }))


;; Add to Data Maps
(define-map sublet-requests
    { property: principal, request-id: uint }
    {
        tenant: principal,
        subtenant: principal,
        start-date: uint,
        end-date: uint,
        status: (string-ascii 20),
        notes: (string-ascii 256)
    }
)

(define-data-var sublet-counter uint u0)

;; Request subletting
(define-public (request-sublet (landlord principal) (subtenant principal) (start-date uint) (end-date uint) (notes (string-ascii 256)))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (request-id (+ (var-get sublet-counter) u1))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (var-set sublet-counter request-id)
                (ok (map-set sublet-requests
                    { property: landlord, request-id: request-id }
                    {
                        tenant: tx-sender,
                        subtenant: subtenant,
                        start-date: start-date,
                        end-date: end-date,
                        status: "pending",
                        notes: notes
                    })))
            ERR-NOT-AUTHORIZED)))

;; Approve or deny sublet request
(define-public (respond-to-sublet (request-id uint) (approve bool) (notes (string-ascii 256)))
    (let (
        (request (unwrap! (map-get? sublet-requests { property: tx-sender, request-id: request-id }) (err u106)))
        (status (if approve "approved" "denied"))
    )
        (ok (map-set sublet-requests
            { property: tx-sender, request-id: request-id }
            (merge request { status: status, notes: notes })))))

;; Get sublet request details
(define-read-only (get-sublet-request (property principal) (request-id uint))
    (map-get? sublet-requests { property: property, request-id: request-id }))


;; Add to Data Maps
(define-map lease-terms
    principal
    {
        start-date: uint,
        end-date: uint,
        auto-renew: bool,
        renewal-term: uint,
        renewal-notice-period: uint
    }
)

(define-map renewal-offers
    { property: principal, offer-id: uint }
    {
        new-end-date: uint,
        new-rent-amount: uint,
        offered-at: uint,
        expires-at: uint,
        status: (string-ascii 20)
    }
)

(define-data-var renewal-counter uint u0)

;; Set initial lease terms
(define-public (set-lease-terms (start-date uint) (end-date uint) (auto-renew bool) (renewal-term uint) (renewal-notice-period uint))
    (let ((sender tx-sender))
        (ok (map-set lease-terms sender
            {
                start-date: start-date,
                end-date: end-date,
                auto-renew: auto-renew,
                renewal-term: renewal-term,
                renewal-notice-period: renewal-notice-period
            }))))

;; Offer lease renewal
(define-public (offer-renewal (new-end-date uint) (new-rent-amount uint) (expires-at uint))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
        (offer-id (+ (var-get renewal-counter) u1))
    )
        (begin
            (var-set renewal-counter offer-id)
            (ok (map-set renewal-offers
                { property: tx-sender, offer-id: offer-id }
                {
                    new-end-date: new-end-date,
                    new-rent-amount: new-rent-amount,
                    offered-at: stacks-block-height,
                    expires-at: expires-at,
                    status: "offered"
                })))))

;; Accept renewal offer
(define-public (accept-renewal (landlord principal) (offer-id uint))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (offer (unwrap! (map-get? renewal-offers { property: landlord, offer-id: offer-id }) (err u107)))
        (lease (unwrap! (map-get? lease-terms landlord) (err u108)))
    )
        (if (and (is-eq (some tx-sender) (get tenant property)) (< stacks-block-height (get expires-at offer)))
            (begin
                ;; Update lease terms
                (map-set lease-terms landlord
                    (merge lease { end-date: (get new-end-date offer) }))
                
                ;; Update rent amount
                (map-set properties landlord
                    (merge property { rent-amount: (get new-rent-amount offer) }))
                
                ;; Update offer status
                (map-set renewal-offers
                    { property: landlord, offer-id: offer-id }
                    (merge offer { status: "accepted" }))
                
                (ok true))
            ERR-NOT-AUTHORIZED)))

;; Get lease terms
(define-read-only (get-lease-terms (property principal))
    (map-get? lease-terms property))

;; Get renewal offer
(define-read-only (get-renewal-offer (property principal) (offer-id uint))
    (map-get? renewal-offers { property: property, offer-id: offer-id }))



;; Add to Data Maps
(define-map utility-payments
    { property: principal, payment-id: uint }
    {
        utility-type: (string-ascii 20),
        amount: uint,
        due-date: uint,
        paid-date: uint,
        paid: bool
    }
)

(define-data-var utility-counter uint u0)

;; Add utility bill
(define-public (add-utility-bill (utility-type (string-ascii 20)) (amount uint) (due-date uint))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
        (payment-id (+ (var-get utility-counter) u1))
    )
        (begin
            (var-set utility-counter payment-id)
            (ok (map-set utility-payments
                { property: tx-sender, payment-id: payment-id }
                {
                    utility-type: utility-type,
                    amount: amount,
                    due-date: due-date,
                    paid-date: u0,
                    paid: false
                })))))

;; Pay utility bill
(define-public (pay-utility-bill (landlord principal) (payment-id uint))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (utility (unwrap! (map-get? utility-payments { property: landlord, payment-id: payment-id }) (err u109)))
        (payment (get amount utility))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (try! (stx-transfer? payment tx-sender landlord))
                (ok (map-set utility-payments
                    { property: landlord, payment-id: payment-id }
                    (merge utility { paid: true, paid-date: stacks-block-height }))))
            ERR-NOT-AUTHORIZED)))

;; Get utility payment details
(define-read-only (get-utility-payment (property principal) (payment-id uint))
    (map-get? utility-payments { property: property, payment-id: payment-id }))

;; Get all utility payments for a property
(define-read-only (get-property-utilities (property principal))
    (map-get? utility-payments { property: property, payment-id: u0 }))



;; Add to Data Maps
(define-map security-deposits
    principal
    {
        amount: uint,
        paid-date: uint,
        returned: bool,
        return-date: uint
    }
)

(define-map deposit-deductions
    { property: principal, deduction-id: uint }
    {
        amount: uint,
        reason: (string-ascii 256),
        evidence: (string-ascii 256),
        disputed: bool
    }
)

(define-data-var deduction-counter uint u0)

;; Pay security deposit
(define-public (pay-security-deposit (landlord principal))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (deposit-amount (get deposit property))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (begin
                (try! (stx-transfer? deposit-amount tx-sender landlord))
                (ok (map-set security-deposits landlord
                    {
                        amount: deposit-amount,
                        paid-date: stacks-block-height,
                        returned: false,
                        return-date: u0
                    })))
            ERR-NOT-AUTHORIZED)))

;; Add deposit deduction
(define-public (add-deposit-deduction (tenant principal) (amount uint) (reason (string-ascii 256)) (evidence (string-ascii 256)))
    (let (
        (property (unwrap! (map-get? properties tx-sender) (err u103)))
        (deduction-id (+ (var-get deduction-counter) u1))
    )
        (if (is-eq (some tenant) (get tenant property))
            (begin
                (var-set deduction-counter deduction-id)
                (ok (map-set deposit-deductions
                    { property: tx-sender, deduction-id: deduction-id }
                    {
                        amount: amount,
                        reason: reason,
                        evidence: evidence,
                        disputed: false
                    })))
            ERR-NOT-AUTHORIZED)))

;; Dispute deposit deduction
(define-public (dispute-deduction (landlord principal) (deduction-id uint))
    (let (
        (property (unwrap! (map-get? properties landlord) (err u103)))
        (deduction (unwrap! (map-get? deposit-deductions { property: landlord, deduction-id: deduction-id }) (err u110)))
    )
        (if (is-eq (some tx-sender) (get tenant property))
            (ok (map-set deposit-deductions
                { property: landlord, deduction-id: deduction-id }
                (merge deduction { disputed: true })))
            ERR-NOT-AUTHORIZED)))

