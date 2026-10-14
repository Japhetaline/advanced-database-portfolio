-- =============================================================
-- Retiro Resort — Portfolio 2: indexes targeting each slow step
-- Run AFTER capturing plans/before.txt
-- =============================================================

-- Q1: booking was read in full (Seq Scan) to find one guest's stays.
CREATE INDEX IF NOT EXISTS idx_booking_guest       ON booking (guest_id);

-- Q2: availability check filters by room AND dates. Composite index,
-- room_id first because it is matched with '=' (leftmost-column rule).
CREATE INDEX IF NOT EXISTS idx_booking_room_dates  ON booking (room_id, check_in, check_out);

-- Q3: revenue report filters payments by date range.
CREATE INDEX IF NOT EXISTS idx_payment_paid_at     ON payment (paid_at);

-- Q4: orders filtered by date, then joined to their items.
CREATE INDEX IF NOT EXISTS idx_order_ordered_at    ON breakfast_order (ordered_at);

-- Q5: arrivals for a single day.
CREATE INDEX IF NOT EXISTS idx_booking_check_in    ON booking (check_in);

-- Q6: deliberately POOR index — about 95% of bookings are 'checked_out',
-- so the planner should ignore it. This is your "index that did not help".
CREATE INDEX IF NOT EXISTS idx_booking_status      ON booking (status);

-- Refresh statistics so the planner knows about the new indexes' data
ANALYZE;

-- How much disk space each index costs (the trade-off of indexing)
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE 'idx_%'
ORDER BY pg_relation_size(indexrelid) DESC;