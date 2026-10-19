-- =============================================================
-- Experiment 2: ROLLBACK and SAVEPOINT
-- =============================================================
\set ON_ERROR_STOP off

\echo '=== 2a. Failure inside a transaction -> everything is undone ==='
BEGIN;
  INSERT INTO booking (guest_id, room_id, staff_id, check_in, check_out, num_guests, status, booking_channel)
  VALUES (4, (SELECT room_id FROM room WHERE room_number = 'C3'), 1,
          '2026-12-05', '2026-12-07', 2, 'confirmed', 'walk_in')
  RETURNING booking_id \gset
  -- The POS returns a bad amount: violates CHECK (amount > 0)
  INSERT INTO payment (booking_id, amount, method) VALUES (:booking_id, -300000, 'pos');
  -- Postgres now refuses every further command in this transaction:
  SELECT 'this will not run';
ROLLBACK;

\echo '--- After ROLLBACK: the booking was NOT saved (expect 0) ---'
SELECT count(*) AS bookings_saved FROM booking WHERE booking_id = :booking_id;

\echo '=== 2b. Guest changes their mind -> deliberate ROLLBACK ==='
BEGIN;
  UPDATE room_type SET price_per_night = 1 WHERE name = 'Beach Chalet';   -- a mistake!
  SELECT name, price_per_night FROM room_type WHERE name = 'Beach Chalet';
ROLLBACK;
\echo '--- Price is back to 150000 ---'
SELECT name, price_per_night FROM room_type WHERE name = 'Beach Chalet';

\echo '=== 2c. SAVEPOINT: keep the booking even though the breakfast add-on fails ==='
BEGIN;
  INSERT INTO booking (guest_id, room_id, staff_id, check_in, check_out, num_guests, status, booking_channel)
  VALUES (4, (SELECT room_id FROM room WHERE room_number = 'C3'), 1,
          '2026-12-05', '2026-12-07', 2, 'confirmed', 'walk_in')
  RETURNING booking_id \gset
  SAVEPOINT before_breakfast;
  -- Invalid status value -> error
  INSERT INTO breakfast_order (booking_id, status) VALUES (:booking_id, 'teleported');
  ROLLBACK TO SAVEPOINT before_breakfast;   -- undo only the failed part
  INSERT INTO payment (booking_id, amount, method) VALUES (:booking_id, 300000, 'transfer');
COMMIT;

\echo '--- Booking and payment kept, no breakfast order ---'
SELECT b.booking_id, p.amount,
       (SELECT count(*) FROM breakfast_order o WHERE o.booking_id = b.booking_id) AS breakfast_orders
FROM booking b JOIN payment p ON p.booking_id = b.booking_id
WHERE b.booking_id = :booking_id;

-- Clean-up so the experiment can be re-run
DELETE FROM payment WHERE booking_id = :booking_id;
DELETE FROM booking WHERE booking_id = :booking_id;