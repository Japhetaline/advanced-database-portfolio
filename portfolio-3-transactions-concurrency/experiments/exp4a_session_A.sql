
-- Experiment 4a: Double booking without protection
-- Session A
-- Room 101, December 20-22, 2026

BEGIN;

-- Step 2: Check whether the room is available.
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

-- PAUSE: Let Session B BEGIN and run its availability check.

-- Step 5: Insert the first booking.
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

-- PAUSE: Let Session B insert its booking too.

-- Step 7: Commit the first booking.
COMMIT;

-- PAUSE: Let Session B commit its booking.

-- Step 9: Show the two conflicting bookings.
SELECT guest_id, room_id, check_in, check_out
FROM booking_demo
ORDER BY guest_id;

-- Expected: Two bookings for the same room and dates.
