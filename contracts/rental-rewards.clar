(define-fungible-token reward-token)

(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-STREAK-NOT-FOUND (err u403))

(define-map reward-balances principal uint)

(define-map payment-streaks
    principal
    {
        current-streak: uint,
        longest-streak: uint,
        last-payment-block: uint,
        total-rewards-earned: uint
    }
)

(define-map maintenance-rewards
    principal
    {
        completed-tasks: uint,
        quality-score: uint,
        bonus-multiplier: uint
    }
)

(define-map reward-levels
    uint
    {
        level-name: (string-ascii 32),
        min-streak: uint,
        reward-multiplier: uint,
        special-perks: (string-ascii 128)
    }
)

(define-map monthly-leaderboard
    uint
    (list 10 {
        user: principal,
        score: uint,
        reward-earned: uint
    })
)

(define-data-var current-month uint u0)
(define-data-var base-reward-amount uint u100)
(define-data-var streak-bonus-multiplier uint u50)

(define-public (initialize-reward-levels)
    (begin
        (map-set reward-levels u1 {
            level-name: "Bronze Tenant",
            min-streak: u3,
            reward-multiplier: u110,
            special-perks: "5% discount on late fees"
        })
        (map-set reward-levels u2 {
            level-name: "Silver Tenant",
            min-streak: u6,
            reward-multiplier: u125,
            special-perks: "Priority maintenance requests"
        })
        (map-set reward-levels u3 {
            level-name: "Gold Tenant",
            min-streak: u12,
            reward-multiplier: u150,
            special-perks: "Rent increase immunity for 6 months"
        })
        (map-set reward-levels u4 {
            level-name: "Platinum Tenant",
            min-streak: u24,
            reward-multiplier: u200,
            special-perks: "Free property upgrades up to 1000 STX"
        })
        (ok true)))

(define-public (record-on-time-payment (tenant principal))
    (let (
        (current-streak-data (default-to {
            current-streak: u0,
            longest-streak: u0,
            last-payment-block: u0,
            total-rewards-earned: u0
        } (map-get? payment-streaks tenant)))
        (new-streak (+ (get current-streak current-streak-data) u1))
        (base-reward (var-get base-reward-amount))
        (streak-bonus (/ (* base-reward (get current-streak current-streak-data) (var-get streak-bonus-multiplier)) u100))
        (total-reward (+ base-reward streak-bonus))
        (new-longest (if (> new-streak (get longest-streak current-streak-data))
            new-streak
            (get longest-streak current-streak-data)))
    )
        (begin
            (try! (ft-mint? reward-token total-reward tenant))
            (map-set reward-balances tenant 
                (+ (default-to u0 (map-get? reward-balances tenant)) total-reward))
            (map-set payment-streaks tenant {
                current-streak: new-streak,
                longest-streak: new-longest,
                last-payment-block: stacks-block-height,
                total-rewards-earned: (+ (get total-rewards-earned current-streak-data) total-reward)
            })
            (ok total-reward))))

(define-public (record-maintenance-completion (user principal) (quality-rating uint))
    (let (
        (current-maintenance (default-to {
            completed-tasks: u0,
            quality-score: u0,
            bonus-multiplier: u100
        } (map-get? maintenance-rewards user)))
        (new-completed (+ (get completed-tasks current-maintenance) u1))
        (new-quality-score (/ (+ (* (get quality-score current-maintenance) (get completed-tasks current-maintenance)) quality-rating) new-completed))
        (quality-bonus (if (> new-quality-score u80) u50 u0))
        (reward-amount (+ (var-get base-reward-amount) quality-bonus))
        (new-multiplier (if (> new-completed u10) u125 u100))
    )
        (begin
            (try! (ft-mint? reward-token reward-amount user))
            (map-set reward-balances user 
                (+ (default-to u0 (map-get? reward-balances user)) reward-amount))
            (map-set maintenance-rewards user {
                completed-tasks: new-completed,
                quality-score: new-quality-score,
                bonus-multiplier: new-multiplier
            })
            (ok reward-amount))))

(define-public (break-payment-streak (tenant principal))
    (let (
        (current-streak-data (unwrap! (map-get? payment-streaks tenant) ERR-STREAK-NOT-FOUND))
    )
        (ok (map-set payment-streaks tenant
            (merge current-streak-data { current-streak: u0 })))))

(define-public (redeem-rewards (amount uint) (recipient principal))
    (let (
        (current-balance (default-to u0 (map-get? reward-balances tx-sender)))
    )
        (begin
            (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (try! (ft-transfer? reward-token amount tx-sender recipient))
            (map-set reward-balances tx-sender (- current-balance amount))
            (ok true))))

(define-public (transfer-rewards (amount uint) (recipient principal))
    (let (
        (sender-balance (default-to u0 (map-get? reward-balances tx-sender)))
    )
        (begin
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (try! (ft-transfer? reward-token amount tx-sender recipient))
            (map-set reward-balances tx-sender (- sender-balance amount))
            (map-set reward-balances recipient 
                (+ (default-to u0 (map-get? reward-balances recipient)) amount))
            (ok true))))

(define-public (update-monthly-leaderboard (user principal) (score uint))
    (let (
        (current-month-val (var-get current-month))
        (current-leaderboard (default-to (list) (map-get? monthly-leaderboard current-month-val)))
        (reward-earned (/ (* score (var-get base-reward-amount)) u100))
        (new-entry { user: user, score: score, reward-earned: reward-earned })
    )
        (begin
            (try! (ft-mint? reward-token reward-earned user))
            (map-set reward-balances user 
                (+ (default-to u0 (map-get? reward-balances user)) reward-earned))
            (map-set monthly-leaderboard current-month-val
                (unwrap-panic (as-max-len? (append current-leaderboard new-entry) u10)))
            (ok true))))

(define-public (advance-month)
    (begin
        (var-set current-month (+ (var-get current-month) u1))
        (ok true)))

(define-public (calculate-user-level (user principal))
    (let (
        (streak-data (map-get? payment-streaks user))
        (current-streak (match streak-data
            data (get current-streak data)
            u0))
    )
        (if (>= current-streak u24)
            (ok u4)
            (if (>= current-streak u12)
                (ok u3)
                (if (>= current-streak u6)
                    (ok u2)
                    (if (>= current-streak u3)
                        (ok u1)
                        (ok u0)))))))

(define-read-only (get-reward-balance (user principal))
    (default-to u0 (map-get? reward-balances user)))

(define-read-only (get-payment-streak (user principal))
    (map-get? payment-streaks user))

(define-read-only (get-maintenance-rewards (user principal))
    (map-get? maintenance-rewards user))

(define-read-only (get-reward-level (level uint))
    (map-get? reward-levels level))

(define-read-only (get-monthly-leaderboard (month uint))
    (map-get? monthly-leaderboard month))

(define-read-only (get-user-level (user principal))
    (unwrap-panic (calculate-user-level user)))
(define-read-only (get-total-supply)
    (ft-get-supply reward-token))

(define-read-only (get-balance (user principal))
    (ft-get-balance reward-token user))
