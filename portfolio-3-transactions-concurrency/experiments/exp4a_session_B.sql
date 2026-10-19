
-- Experiment 4a: Double booking without protection
-- Session B
-- Run commands in the indicated order.

-- Step 3: Start Session B's transaction.
BEGIN;

-- Step 4: Check availability BEFORE Session A commits.
-- Expected: clashes = 0
SELECT count(*) AS clashes
FROM booking_demo
WHERE room_id = (
    SELECT room_id
    FROM room
    WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- PAUSE: Let Session A insert its booking first.

-- Step 6: Insert the second booking.
INSERT INTO booking_demo
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    7,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- Expected: INSERT 0 1

-- PAUSE: Session A must commit first.

-- Step 8: Commit the second booking.
COMMIT;
