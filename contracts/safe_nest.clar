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

;; Data Variables
(define-data-var time-lock uint u0)
(define-data-var required-signatures uint u2)
(define-data-var withdrawal-limit uint u0)
(define-data-var emergency-address principal contract-owner)

;; Data Maps
(define-map balances principal uint)
(define-map signers principal bool)
(define-map pending-withdrawals {id: uint} {amount: uint, signatures: uint})
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

(define-public (withdraw (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances tx-sender)))
    )
    (if (and
            (validate-time-lock)
            (>= current-balance amount)
            (<= amount (var-get withdrawal-limit))
        )
        (begin
            (map-set balances tx-sender (- current-balance amount))
            (ok true)
        )
        err-insufficient-balance
    ))
)

(define-public (add-signer (new-signer principal))
    (if (is-eq tx-sender contract-owner)
        (if (default-to false (map-get? signers new-signer))
            err-signer-exists
            (begin
                (map-set signers new-signer true)
                (ok true)
            )
        )
        err-owner-only
    )
)

(define-public (set-time-lock (new-lock uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set time-lock new-lock)
            (ok true)
        )
        err-owner-only
    )
)

(define-public (set-withdrawal-limit (limit uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set withdrawal-limit limit)
            (ok true)
        )
        err-owner-only
    )
)

(define-public (emergency-withdraw (amount uint))
    (if (and
            (is-eq tx-sender (var-get emergency-address))
            (check-authorization tx-sender)
        )
        (let (
            (total-balance (default-to u0 (map-get? balances contract-owner)))
        )
        (if (>= total-balance amount)
            (begin
                (map-set balances contract-owner (- total-balance amount))
                (ok true)
            )
            err-insufficient-balance
        ))
        err-not-authorized
    )
)

;; Read Only Functions
(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? balances user)))
)

(define-read-only (is-signer (user principal))
    (ok (default-to false (map-get? signers user)))
)

(define-read-only (get-time-lock)
    (ok (var-get time-lock))
)

(define-read-only (get-withdrawal-limit)
    (ok (var-get withdrawal-limit))
)