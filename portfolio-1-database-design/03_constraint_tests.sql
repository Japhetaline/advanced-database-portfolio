-- =============================================================
-- Retiro Resort — Portfolio 1: constraint tests
-- EVERY statement below is SUPPOSED TO FAIL. Each error message is
-- evidence that the database protects data quality.
-- =============================================================

\echo '--- Test 1: check-out before check-in (CHECK chk_booking_dates) ---'
INSERT INTO booking (guest_id, room_id, check_in, check_out, num_guests)
VALUES (1, 3, '2026-12-10', '2026-12-08', 1);

\echo '--- Test 2: double-booking room 101 (EXCLUDE no_double_booking) ---'
INSERT INTO booking (guest_id, room_id, check_in, check_out, num_guests)
VALUES (5, 1, '2026-10-03', '2026-10-06', 1);

\echo '--- Test 3: negative room price (CHECK price_per_night > 0) ---'
INSERT INTO room_type (name, max_occupancy, price_per_night)
VALUES ('Budget', 2, -5000);

\echo '--- Test 4: duplicate guest email (UNIQUE) ---'
INSERT INTO guest (first_name, last_name, email, phone)
VALUES ('Copy', 'Cat', 'adaeze.okafor@example.com', '08000000000');

\echo '--- Test 5: booking for a guest that does not exist (FOREIGN KEY) ---'
INSERT INTO booking (guest_id, room_id, check_in, check_out, num_guests)
VALUES (9999, 3, '2026-12-10', '2026-12-12', 1);

\echo '--- Test 6: invalid status value (CHECK status IN ...) ---'
UPDATE booking SET status = 'lost' WHERE booking_id = 7;

\echo '--- Test 7: deleting a guest who has bookings (ON DELETE RESTRICT) ---'
DELETE FROM guest WHERE guest_id = 1;

\echo '--- Test 8: same item twice in one order (composite PRIMARY KEY) ---'
INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price)
VALUES (1, 1, 1, 3500);

\echo '--- Test 9 (should SUCCEED): a CANCELLED booking may overlap ---'
INSERT INTO booking (guest_id, room_id, check_in, check_out, num_guests, status)
VALUES (6, 1, '2026-10-03', '2026-10-04', 1, 'cancelled');
DELETE FROM booking WHERE guest_id = 6 AND room_id = 1 AND status = 'cancelled';