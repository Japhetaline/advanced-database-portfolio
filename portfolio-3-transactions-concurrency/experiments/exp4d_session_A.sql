
-- Experiment 4d: Exclusion constraint
-- Session A
-- IMPORTANT: This experiment modifies the real booking table.

BEGIN;

-- Step 2: Check for existing conflicting bookings.
-- Expected: clashes = 0
SELECT count(*) AS clashes
FROM booking
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- PAUSE: Session B must run its BEGIN and availability
-- check before Session A inserts.

-- Step 5: Insert guest 4's booking.
INSERT INTO booking
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    4,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- Expected: INSERT 0 1

-- PAUSE: Session B attempts its conflicting INSERT.
-- It should wait for this transaction to resolve.

-- Step 7: Commit Session A.
COMMIT;

-- Step 10: After Session B has rolled back,
-- remove ONLY the test booking inserted by this experiment.
DELETE FROM booking
WHERE guest_id = 4
  AND room_id = (
      SELECT room_id FROM room WHERE room_number = '101'
  )
  AND check_in = DATE '2026-12-20'
  AND check_out = DATE '2026-12-22';

-- Verify the cleanup.
SELECT guest_id, room_id, check_in, check_out
FROM booking
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20'
AND status <> 'cancelled';
