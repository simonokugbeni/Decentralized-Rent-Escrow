;; Property Analytics & Market Intelligence Contract

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PROPERTY-NOT-FOUND (err u501))
(define-constant ERR-INVALID-DATA (err u502))
(define-constant ERR-INSUFFICIENT-DATA (err u503))
(define-constant ERR-NEIGHBORHOOD-NOT-FOUND (err u504))

;; Data Maps for property performance tracking
(define-map property-analytics
    principal
    {
        rent-per-sqft: uint,
        vacancy-days: uint,
        tenant-turnover-rate: uint,
        maintenance-costs: uint,
        property-age: uint,
        amenity-score: uint,
        last-updated: uint,
        data-points: uint
    }
)

;; Neighborhood market data
(define-map neighborhood-data
    (string-ascii 64)
    {
        avg-rent: uint,
        median-rent: uint,
        occupancy-rate: uint,
        price-trend: int,
        demand-score: uint,
        total-properties: uint,
        last-quarter-growth: int,
        market-activity: uint
    }
)

;; Market trends and predictions
(define-map market-predictions
    (string-ascii 64)
    {
        predicted-growth-6m: int,
        predicted-growth-12m: int,
        risk-score: uint,
        investment-rating: uint,
        confidence-level: uint,
        trend-direction: (string-ascii 16),
        last-calculated: uint
    }
)

;; Property comparison metrics
(define-map property-rankings
    principal
    {
        roi-score: uint,
        market-position: uint,
        appreciation-potential: uint,
        rental-yield: uint,
        overall-grade: (string-ascii 8),
        percentile-rank: uint
    }
)

;; Historical rent data for trend analysis
(define-map rent-history
    principal
    (list 24 {
        month: uint,
        rent-amount: uint,
        occupancy-status: bool
    })
)

;; Neighborhood amenity scores
(define-map amenity-index
    (string-ascii 64)
    {
        transit-score: uint,
        safety-score: uint,
        school-rating: uint,
        shopping-score: uint,
        restaurant-score: uint,
        overall-livability: uint
    }
)

;; Data variables for global market tracking
(define-data-var total-properties-tracked uint u0)
(define-data-var market-update-frequency uint u144)
(define-data-var analytics-oracle principal tx-sender)

;; Initialize neighborhood with basic data
(define-public (initialize-neighborhood (neighborhood (string-ascii 64)) (initial-avg-rent uint))
    (begin
        (asserts! (> initial-avg-rent u0) ERR-INVALID-DATA)
        (ok (map-set neighborhood-data neighborhood
            {
                avg-rent: initial-avg-rent,
                median-rent: initial-avg-rent,
                occupancy-rate: u85,
                price-trend: 0,
                demand-score: u50,
                total-properties: u0,
                last-quarter-growth: 0,
                market-activity: u50
            }))))

;; Add property analytics data
(define-public (add-property-analytics (property principal) (rent-per-sqft uint) (property-age uint) (amenity-score uint))
    (let (
        (current-data (default-to {
            rent-per-sqft: u0,
            vacancy-days: u0,
            tenant-turnover-rate: u0,
            maintenance-costs: u0,
            property-age: u0,
            amenity-score: u0,
            last-updated: u0,
            data-points: u0
        } (map-get? property-analytics property)))
    )
        (begin
            (asserts! (> rent-per-sqft u0) ERR-INVALID-DATA)
            (asserts! (<= amenity-score u100) ERR-INVALID-DATA)
            (var-set total-properties-tracked (+ (var-get total-properties-tracked) u1))
            (ok (map-set property-analytics property
                {
                    rent-per-sqft: rent-per-sqft,
                    vacancy-days: (get vacancy-days current-data),
                    tenant-turnover-rate: (get tenant-turnover-rate current-data),
                    maintenance-costs: (get maintenance-costs current-data),
                    property-age: property-age,
                    amenity-score: amenity-score,
                    last-updated: stacks-block-height,
                    data-points: (+ (get data-points current-data) u1)
                })))))

;; Update vacancy tracking
(define-public (update-vacancy-data (property principal) (days-vacant uint))
    (let (
        (current-data (unwrap! (map-get? property-analytics property) ERR-PROPERTY-NOT-FOUND))
    )
        (ok (map-set property-analytics property
            (merge current-data {
                vacancy-days: (+ (get vacancy-days current-data) days-vacant),
                last-updated: stacks-block-height
            })))))

;; Record tenant turnover
(define-public (record-tenant-turnover (property principal))
    (let (
        (current-data (unwrap! (map-get? property-analytics property) ERR-PROPERTY-NOT-FOUND))
        (new-turnover-rate (+ (get tenant-turnover-rate current-data) u1))
    )
        (ok (map-set property-analytics property
            (merge current-data {
                tenant-turnover-rate: new-turnover-rate,
                last-updated: stacks-block-height
            })))))

;; Add maintenance cost data
(define-public (add-maintenance-cost (property principal) (cost uint))
    (let (
        (current-data (unwrap! (map-get? property-analytics property) ERR-PROPERTY-NOT-FOUND))
    )
        (ok (map-set property-analytics property
            (merge current-data {
                maintenance-costs: (+ (get maintenance-costs current-data) cost),
                last-updated: stacks-block-height
            })))))

;; Update neighborhood market data
(define-public (update-neighborhood-data (neighborhood (string-ascii 64)) (avg-rent uint) (occupancy-rate uint) (demand-score uint))
    (let (
        (current-data (unwrap! (map-get? neighborhood-data neighborhood) ERR-NEIGHBORHOOD-NOT-FOUND))
        (price-change (- (to-int avg-rent) (to-int (get avg-rent current-data))))
        (growth-percentage (if (> (get avg-rent current-data) u0)
            (/ (* price-change 100) (to-int (get avg-rent current-data)))
            0))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get analytics-oracle)) ERR-NOT-AUTHORIZED)
            (asserts! (<= occupancy-rate u100) ERR-INVALID-DATA)
            (ok (map-set neighborhood-data neighborhood
                (merge current-data {
                    avg-rent: avg-rent,
                    median-rent: (/ (+ avg-rent (get median-rent current-data)) u2),
                    occupancy-rate: occupancy-rate,
                    price-trend: growth-percentage,
                    demand-score: demand-score,
                    last-quarter-growth: growth-percentage,
                    market-activity: (/ (+ demand-score occupancy-rate) u2)
                }))))))

;; Calculate property ROI score
(define-public (calculate-property-roi (property principal) (purchase-price uint) (annual-income uint))
    (let (
        (analytics-data (unwrap! (map-get? property-analytics property) ERR-PROPERTY-NOT-FOUND))
        (annual-maintenance (get maintenance-costs analytics-data))
        (net-income (if (> annual-income annual-maintenance) (- annual-income annual-maintenance) u0))
        (roi-percentage (if (> purchase-price u0) (/ (* net-income u100) purchase-price) u0))
        (vacancy-penalty (/ (get vacancy-days analytics-data) u3))
        (adjusted-roi (if (> roi-percentage vacancy-penalty) (- roi-percentage vacancy-penalty) u0))
    )
        (begin
            (map-set property-rankings property
                {
                    roi-score: adjusted-roi,
                    market-position: u50,
                    appreciation-potential: u50,
                    rental-yield: (/ (* annual-income u100) purchase-price),
                    overall-grade: (if (> adjusted-roi u12) "A"
                        (if (> adjusted-roi u8) "B"
                            (if (> adjusted-roi u5) "C" "D"))),
                    percentile-rank: u50
                })
            (ok adjusted-roi))))

;; Generate market predictions for neighborhood
(define-public (generate-market-prediction (neighborhood (string-ascii 64)))
    (let (
        (market-data (unwrap! (map-get? neighborhood-data neighborhood) ERR-NEIGHBORHOOD-NOT-FOUND))
        (current-trend (get price-trend market-data))
        (demand (get demand-score market-data))
        (occupancy (get occupancy-rate market-data))
        (stability-factor (/ (+ demand occupancy) u2))
        (growth-6m (* current-trend 6))
        (growth-12m (* current-trend 12))
        (risk-score (if (< stability-factor u60) u80 
            (if (< stability-factor u80) u40 u20)))
        (investment-rating (/ (+ stability-factor (- u100 risk-score)) u2))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get analytics-oracle)) ERR-NOT-AUTHORIZED)
            (ok (map-set market-predictions neighborhood
                {
                    predicted-growth-6m: growth-6m,
                    predicted-growth-12m: growth-12m,
                    risk-score: risk-score,
                    investment-rating: investment-rating,
                    confidence-level: (/ stability-factor u2),
                    trend-direction: (if (> current-trend 0) "up" 
                        (if (< current-trend 0) "down" "stable")),
                    last-calculated: stacks-block-height
                })))))

;; Add rent history entry
(define-public (add-rent-history (property principal) (month uint) (rent-amount uint) (occupied bool))
    (let (
        (current-history (default-to (list) (map-get? rent-history property)))
        (new-entry { month: month, rent-amount: rent-amount, occupancy-status: occupied })
    )
        (ok (map-set rent-history property
            (if (>= (len current-history) u24)
                (unwrap-panic (as-max-len? (append (unwrap-panic (slice? current-history u1 u24)) new-entry) u24))
                (unwrap-panic (as-max-len? (append current-history new-entry) u24)))))))

;; Calculate property appreciation trend
(define-public (calculate-appreciation-trend (property principal))
    (let (
        (history (unwrap! (map-get? rent-history property) ERR-PROPERTY-NOT-FOUND))
        (history-length (len history))
    )
        (if (>= history-length u6)
            (let (
                (recent-avg (/ (fold + (map get-rent-amount (unwrap-panic (slice? history (- history-length u3) history-length))) u0) u3))
                (older-avg (/ (fold + (map get-rent-amount (unwrap-panic (slice? history u0 u3))) u0) u3))
                (appreciation-rate (if (> older-avg u0) (/ (* (- recent-avg older-avg) u100) older-avg) u0))
            )
                (ok appreciation-rate))
            ERR-INSUFFICIENT-DATA)))

;; Set amenity scores for neighborhood
(define-public (set-neighborhood-amenities (neighborhood (string-ascii 64)) (transit uint) (safety uint) (schools uint) (shopping uint) (restaurants uint))
    (let (
        (overall-score (/ (+ transit safety schools shopping restaurants) u5))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get analytics-oracle)) ERR-NOT-AUTHORIZED)
            (asserts! (<= transit u100) ERR-INVALID-DATA)
            (asserts! (<= safety u100) ERR-INVALID-DATA)
            (ok (map-set amenity-index neighborhood
                {
                    transit-score: transit,
                    safety-score: safety,
                    school-rating: schools,
                    shopping-score: shopping,
                    restaurant-score: restaurants,
                    overall-livability: overall-score
                })))))

;; Helper function for rent amount extraction
(define-private (get-rent-amount (entry { month: uint, rent-amount: uint, occupancy-status: bool }))
    (get rent-amount entry))

;; Read-only functions for querying analytics

(define-read-only (get-property-analytics (property principal))
    (map-get? property-analytics property))

(define-read-only (get-neighborhood-data (neighborhood (string-ascii 64)))
    (map-get? neighborhood-data neighborhood))

(define-read-only (get-market-prediction (neighborhood (string-ascii 64)))
    (map-get? market-predictions neighborhood))

(define-read-only (get-property-ranking (property principal))
    (map-get? property-rankings property))

(define-read-only (get-rent-history (property principal))
    (map-get? rent-history property))

(define-read-only (get-amenity-scores (neighborhood (string-ascii 64)))
    (map-get? amenity-index neighborhood))

(define-read-only (get-total-properties-tracked)
    (var-get total-properties-tracked))

;; Calculate comparative property score against neighborhood
(define-read-only (get-property-vs-market (property principal) (neighborhood (string-ascii 64)))
    (match (map-get? property-analytics property)
        property-data (match (map-get? neighborhood-data neighborhood)
            market-data (some {
                above-market-rent: (> (get rent-per-sqft property-data) (/ (get avg-rent market-data) u100)),
                vacancy-vs-avg: (< (get vacancy-days property-data) u30),
                maintenance-efficiency: (< (get maintenance-costs property-data) u5000),
                market-alignment: (> (get amenity-score property-data) u70)
            })
            none)
        none))

;; Get investment recommendation
(define-read-only (get-investment-recommendation (neighborhood (string-ascii 64)))
    (match (map-get? market-predictions neighborhood)
        prediction-data (some {
            recommendation: (if (> (get investment-rating prediction-data) u70) "BUY"
                (if (> (get investment-rating prediction-data) u40) "HOLD" "SELL")),
            confidence: (get confidence-level prediction-data),
            expected-return: (get predicted-growth-12m prediction-data),
            risk-level: (if (< (get risk-score prediction-data) u30) "LOW"
                (if (< (get risk-score prediction-data) u70) "MEDIUM" "HIGH"))
        })
        none))


