# Phase 1 schema review (applied to `V1__core_schema.sql`)

V1 has not been deployed anywhere, so it was edited in place rather than adding V2. Still 32 tables, plus one consistency view.

## A. Requested changes
| # | Change | How |
|---|---|---|
| 1 | Booking slot must belong to the booking's exam | `exam_slots` gets `UNIQUE (id, examination_id)`. `exam_bookings` FK `(slot_id, examination_id) -> exam_slots(id, examination_id)` replaces the two single FKs. |
| 2 | Attendance must match its booking | `exam_bookings` gets `UNIQUE (id, examination_id, slot_id, student_id)`. `exam_attendance` FK `(booking_id, examination_id, slot_id, student_id)` references it; the three separate FKs were removed. Side effect (wanted): a booking cannot be moved to another slot after attendance exists. Also added: MANUAL attendance requires `recorded_by`. |
| 3 | Capacity hard limit | `CHECK (capacity BETWEEN 1 AND 20)`, default stays 20. Raising the limit later needs a migration. |
| 4 | Material category in same subject | `material_categories` gets `UNIQUE (id, subject_id)`; `learning_materials` FK `(category_id, subject_id)`. A NULL category skips the check. |
| 5 | Application subjects in the application's year | `application_subjects` gains `academic_year_id`; two composite FKs force it to equal both the application's year and the subject's year (`student_applications` and `subjects` each gain `UNIQUE (id, academic_year_id)`). |
| 6 | Password hash | `users.password_hash VARCHAR(255)`. |
| 7 | Permissions | 46 permissions and role mappings seeded. See `docs/PERMISSIONS.md`. |
| 8 | QR secrets at rest | `signing_secret` removed. Table stores `key_salt` (random, not secret) and `key_version`. The HMAC key is derived at runtime from `QR_MASTER_KEY` (environment variable, never in the DB): `HKDF(master, salt, session id)`. A database leak alone cannot forge QR codes. Rotating the master key only invalidates short-lived sessions. |

## B. Additional review findings and fixes
**Student ID sequence.** The old plan (`SELECT ... FOR UPDATE` on the year's row) fails for the first approval of a year because no row exists to lock, and locking a missing row can deadlock. Use one atomic statement inside the approval transaction:
```sql
INSERT INTO student_id_sequences (year_number, last_no) VALUES (?, LAST_INSERT_ID(1))
  ON DUPLICATE KEY UPDATE last_no = LAST_INSERT_ID(last_no + 1);
SELECT LAST_INSERT_ID();   -- code = year || 'STU' || zero-pad(n, 3)
```
The row lock lasts until commit and a rollback reverts the increment, so there are no gaps or duplicates. Added `CHECK student_code REGEXP '^[0-9]{4}STU[0-9]{3,}$'` and the existing unique key as backstops.

**Booking counter.** `booked_count` stays (fast display, capacity guard) but has one writer: the booking service, using atomic conditional updates in the same transaction as the booking row:
```sql
-- book:   0 rows updated = slot full/closed
UPDATE exam_slots SET booked_count = booked_count + 1
 WHERE id = ? AND examination_id = ? AND status = 'OPEN' AND booked_count < capacity;
-- cancel: UPDATE exam_slots SET booked_count = booked_count - 1 WHERE id = ? AND booked_count > 0;
```
Admin move = decrement old + increment new, locking slots in ascending id order to avoid deadlocks (retry on deadlock). Safety nets: `CHECK booked_count <= capacity`, unsigned column, and new view `v_slot_booking_drift`, which must always return zero rows (asserted in tests). Database triggers were considered and rejected: on MySQL with binary logging (the Docker default) a non-SUPER user cannot create them without extra server settings, which adds fragile setup for little gain.

**Grade boundaries.** Replaced `min_percent/max_percent` with `min_percent` only. A grade covers its lower bound up to the next boundary, so overlaps and gaps are impossible by construction. Unique `(configuration, min_percent)` and `(configuration, grade)`; at most one active scale (generated-column unique key). The service must verify a `0.00` boundary exists before activating a scale. Seed grade `W` renamed to `F` (A/L style), still just data.

**Result validation.**
- `exam_results.total_marks` must equal the exam's `total_marks` via composite FK, so the exam's total can't be edited once results exist (intended).
- CHECKs: marks within `0..total`; `percentage = ROUND(marks*100/total, 2)` (Java must use HALF_UP); absent rows have no marks or grade; a PUBLISHED row needs publisher, time, and grade (unless absent).
- The stored `(grade_configuration_id, grade)` must exist in `grade_boundaries`.
- Service-level (not expressible in SQL): student has a confirmed booking for the exam and is enrolled in its subject.

**Atomic approval.** All of this runs in a single `@Transactional` method; any failure rolls back everything:
1. Lock the application (`SELECT ... FOR UPDATE`), require `PENDING`.
2. Allocate the student ID (above).
3. Insert `users` (PENDING, no password), `students`, `student_guardians`.
4. Insert `student_enrollments` from `application_subjects`.
5. Insert `password_tokens` (hashed), an `email_outbox` row, a notification, an `audit_logs` row.
6. Mark the application `APPROVED`.
Email is sent after commit by an outbox worker, never inside the transaction. `students.application_id UNIQUE` and `student_code UNIQUE` stop a double approval even if two admins click at once.

## C. Open decision
**Returning students (A or B)** is still unanswered. Until you say otherwise I assume **A: one student record and ID for life, new enrolments per year**. The schema already supports A. For A, approving a later application for a known email adds enrolments and no new user. Option B (new ID per year) would need `students.email` and `users.email` uniqueness changed. Please confirm before Phase 3.

## D. Validation status
Checked with a script I wrote: all 32 tables parse, every FK target exists earlier and is a unique key, no CHECK/FK combination hits MySQL error 3823, every permission code is defined. **Not yet run on real MySQL.** Please run step 6 of `docs/SETUP.md`.
