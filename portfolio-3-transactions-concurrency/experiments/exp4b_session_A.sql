
-- Experiment 4b: Pessimistic locking
-- Session A

-- Step 1: Lock room 101.
BEGIN;

SELECT room_id
FROM room
WHERE room_number = '101'
FOR UPDATE;

-- Expected: One room_id returned.
-- Session A now holds a row lock on room 101.

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

-- PAUSE: Session B attempts SELECT ... FOR UPDATE
-- and should wait for this session to finish.

-- Step 4: Insert the first booking.
INSERT INTO booking_demo
    (guest_id, room_id, check_in, check_out, num_guests)
VALUES (
    4,
    (SELECT room_id FROM room WHERE room_number = '101'),
    DATE '2026-12-20',
    DATE '2026-12-22',
    1
);

-- Expected: INSERT 0 1

-- Release the room lock.
COMMIT;
