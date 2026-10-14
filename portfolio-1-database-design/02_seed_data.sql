-- =============================================================
-- Retiro Resort — Portfolio 1: small sample data (all fictional)
-- Run AFTER 01_schema.sql:
--   psql -U postgres -d retiro -f portfolio-1-database-design/02_seed_data.sql
-- IDs below (1, 2, 3 ...) work because 01_schema.sql recreates the tables,
-- so identity numbering starts again at 1.
-- =============================================================

INSERT INTO room_type (name, description, max_occupancy, price_per_night) VALUES
('Standard',        'Queen bed, garden view',            2,  45000),   -- id 1
('Deluxe',          'King bed, partial sea view',        2,  70000),   -- id 2
('Executive Suite', 'Separate lounge, full sea view',    3, 120000),   -- id 3
('Beach Chalet',    'Standalone chalet on the beach',    4, 150000);   -- id 4

INSERT INTO room (room_number, room_type_id, floor, status) VALUES
('101', 1, 1, 'available'), ('102', 1, 1, 'available'),   -- ids 1, 2
('103', 1, 1, 'available'), ('104', 1, 1, 'maintenance'), -- ids 3, 4
('201', 2, 2, 'available'), ('202', 2, 2, 'available'),   -- ids 5, 6
('203', 2, 2, 'available'),                               -- id 7
('301', 3, 3, 'available'), ('302', 3, 3, 'available'),   -- ids 8, 9
('C1',  4, 0, 'available'), ('C2',  4, 0, 'available'),   -- ids 10, 11
('C3',  4, 0, 'available');                               -- id 12

INSERT INTO staff (first_name, last_name, role, email, hired_on) VALUES
('Bisi',   'Adewale', 'front_desk', 'bisi.adewale@retiro.test',   '2022-03-01'),  -- id 1
('Kunle',  'Ojo',     'front_desk', 'kunle.ojo@retiro.test',      '2023-07-15'),  -- id 2
('Mary',   'Etim',    'kitchen',    'mary.etim@retiro.test',      '2021-11-20'),  -- id 3
('Sola',   'Hassan',  'manager',    'sola.hassan@retiro.test',    '2020-01-10'),  -- id 4
('Grace',  'Nwosu',   'accounts',   'grace.nwosu@retiro.test',    '2022-09-05'),  -- id 5
('Tayo',   'Bakare',  'kitchen',    'tayo.bakare@retiro.test',    '2024-02-12');  -- id 6

INSERT INTO guest (first_name, last_name, email, phone, nationality) VALUES
('Adaeze',  'Okafor',   'adaeze.okafor@example.com',   '08031110001', 'Nigeria'),        -- id 1
('Tunde',   'Balogun',  'tunde.balogun@example.com',   '08031110002', 'Nigeria'),        -- id 2
('Kofi',    'Mensah',   'kofi.mensah@example.com',     '0244110003',  'Ghana'),          -- id 3
('Sarah',   'Williams', 'sarah.williams@example.com',  '07700110004', 'United Kingdom'), -- id 4
('Ibrahim', 'Usman',    'ibrahim.usman@example.com',   '08031110005', 'Nigeria'),        -- id 5
('Ngozi',   'Eze',      'ngozi.eze@example.com',       '08031110006', 'Nigeria'),        -- id 6
('Femi',    'Adeyemi',  'femi.adeyemi@example.com',    '08031110007', 'Nigeria'),        -- id 7
('Aisha',   'Bello',    'aisha.bello@example.com',     '08031110008', 'Nigeria'),        -- id 8
('Jean',    'Dossou',   'jean.dossou@example.com',     '22997110009', 'Benin'),          -- id 9
('Chioma',  'Nwankwo',  'chioma.nwankwo@example.com',  '08031110010', 'Nigeria');        -- id 10

INSERT INTO booking (guest_id, room_id, staff_id, check_in, check_out, num_guests, status, booking_channel) VALUES
(1, 1,  1,    '2026-10-02', '2026-10-05', 2, 'checked_out', 'walk_in'),   -- id 1
(2, 5,  NULL, '2026-10-03', '2026-10-04', 1, 'checked_out', 'website'),   -- id 2
(3, 8,  2,    '2026-10-09', '2026-10-12', 3, 'checked_out', 'phone'),     -- id 3
(4, 10, NULL, '2026-10-10', '2026-10-14', 4, 'checked_out', 'website'),   -- id 4
(5, 2,  1,    '2026-10-12', '2026-10-15', 2, 'checked_in',  'walk_in'),   -- id 5
(6, 6,  NULL, '2026-10-13', '2026-10-16', 2, 'checked_in',  'website'),   -- id 6
(7, 9,  2,    '2026-10-20', '2026-10-23', 2, 'confirmed',   'phone'),     -- id 7
(8, 11, NULL, '2026-10-24', '2026-10-27', 3, 'confirmed',   'website'),   -- id 8
(9, 3,  1,    '2026-11-01', '2026-11-03', 1, 'confirmed',   'walk_in'),   -- id 9
(10, 7, NULL, '2026-11-05', '2026-11-08', 2, 'cancelled',   'website'),   -- id 10
(1, 12, NULL, '2026-12-23', '2026-12-27', 4, 'confirmed',   'website'),   -- id 11
(2, 1,  1,    '2026-10-05', '2026-10-07', 1, 'checked_out', 'phone');     -- id 12 (starts the day booking 1 ends — allowed)

INSERT INTO payment (booking_id, amount, method, status, paid_at) VALUES
(1,  135000, 'transfer', 'successful', '2026-10-02 12:10'),
(2,   70000, 'card',     'successful', '2026-10-01 18:40'),
(3,  360000, 'pos',      'successful', '2026-10-09 14:05'),
(4,  600000, 'card',     'successful', '2026-10-08 09:30'),
(5,  135000, 'cash',     'successful', '2026-10-12 13:00'),
(6,  210000, 'card',     'failed',     '2026-10-13 10:00'),
(6,  210000, 'transfer', 'successful', '2026-10-13 10:20'),
(7,  360000, 'transfer', 'successful', '2026-10-15 16:45'),
(10, 210000, 'card',     'refunded',   '2026-10-20 11:00'),
(12,  90000, 'cash',     'successful', '2026-10-05 13:30');

INSERT INTO menu_item (name, category, price, is_available) VALUES
('Akara and Pap',           'local',       3500, TRUE),   -- id 1
('Yam and Egg Sauce',       'local',       4500, TRUE),   -- id 2
('Jollof Breakfast Plate',  'local',       5000, TRUE),   -- id 3
('Full English Breakfast',  'continental', 7500, TRUE),   -- id 4
('Pancakes with Honey',     'continental', 4000, TRUE),   -- id 5
('Fruit Platter',           'side',        3000, TRUE),   -- id 6
('Tea',                     'drink',       1500, TRUE),   -- id 7
('Coffee',                  'drink',       2000, TRUE),   -- id 8
('Fresh Orange Juice',      'drink',       2500, FALSE);  -- id 9

INSERT INTO breakfast_order (booking_id, ordered_at, status, notes) VALUES
(1, '2026-10-03 07:45', 'delivered', NULL),                  -- id 1
(1, '2026-10-04 08:10', 'delivered', 'Less pepper please'),  -- id 2
(3, '2026-10-10 07:30', 'delivered', NULL),                  -- id 3
(4, '2026-10-11 09:00', 'delivered', 'Deliver to the beach chalet patio'), -- id 4
(5, '2026-10-13 07:50', 'preparing', NULL);                  -- id 5

INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price) VALUES
(1, 1, 2, 3500), (1, 7, 2, 1500),
(2, 2, 1, 4500), (2, 8, 1, 2000),
(3, 4, 2, 7500), (3, 6, 1, 3000), (3, 8, 3, 2000),
(4, 3, 4, 5000), (4, 9, 4, 2500),
(5, 5, 2, 4000), (5, 7, 2, 1500);

INSERT INTO review (booking_id, rating, comment) VALUES
(1, 5, 'Lovely garden view and the akara was perfect.'),
(3, 4, 'Great suite. Breakfast arrived 15 minutes late.'),
(4, 5, 'The beach chalet is worth every naira.');

-- Quick check: row counts per table
SELECT 'guest' AS table_name, count(*) FROM guest
UNION ALL SELECT 'room_type', count(*) FROM room_type
UNION ALL SELECT 'room', count(*) FROM room
UNION ALL SELECT 'staff', count(*) FROM staff
UNION ALL SELECT 'booking', count(*) FROM booking
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'menu_item', count(*) FROM menu_item
UNION ALL SELECT 'breakfast_order', count(*) FROM breakfast_order
UNION ALL SELECT 'order_item', count(*) FROM order_item
UNION ALL SELECT 'review', count(*) FROM review;