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

;; Data Variables
(define-data-var time-lock uint u0)
(define-data-var required-signatures uint u2)
(define-data-var withdrawal-limit uint u0)
(define-data-var emergency-address principal contract-owner)
(define-data-var withdrawal-nonce uint u0)

;; Data Maps
(define-map balances principal uint)
(define-map signers principal bool)
(define-map pending-withdrawals {id: uint} {amount: uint, recipient: principal, signatures: (list 10 principal)})
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

;; Public Functions
(define-public (deposit (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances tx-sender)))
    )
    (if (> amount u0)
        (begin
            (map-set balances tx-sender (+ current-balance amount))
            (ok true)
        )
        err-invalid-amount
    ))
)

(define-public (initiate-withdrawal (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances tx-sender)))
        (withdrawal-id (var-get withdrawal-nonce))
    )
    (begin
        (asserts! (validate-time-lock) err-time-locked)
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (asserts! (<= amount (var-get withdrawal-limit)) err-invalid-amount)
        
        (map-set pending-withdrawals 
            {id: withdrawal-id}
            {amount: amount, recipient: tx-sender, signatures: (list)}
        )
        (var-set withdrawal-nonce (+ withdrawal-id u1))
        (ok withdrawal-id)
    ))
)

(define-public (sign-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (unwrap! (map-get? pending-withdrawals {id: withdrawal-id}) err-withdrawal-not-found))
    )
    (begin
        (asserts! (validate-time-lock) err-time-locked)
        (try! (has-signed withdrawal-id tx-sender))
        (asserts! (check-authorization tx-sender) err-not-authorized)
        (asserts! (< (len (get signatures withdrawal)) u10) err-max-signatures)
        
        (map-set pending-withdrawals
            {id: withdrawal-id}
            (merge withdrawal {signatures: (append (get signatures withdrawal) tx-sender)})
        )
        
        (if (>= (+ (len (get signatures withdrawal)) u1) (var-get required-signatures))
            (begin
                (try! (withdraw (get amount withdrawal) (get recipient withdrawal)))
                (map-delete pending-withdrawals {id: withdrawal-id})
                (ok true)
            )
            (ok false)
        )
    ))
)

(define-private (withdraw (amount uint) (recipient principal))
    (let (
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
