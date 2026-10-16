-- =============================================================
-- Experiment 1: a successful transaction (COMMIT)
-- A walk-in guest books Beach Chalet C3 for 1-3 Dec 2026 and pays.
-- The booking and the payment must BOTH be saved, or NEITHER.
-- =============================================================
\set ON_ERROR_STOP off
-- Clean-up so the experiment can be re-run
DELETE FROM payment WHERE booking_id IN (SELECT booking_id FROM booking
       WHERE room_id = (SELECT room_id FROM room WHERE room_number = 'C3') AND check_in = '2026-12-01');
DELETE FROM booking WHERE room_id = (SELECT room_id FROM room WHERE room_number = 'C3') AND check_in = '2026-12-01';

BEGIN;
  INSERT INTO booking (guest_id, room_id, staff_id, check_in, check_out, num_guests, status, booking_channel)
  VALUES (3, (SELECT room_id FROM room WHERE room_number = 'C3'), 1,
          '2026-12-01', '2026-12-03', 2, 'confirmed', 'walk_in')
  RETURNING booking_id \gset
  -- \gset stores the new booking_id in a psql variable called :booking_id
  INSERT INTO payment (booking_id, amount, method)
  VALUES (:booking_id, 300000, 'card');
COMMIT;

\echo '--- After COMMIT: both rows exist ---'
SELECT b.booking_id, b.check_in, b.check_out, p.amount, p.method, p.status
FROM booking b JOIN payment p ON p.booking_id = b.booking_id
WHERE b.booking_id = :booking_id;