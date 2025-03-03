;; SafeNest - Secure Digital Asset Management
(define-trait safe-nest-trait
    (
        (deposit (uint) (response bool uint))
        (withdraw (uint) (response bool uint)) 
        (add-signer (principal) (response bool uint))
    )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-time-locked (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-signer-exists (err u105))
(define-constant err-withdrawal-exists (err u106))
(define-constant err-withdrawal-not-found (err u107))
(define-constant err-already-signed (err u108))
(define-constant err-max-signatures (err u109))
(define-constant err-zero-address (err u110))
(define-constant err-expired-request (err u111))

;; Data Variables
(define-data-var time-lock uint u0)
(define-data-var required-signatures uint u2)
(define-data-var withdrawal-limit uint u0)
(define-data-var emergency-address principal contract-owner)
(define-data-var withdrawal-nonce uint u0)
(define-data-var max-pending-withdrawals uint u100)

;; Data Maps
(define-map balances principal uint)
(define-map signers principal bool)
(define-map pending-withdrawals 
    {id: uint} 
    {
        amount: uint, 
        recipient: principal, 
        signatures: (list 10 principal),
        expiration: uint
    }
)
(define-map allowances {owner: principal, spender: principal} uint)

;; Private Functions
(define-private (validate-time-lock)
    (if (<= (var-get time-lock) block-height)
        true
        false
    )
)

(define-private (check-authorization (user principal))
    (default-to false (map-get? signers user))
)

(define-private (has-signed (withdrawal-id uint) (signer principal))
    (match (map-get? pending-withdrawals {id: withdrawal-id})
        withdrawal (asserts! (is-none (index-of? (get signatures withdrawal) signer)) err-already-signed)
        err-withdrawal-not-found
    )
)

(define-private (validate-withdrawal-request (withdrawal-id uint))
    (match (map-get? pending-withdrawals {id: withdrawal-id})
        withdrawal (begin
            (asserts! (< block-height (get expiration withdrawal)) err-expired-request)
            (ok withdrawal)
        )
        err-withdrawal-not-found
    )
)

;; Public Functions
(define-public (deposit (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances tx-sender)))
    )
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (map-set balances tx-sender (+ current-balance amount))
        (ok true)
    ))
)

(define-public (initiate-withdrawal (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances tx-sender)))
        (withdrawal-id (var-get withdrawal-nonce))
    )
    (begin
        (asserts! (validate-time-lock) err-time-locked)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (asserts! (<= amount (var-get withdrawal-limit)) err-invalid-amount)
        
        (map-set pending-withdrawals 
            {id: withdrawal-id}
            {
                amount: amount, 
                recipient: tx-sender, 
                signatures: (list),
                expiration: (+ block-height u144)  ;; 24 hour expiration
            }
        )
        (var-set withdrawal-nonce (+ withdrawal-id u1))
        (ok withdrawal-id)
    ))
)

(define-public (cancel-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (try! (validate-withdrawal-request withdrawal-id)))
    )
    (begin
        (asserts! (is-eq tx-sender (get recipient withdrawal)) err-not-authorized)
        (map-delete pending-withdrawals {id: withdrawal-id})
        (ok true)
    ))
)

(define-public (sign-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (try! (validate-withdrawal-request withdrawal-id)))
    )
    (begin
        (try! (has-signed withdrawal-id tx-sender))
        (asserts! (check-authorization tx-sender) err-not-authorized)
        (asserts! (< (len (get signatures withdrawal)) u10) err-max-signatures)
        
        (map-set pending-withdrawals
            {id: withdrawal-id}
            (merge withdrawal {signatures: (append (get signatures withdrawal) tx-sender)})
        )
        
        (if (>= (+ (len (get signatures withdrawal)) u1) (var-get required-signatures))
            (begin
                (try! (withdraw withdrawal-id))
                (map-delete pending-withdrawals {id: withdrawal-id})
                (ok true)
            )
            (ok false)
        )
    ))
)

(define-private (withdraw (withdrawal-id uint))
    (let (
        (withdrawal (unwrap! (map-get? pending-withdrawals {id: withdrawal-id}) err-withdrawal-not-found))
        (recipient (get recipient withdrawal))
        (amount (get amount withdrawal))
        (current-balance (default-to u0 (map-get? balances recipient)))
    )
    (begin
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (map-set balances recipient (- current-balance amount))
        (ok true)
    ))
)

(define-public (add-signer (new-signer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (is-eq new-signer contract-owner)) err-zero-address)
        (asserts! (is-none (map-get? signers new-signer)) err-signer-exists)
        (map-set signers new-signer true)
        (ok true)
    )
)

;; Read Only Functions
(define-read-only (get-pending-withdrawal (withdrawal-id uint))
    (ok (map-get? pending-withdrawals {id: withdrawal-id}))
)

(define-read-only (get-required-signatures)
    (ok (var-get required-signatures))
)

(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? balances user)))
)

(define-read-only (get-time-lock-status)
    (ok (validate-time-lock))
)
