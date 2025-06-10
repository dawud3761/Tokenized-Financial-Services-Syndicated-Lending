;; Loan Syndication Contract
;; Manages loan creation and syndication process

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_LOAN_NOT_FOUND (err u301))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u302))
(define-constant ERR_INVALID_AMOUNT (err u303))
(define-constant ERR_LOAN_NOT_ACTIVE (err u304))

;; Loan status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_FUNDED u2)
(define-constant STATUS_CLOSED u3)
(define-constant STATUS_DEFAULTED u4)

;; Data structures
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lead-arranger: principal,
    principal-amount: uint,
    interest-rate: uint,
    term-months: uint,
    status: uint,
    creation-date: uint,
    funding-deadline: uint,
    total-funded: uint
  }
)

(define-map loan-terms
  { loan-id: uint }
  {
    purpose: (string-ascii 100),
    collateral-type: (string-ascii 50),
    collateral-value: uint,
    debt-service-coverage: uint,
    loan-to-value: uint
  }
)

(define-data-var next-loan-id uint u1)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-loan-terms (loan-id uint))
  (map-get? loan-terms { loan-id: loan-id })
)

(define-read-only (get-next-loan-id)
  (var-get next-loan-id)
)

;; Public functions
(define-public (create-loan
  (borrower principal)
  (principal-amount uint)
  (interest-rate uint)
  (term-months uint)
  (funding-deadline uint)
  (purpose (string-ascii 100))
  (collateral-type (string-ascii 50))
  (collateral-value uint)
)
  (let ((loan-id (var-get next-loan-id)))
    (asserts! (> principal-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> interest-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (> term-months u0) ERR_INVALID_AMOUNT)

    (map-set loans
      { loan-id: loan-id }
      {
        borrower: borrower,
        lead-arranger: tx-sender,
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        term-months: term-months,
        status: STATUS_PENDING,
        creation-date: block-height,
        funding-deadline: funding-deadline,
        total-funded: u0
      }
    )

    (map-set loan-terms
      { loan-id: loan-id }
      {
        purpose: purpose,
        collateral-type: collateral-type,
        collateral-value: collateral-value,
        debt-service-coverage: (/ collateral-value principal-amount),
        loan-to-value: (/ (* principal-amount u100) collateral-value)
      }
    )

    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (activate-loan (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get lead-arranger loan-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan-data) STATUS_PENDING) ERR_LOAN_NOT_ACTIVE)

    (ok (map-set loans
      { loan-id: loan-id }
      (merge loan-data { status: STATUS_ACTIVE })
    ))
  )
)

(define-public (fund-loan (loan-id uint) (amount uint))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get status loan-data) STATUS_ACTIVE) ERR_LOAN_NOT_ACTIVE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let ((new-total (+ (get total-funded loan-data) amount)))
      (ok (map-set loans
        { loan-id: loan-id }
        (merge loan-data
          {
            total-funded: new-total,
            status: (if (>= new-total (get principal-amount loan-data)) STATUS_FUNDED STATUS_ACTIVE)
          }
        )
      ))
    )
  )
)

(define-public (close-loan (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get lead-arranger loan-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan-data) STATUS_FUNDED) ERR_LOAN_NOT_ACTIVE)

    (ok (map-set loans
      { loan-id: loan-id }
      (merge loan-data { status: STATUS_CLOSED })
    ))
  )
)
