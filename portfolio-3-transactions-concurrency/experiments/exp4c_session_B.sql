
-- Experiment 4c: SERIALIZABLE isolation
-- Session B

-- Step 3: Start a SERIALIZABLE transaction.
BEGIN ISOLATION LEVEL SERIALIZABLE;

-- Step 4: Check availability before Session A commits.
-- Expected: clashes = 0
SELECT count(*) AS clashes
FROM booking_demo
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- Step 6: Attempt to insert guest 7's booking.
INSERT INTO booking_demo
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    7,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- IMPORTANT:
-- The INSERT or COMMIT may fail with SQLSTATE 40001.
-- If the INSERT succeeds, coordinate with Session A,
-- which should attempt COMMIT first.

COMMIT;

-- If PostgreSQL reports a serialization failure,
-- do not continue with further statements in the
-- failed transaction. Issue ROLLBACK if required.
