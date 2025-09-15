;; Digital Access Keys - Property Access Management
;; Issues revocable time-bound NFT tokens as digital keys

(define-non-fungible-token access-key uint)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-TOKEN-NOT-FOUND (err u601))
(define-constant ERR-TRANSFER-DISABLED (err u602))
(define-constant ERR-INVALID-DURATION (err u605))

;; Data storage
(define-map access-keys
    uint
    {
        owner: principal,
        property: principal,
        expires-at: uint,
        active: bool,
        issued-by: principal
    }
)

(define-map property-key-count principal uint)
(define-map tenant-active-keys { tenant: principal, property: principal } uint)

;; Variables
(define-data-var next-token-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; NFT Functions
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    ERR-TRANSFER-DISABLED)

(define-read-only (get-owner (token-id uint))
    (ok (get owner (map-get? access-keys token-id))))

(define-read-only (get-last-token-id)
    (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
    (ok (some "https://access-keys.rent/metadata/{id}")))

;; Core Functions

;; Mint new access key
(define-public (mint-access-key (tenant principal) (property principal) (duration-blocks uint))
    (let (
        (token-id (var-get next-token-id))
        (expires-at (+ stacks-block-height duration-blocks))
    )
        (begin
            (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
            (asserts! (<= duration-blocks u52560) ERR-INVALID-DURATION)
            
            (try! (nft-mint? access-key token-id tenant))
            
            (map-set access-keys token-id {
                owner: tenant,
                property: property,
                expires-at: expires-at,
                active: true,
                issued-by: tx-sender
            })
            
            (map-set property-key-count property (+ (default-to u0 (map-get? property-key-count property)) u1))
            (map-set tenant-active-keys { tenant: tenant, property: property } token-id)
            (var-set next-token-id (+ token-id u1))
            
            (ok token-id))))

;; Revoke access key
(define-public (revoke-access-key (token-id uint))
    (let (
        (key-data (unwrap! (map-get? access-keys token-id) ERR-TOKEN-NOT-FOUND))
    )
        (begin
            (asserts! (is-eq tx-sender (get issued-by key-data)) ERR-NOT-AUTHORIZED)
            (map-set access-keys token-id (merge key-data { active: false }))
            (ok true))))

;; Extend key expiration
(define-public (extend-access-key (token-id uint) (additional-blocks uint))
    (let (
        (key-data (unwrap! (map-get? access-keys token-id) ERR-TOKEN-NOT-FOUND))
    )
        (begin
            (asserts! (is-eq tx-sender (get issued-by key-data)) ERR-NOT-AUTHORIZED)
            (asserts! (get active key-data) ERR-NOT-AUTHORIZED)
            (asserts! (> additional-blocks u0) ERR-INVALID-DURATION)
            
            (map-set access-keys token-id 
                (merge key-data { expires-at: (+ (get expires-at key-data) additional-blocks) }))
            (ok (+ (get expires-at key-data) additional-blocks)))))

;; Read-only functions

;; Check if tenant has valid key
(define-read-only (has-valid-access-key (tenant principal) (property principal))
    (match (map-get? tenant-active-keys { tenant: tenant, property: property })
        token-id 
            (match (map-get? access-keys token-id)
                key-data 
                    (and 
                        (get active key-data)
                        (> (get expires-at key-data) stacks-block-height)
                        (is-eq (get property key-data) property))
                false)
        false))

;; Get key details
(define-read-only (get-access-key-details (token-id uint))
    (map-get? access-keys token-id))

;; Verify access for external systems
(define-read-only (verify-property-access (tenant principal) (property principal))
    (let (
        (has-valid-key (has-valid-access-key tenant property))
    )
        {
            access-granted: has-valid-key,
            verified-at: stacks-block-height,
            tenant: tenant,
            property: property
        }))

;; Get contract info
(define-read-only (get-contract-info)
    {
        total-keys-minted: (- (var-get next-token-id) u1),
        contract-owner: (var-get contract-owner)
    })
