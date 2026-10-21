
-- Experiment 3: Non-repeatable reads
-- Session A
-- Database: retiro
--
-- PART 1: READ COMMITTED
-- Expected starting price: 70000.00
-- Coordinate with Session B between the two SELECT statements.

BEGIN ISOLATION LEVEL READ COMMITTED;

-- Step 2: Read the original Deluxe price.
SELECT price_per_night
FROM room_type
WHERE name = 'Deluxe';

-- Step 3: PAUSE.
-- Session B updates the price to 80000 and autocommits.

-- Step 4: Run this SELECT after Session B finishes its UPDATE.
-- Expected: 80000.00
SELECT price_per_night
FROM room_type
WHERE name = 'Deluxe';

-- Step 5: Finish the transaction.
COMMIT;


-- PART 2: REPEATABLE READ
-- Session B must first have completed the update to 80000.

BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Step 7: Establish Session A's snapshot.
-- Expected: 80000.00
SELECT price_per_night
FROM room_type
WHERE name = 'Deluxe';

-- Step 8: PAUSE.
-- Session B updates the price to 90000 and autocommits.

-- Step 9: Run this SELECT after Session B finishes.
-- Expected: still 80000.00
SELECT price_per_night
FROM room_type
WHERE name = 'Deluxe';

-- Step 10: Finish the transaction.
COMMIT;

-- Run this SELECT AFTER COMMIT.
-- Expected: 90000.00
SELECT price_per_night
FROM room_type
WHERE name = 'Deluxe';
