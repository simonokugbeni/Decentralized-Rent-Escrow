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
