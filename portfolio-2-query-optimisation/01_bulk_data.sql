-- =============================================================
-- Retiro Resort — Portfolio 2: generate a LARGE realistic dataset
-- Indexes make no visible difference on 12 rows, so we create:
--   ~100,000 guests, 60 rooms, ~90,000 bookings (2010-2026),
--   ~85,000 payments, ~60,000 breakfast orders, ~160,000 order lines.
-- Run AFTER Portfolio 1 scripts (takes 1-3 minutes).
-- All data is synthetic.
-- =============================================================

\timing on

-- 1. 48 extra rooms in a new "Block B" (B001 ... B048)
INSERT INTO room (room_number, room_type_id, floor)
SELECT 'B' || lpad(g::text, 3, '0'),
       1 + (g % 4),            -- cycles through room types 1-4
       1 + (g % 3)             -- floors 1-3
FROM generate_series(1, 48) AS g;

-- 2. 100,000 synthetic guests
INSERT INTO guest (first_name, last_name, email, phone, nationality)
SELECT (ARRAY['Ade','Chioma','Tunde','Ngozi','Emeka','Funke','Ibrahim','Aisha','Kwame','Sarah'])[1 + g % 10],
       (ARRAY['Okafor','Adeyemi','Bello','Eze','Johnson','Mensah','Balogun','Usman','Smith','Okon'])[1 + (g / 10) % 10],
       'guest' || g || '@example.com',
       '080' || lpad(g::text, 8, '0'),
       CASE WHEN g % 7 = 0 THEN 'Ghana'
            WHEN g % 11 = 0 THEN 'United Kingdom'
            ELSE 'Nigeria' END
FROM generate_series(1, 100000) AS g;

-- 3. Bookings: every room gets 1,500 stays, one every 4 days from 2010,
--    each 1-3 nights long, so stays NEVER overlap (the exclusion constraint
--    would reject overlaps). Dates run from 2010-01-01 to mid-2026.
INSERT INTO booking (guest_id, room_id, staff_id, check_in, check_out,
                     num_guests, status, booking_channel, created_at)
-- Guest choice is deterministic (not random) so everyone gets the same
-- pattern: the first 30,000 guests are "returning guests" with 3 stays each.
SELECT g.ids[1 + ((r.room_id * 1500 + s) * 7919) % 30000],
       r.room_id,
       CASE WHEN random() < 0.4 THEN NULL ELSE 1 + floor(random() * 2)::int END,  -- NULL = online
       DATE '2010-01-01' + s * 4,
       DATE '2010-01-01' + s * 4 + 1 + floor(random() * 3)::int,
       1 + floor(random() * 2)::int,
       CASE WHEN random() < 0.05 THEN 'cancelled' ELSE 'checked_out' END,
       (ARRAY['walk_in','phone','website'])[1 + floor(random() * 3)::int],
       (DATE '2010-01-01' + s * 4 - 7)::timestamptz
FROM room r
CROSS JOIN generate_series(0, 1499) AS s
CROSS JOIN (SELECT array_agg(guest_id ORDER BY guest_id) AS ids FROM guest) AS g;  -- all guest IDs in order (there may be gaps)

-- 4. One successful payment for each non-cancelled booking that has none
INSERT INTO payment (booking_id, amount, method, status, paid_at)
SELECT bk.booking_id,
       rt.price_per_night * (bk.check_out - bk.check_in),
       (ARRAY['cash','card','transfer','pos'])[1 + floor(random() * 4)::int],
       'successful',
       bk.check_in::timestamptz + interval '12 hours'
FROM booking bk
JOIN room r       ON r.room_id = bk.room_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
WHERE bk.status <> 'cancelled'
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.booking_id = bk.booking_id);

-- 5. About 70% of finished stays ordered breakfast on their first morning
INSERT INTO breakfast_order (booking_id, ordered_at, status)
SELECT booking_id,
       (check_in + 1)::timestamptz + interval '7 hours 30 minutes',
       'delivered'
FROM booking
WHERE status = 'checked_out'
  AND check_in < DATE '2026-09-01'
  AND random() < 0.7;

-- 6. Each order gets a random selection of menu items
INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price)
SELECT o.order_id, m.menu_item_id, 1 + floor(random() * 2)::int, m.price
FROM breakfast_order o
JOIN menu_item m ON random() < 0.3
WHERE NOT EXISTS (SELECT 1 FROM order_item oi WHERE oi.order_id = o.order_id)
ON CONFLICT DO NOTHING;

-- 7. Refresh the optimiser's statistics after the bulk load
ANALYZE;

-- 8. Check the new sizes
SELECT 'guest' AS table_name, count(*) FROM guest
UNION ALL SELECT 'room', count(*) FROM room
UNION ALL SELECT 'booking', count(*) FROM booking
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'breakfast_order', count(*) FROM breakfast_order
UNION ALL SELECT 'order_item', count(*) FROM order_item;