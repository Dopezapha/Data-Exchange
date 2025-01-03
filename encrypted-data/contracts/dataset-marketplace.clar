;; Data Marketplace Smart Contract
;; Allows users to list, buy, and manage data assets on the Stacks blockchain

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERROR_NOT_CONTRACT_OWNER (err u100))
(define-constant ERROR_DATA_LISTING_NOT_FOUND (err u101))
(define-constant ERROR_DATA_ASSET_ALREADY_EXISTS (err u102))
(define-constant ERROR_BUYER_INSUFFICIENT_BALANCE (err u103))
(define-constant ERROR_UNAUTHORIZED_BUYER (err u104))
(define-constant ERROR_INVALID_LISTING_PRICE (err u105))
(define-constant ERROR_INVALID_PARAMETER (err u106))

;; Data structures
(define-map data-listings 
    { listing-id: uint }
    {
        seller-address: principal,
        listing-price: uint,
        dataset-description: (string-ascii 256),
        dataset-category: (string-ascii 64),
        is-listing-active: bool,
        listing-timestamp: uint
    }
)

(define-map user-marketplace-data
    { marketplace-participant: principal }
    {
        completed-sales-count: uint,
        seller-rating: uint,
        last-interaction-time: uint
    }
)

(define-map completed-purchases
    { buyer-address: principal, purchased-listing-id: uint }
    {
        purchase-timestamp: uint,
        purchase-amount: uint,
        seller-address: principal
    }
)

;; Storage of asset access keys (encrypted off-chain)
(define-map dataset-access-keys
    { listing-id: uint }
    { encrypted-dataset-key: (string-ascii 512) }
)

;; Variables
(define-data-var next-listing-id uint u1)
(define-data-var platform-commission-rate uint u2) ;; 2% platform fee
(define-data-var total-successful-transactions uint u0)

;; Input validation functions
(define-private (validate-description-length (description-text (string-ascii 256)))
    (and 
        (not (is-eq description-text ""))
        (<= (len description-text) u256)
    )
)

(define-private (validate-category-length (category-text (string-ascii 64)))
    (and
        (not (is-eq category-text ""))
        (<= (len category-text) u64)
    )
)

(define-private (validate-access-key-length (access-key (string-ascii 512)))
    (and
        (not (is-eq access-key ""))
        (<= (len access-key) u512)
    )
)

;; Private functions
(define-private (calculate-platform-fee (listing-price uint))
    (/ (* listing-price (var-get platform-commission-rate)) u100)
)

(define-private (execute-stx-transfer (from-address principal) (to-address principal) (payment-amount uint))
    (stx-transfer? payment-amount from-address to-address)
)

;; Public functions

;; List a new data asset
(define-public (create-dataset-listing (listing-price uint) 
                                     (dataset-description (string-ascii 256)) 
                                     (dataset-category (string-ascii 64)) 
                                     (encrypted-dataset-key (string-ascii 512)))
    (let
        (
            (current-listing-id (var-get next-listing-id))
        )
        ;; Input validation
        (asserts! (> listing-price u0) ERROR_INVALID_LISTING_PRICE)
        (asserts! (validate-description-length dataset-description) ERROR_INVALID_PARAMETER)
        (asserts! (validate-category-length dataset-category) ERROR_INVALID_PARAMETER)
        (asserts! (validate-access-key-length encrypted-dataset-key) ERROR_INVALID_PARAMETER)
        (asserts! (not (default-to false (get is-listing-active 
            (map-get? data-listings { listing-id: current-listing-id })))) 
            ERROR_DATA_ASSET_ALREADY_EXISTS)
        
        (map-set data-listings
            { listing-id: current-listing-id }
            {
                seller-address: tx-sender,
                listing-price: listing-price,
                dataset-description: dataset-description,
                dataset-category: dataset-category,
                is-listing-active: true,
                listing-timestamp: block-height
            }
        )
        
        (map-set dataset-access-keys
            { listing-id: current-listing-id }
            { encrypted-dataset-key: encrypted-dataset-key }
        )
        
        (var-set next-listing-id (+ current-listing-id u1))
        (ok current-listing-id)
    )
)

;; Purchase a data asset
(define-public (purchase-dataset (listing-id uint))
    (let
        (
            (listing-details (unwrap! (map-get? data-listings { listing-id: listing-id }) 
                ERROR_DATA_LISTING_NOT_FOUND))
            (total-price (get listing-price listing-details))
            (dataset-seller (get seller-address listing-details))
            (platform-fee (calculate-platform-fee total-price))
            (seller-payment (- total-price platform-fee))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (get is-listing-active listing-details) ERROR_DATA_LISTING_NOT_FOUND)
        (asserts! (is-eq false (is-eq tx-sender dataset-seller)) ERROR_UNAUTHORIZED_BUYER)
        
        ;; Process payments
        (try! (execute-stx-transfer tx-sender dataset-seller seller-payment))
        (try! (execute-stx-transfer tx-sender contract-administrator platform-fee))
        
        ;; Record purchase
        (map-set completed-purchases
            { buyer-address: tx-sender, purchased-listing-id: listing-id }
            {
                purchase-timestamp: block-height,
                purchase-amount: total-price,
                seller-address: dataset-seller
            }
        )
        
        ;; Update seller stats
        (let
            (
                (seller-profile (default-to 
                    { completed-sales-count: u0, seller-rating: u0, last-interaction-time: u0 }
                    (map-get? user-marketplace-data { marketplace-participant: dataset-seller })))
            )
            (map-set user-marketplace-data
                { marketplace-participant: dataset-seller }
                {
                    completed-sales-count: (+ (get completed-sales-count seller-profile) u1),
                    seller-rating: (get seller-rating seller-profile),
                    last-interaction-time: block-height
                }
            )
        )
        
        (var-set total-successful-transactions (+ (var-get total-successful-transactions) u1))
        (ok true)
    )
)

;; Get asset access key (only available to buyer)
(define-public (get-dataset-access-key (listing-id uint))
    (let
        (
            (purchase-record (unwrap! (map-get? completed-purchases 
                { buyer-address: tx-sender, purchased-listing-id: listing-id }) ERROR_UNAUTHORIZED_BUYER))
            (dataset-credentials (unwrap! (map-get? dataset-access-keys 
                { listing-id: listing-id }) ERROR_DATA_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (ok (get encrypted-dataset-key dataset-credentials))
    )
)

;; Update listing price
(define-public (update-listing-price (listing-id uint) (new-price uint))
    (let
        (
            (listing-details (unwrap! (map-get? data-listings { listing-id: listing-id }) 
                ERROR_DATA_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (is-eq (get seller-address listing-details) tx-sender) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (> new-price u0) ERROR_INVALID_LISTING_PRICE)
        
        (map-set data-listings
            { listing-id: listing-id }
            (merge listing-details { listing-price: new-price })
        )
        (ok true)
    )
)

;; Remove listing
(define-public (deactivate-listing (listing-id uint))
    (let
        (
            (listing-details (unwrap! (map-get? data-listings { listing-id: listing-id }) 
                ERROR_DATA_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (is-eq (get seller-address listing-details) tx-sender) ERROR_NOT_CONTRACT_OWNER)
        
        (map-set data-listings
            { listing-id: listing-id }
            (merge listing-details { is-listing-active: false })
        )
        (ok true)
    )
)

;; Admin functions
(define-public (update-platform-fee (new-fee-percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (<= new-fee-percentage u100) ERROR_INVALID_LISTING_PRICE)
        (var-set platform-commission-rate new-fee-percentage)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-listing-details (listing-id uint))
    (map-get? data-listings { listing-id: listing-id })
)

(define-read-only (get-participant-profile (marketplace-participant principal))
    (map-get? user-marketplace-data { marketplace-participant: marketplace-participant })
)

(define-read-only (get-total-completed-transactions)
    (var-get total-successful-transactions)
)

(define-read-only (get-current-platform-fee)
    (var-get platform-commission-rate)
)