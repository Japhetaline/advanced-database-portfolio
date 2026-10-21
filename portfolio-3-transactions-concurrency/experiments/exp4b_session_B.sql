
-- Experiment 4b: Pessimistic locking
-- Session B

-- Step 3: Start a transaction and request the same room lock.
BEGIN;

SELECT room_id
FROM room
WHERE room_number = '101'
FOR UPDATE;

-- IMPORTANT:
-- Execute the SELECT above while Session A still holds
-- the lock. It should wait without returning a prompt.
--
-- Do not cancel the query.
-- Wait for Session A to COMMIT.

-- Step 5: After the SELECT returns, check availability.
-- Expected: clashes = 1
SELECT count(*) AS clashes
FROM booking_demo
WHERE room_id = (
    SELECT room_id FROM room WHERE room_number = '101'
)
AND status <> 'cancelled'
AND check_in < DATE '2026-12-22'
AND check_out > DATE '2026-12-20';

-- Step 6: Do not create another booking.
ROLLBACK;
