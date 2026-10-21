
-- Experiment 4c: SERIALIZABLE isolation
-- Session A

-- Step 1: Start a SERIALIZABLE transaction.
BEGIN ISOLATION LEVEL SERIALIZABLE;

-- Step 2: Check availability.
-- Expected: clashes = 0
SELECT count(*) AS clashes
FROM booking_demo
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- PAUSE: Session B must also start a SERIALIZABLE
-- transaction and run its availability check.

-- Step 5: Insert guest 4's booking.
INSERT INTO booking_demo
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    4,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- PAUSE: Coordinate with Session B.
-- Ensure both transactions have checked availability
-- and attempted their inserts before committing.

-- Step 7: Commit Session A first.
COMMIT;

-- Verify the surviving booking after Session B has
-- either failed or rolled back.
SELECT guest_id, room_id, check_in, check_out
FROM booking_demo
ORDER BY guest_id;
