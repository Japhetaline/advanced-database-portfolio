
-- Experiment 4d: Exclusion constraint
-- Session B
-- IMPORTANT: This experiment modifies the real booking table.

BEGIN;

-- Step 3: Check availability before Session A commits.
-- Expected: clashes = 0
SELECT count(*) AS clashes
FROM booking
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- PAUSE: Wait until Session A inserts its booking.

-- Step 6: Attempt the conflicting booking.
INSERT INTO booking
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    7,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- Expected: This INSERT waits while Session A's
-- conflicting insert is uncommitted.
--
-- After Session A commits, expect SQLSTATE 23P01
-- if the no_double_booking constraint applies.

-- Step 9: If the INSERT fails, clear the transaction.
ROLLBACK;
