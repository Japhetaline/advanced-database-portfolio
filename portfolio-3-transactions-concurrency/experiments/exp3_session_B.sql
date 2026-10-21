
-- Experiment 3: Non-repeatable reads
-- Session B
-- Database: retiro

-- PART 1: READ COMMITTED
-- Execute after Session A has completed its first SELECT.
-- Step 3: Change the Deluxe price to 80000.
-- This standalone UPDATE autocommits.

UPDATE room_type
SET price_per_night = 80000
WHERE name = 'Deluxe';

-- Expected: UPDATE 1


-- PART 2: REPEATABLE READ
-- Execute after Session A has read 80000 inside its
-- REPEATABLE READ transaction.
-- Step 8: Change the Deluxe price to 90000.
-- This standalone UPDATE autocommits.

UPDATE room_type
SET price_per_night = 90000
WHERE name = 'Deluxe';

-- Expected: UPDATE 1


-- Step 11: Restore the original price after Session A
-- has committed and completed its final SELECT.

UPDATE room_type
SET price_per_night = 70000
WHERE name = 'Deluxe';

-- Expected: UPDATE 1
