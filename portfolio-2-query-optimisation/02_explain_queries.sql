-- =============================================================
-- Retiro Resort — Portfolio 2: six business queries with execution plans
-- Run this file TWICE: once BEFORE adding indexes, once AFTER.
-- EXPLAIN (ANALYZE, BUFFERS) actually runs each query and reports
-- the plan, the real time, and how many data pages were read.
-- =============================================================

\echo '=================================================='
\echo 'Q1. Stay history of one guest, looked up by email'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT g.first_name, g.last_name, b.check_in, b.check_out, r.room_number, rt.name AS room_type
FROM guest g
JOIN booking b    ON b.guest_id = g.guest_id
JOIN room r       ON r.room_id = b.room_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
WHERE g.email = 'guest4521@example.com'
ORDER BY b.check_in DESC;

\echo '=================================================='
\echo 'Q2. Deluxe rooms FREE for 20-22 Nov 2026 (availability search)'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.room_number, rt.name, rt.price_per_night
FROM room r
JOIN room_type rt ON rt.room_type_id = r.room_type_id
WHERE rt.name = 'Deluxe'
  AND r.status = 'available'
  AND NOT EXISTS (
        SELECT 1 FROM booking b
        WHERE b.room_id = r.room_id
          AND b.status <> 'cancelled'
          AND b.check_in  < DATE '2026-11-22'
          AND b.check_out > DATE '2026-11-20');

\echo '=================================================='
\echo 'Q3. Monthly revenue for 2025'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', paid_at) AS month, sum(amount) AS revenue
FROM payment
WHERE status = 'successful'
  AND paid_at >= '2025-01-01' AND paid_at < '2026-01-01'
GROUP BY 1
ORDER BY 1;

\echo '=================================================='
\echo 'Q4. Top 5 breakfast items in the last 12 months of data'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.name, sum(oi.quantity) AS portions
FROM breakfast_order o
JOIN order_item oi ON oi.order_id = o.order_id
JOIN menu_item m   ON m.menu_item_id = oi.menu_item_id
WHERE o.ordered_at >= '2025-09-01' AND o.ordered_at < '2026-09-01'
GROUP BY m.name
ORDER BY portions DESC
LIMIT 5;

\echo '=================================================='
\echo 'Q5. Front-desk arrivals list for one day'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT b.booking_id, g.first_name, g.last_name, r.room_number
FROM booking b
JOIN guest g ON g.guest_id = b.guest_id
JOIN room r  ON r.room_id = b.room_id
WHERE b.check_in = DATE '2025-03-15'
  AND b.status <> 'cancelled';

\echo '=================================================='
\echo 'Q6. Count of completed stays (low-selectivity filter)'
\echo '=================================================='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM booking WHERE status = 'checked_out';