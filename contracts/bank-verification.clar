;; Bank Verification Contract
;; Manages verification and registration of lending institutions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_BANK_NOT_FOUND (err u101))
(define-constant ERR_BANK_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Bank status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map banks
  { bank-address: principal }
  {
    name: (string-ascii 50),
    license-number: (string-ascii 20),
    status: uint,
    verification-date: uint,
    capital-requirement: uint
  }
)

(define-map bank-admins
  { admin: principal }
  { is-admin: bool }
)

;; Initialize contract owner as admin
(map-set bank-admins { admin: CONTRACT_OWNER } { is-admin: true })

;; Read-only functions
(define-read-only (get-bank (bank-address principal))
  (map-get? banks { bank-address: bank-address })
)

(define-read-only (is-bank-verified (bank-address principal))
  (match (map-get? banks { bank-address: bank-address })
    bank-data (is-eq (get status bank-data) STATUS_VERIFIED)
    false
  )
)

(define-read-only (is-admin (admin principal))
  (default-to false (get is-admin (map-get? bank-admins { admin: admin })))
)

;; Public functions
(define-public (register-bank (name (string-ascii 50)) (license-number (string-ascii 20)) (capital-requirement uint))
  (let ((bank-address tx-sender))
    (asserts! (is-none (map-get? banks { bank-address: bank-address })) ERR_BANK_ALREADY_EXISTS)
    (ok (map-set banks
      { bank-address: bank-address }
      {
        name: name,
        license-number: license-number,
        status: STATUS_PENDING,
        verification-date: block-height,
        capital-requirement: capital-requirement
      }
    ))
  )
)

(define-public (verify-bank (bank-address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? banks { bank-address: bank-address })) ERR_BANK_NOT_FOUND)
    (ok (map-set banks
      { bank-address: bank-address }
      (merge
        (unwrap-panic (map-get? banks { bank-address: bank-address }))
        { status: STATUS_VERIFIED, verification-date: block-height }
      )
    ))
  )
)

(define-public (suspend-bank (bank-address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? banks { bank-address: bank-address })) ERR_BANK_NOT_FOUND)
    (ok (map-set banks
      { bank-address: bank-address }
      (merge
        (unwrap-panic (map-get? banks { bank-address: bank-address }))
        { status: STATUS_SUSPENDED }
      )
    ))
  )
)

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (ok (map-set bank-admins { admin: new-admin } { is-admin: true }))
  )
)
