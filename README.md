# Portfolio 1 lab — Design & Modelling (Oct 16–21)

You will build 10 tables, load sample data, prove the constraints work, draw the ER diagram, and write the normalisation explanation. All scripts below were tested on PostgreSQL 16.

## 1.1 The design at a glance

| Table | Primary key | Foreign keys | Why it exists |
|---|---|---|---|
| guest | guest_id | — | People who stay |
| room_type | room_type_id | — | Category + price; price lives here, not on each room (3NF) |
| room | room_id | room_type_id | Each physical room |
| staff | staff_id | — | Front desk, kitchen, accounts |
| booking | booking_id | guest_id, room_id, staff_id | One guest reserves one room for a date range |
| payment | payment_id | booking_id | A booking can have several payments (failed, then successful) |
| menu_item | menu_item_id | — | The breakfast menu |
| breakfast_order | order_id | booking_id | One QR-code order from a room |
| order_item | (order_id, menu_item_id) | both | Junction table for the M:N between orders and menu items |
| review | review_id | booking_id (UNIQUE) | At most one review per stay |

## 1.2 Save your password for this terminal session (Terminal)

So psql stops asking for your password on every command. This lasts until you close the window and is not saved in any file:

```powershell
$env:PGPASSWORD = "the-password-you-chose-in-A4"
cd ~\Documents\advanced-database-portfolio
```

Do this every time you open a new terminal for database work.

## 1.3 Create the schema

In VS Code, create portfolio-1-database-design/01_schema.sql and paste:

```sql
-- =============================================================
-- Retiro Resort Reservation & Guest Services Database
-- Portfolio 1: Schema (PostgreSQL 16)
-- Run with:  psql -U postgres -d retiro -f portfolio-1-database-design/01_schema.sql
-- =============================================================

-- Start clean so the script can be re-run safely
DROP TABLE IF EXISTS review, order_item, breakfast_order, menu_item,
                     payment, booking, staff, room, room_type, guest CASCADE;

-- Needed for the exclusion constraint that blocks double-booking
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- GUEST: people who stay at the resort ----------
CREATE TABLE guest (
    guest_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(120) NOT NULL UNIQUE,          -- alternate (candidate) key
    phone        VARCHAR(20)  NOT NULL,
    nationality  VARCHAR(60)  NOT NULL DEFAULT 'Nigeria',
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------- ROOM_TYPE: category and price of rooms ----------
CREATE TABLE room_type (
    room_type_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             VARCHAR(50)   NOT NULL UNIQUE,
    description      TEXT,
    max_occupancy    SMALLINT      NOT NULL CHECK (max_occupancy BETWEEN 1 AND 10),
    price_per_night  NUMERIC(12,2) NOT NULL CHECK (price_per_night > 0)
);

-- ---------- ROOM: each physical room ----------
CREATE TABLE room (
    room_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_number   VARCHAR(10) NOT NULL UNIQUE,              -- natural key kept unique
    room_type_id  INT NOT NULL REFERENCES room_type(room_type_id) ON DELETE RESTRICT,
    floor         SMALLINT NOT NULL CHECK (floor >= 0),
    status        VARCHAR(20) NOT NULL DEFAULT 'available'
                  CHECK (status IN ('available', 'maintenance', 'out_of_service'))
);

-- ---------- STAFF ----------
CREATE TABLE staff (
    staff_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    role        VARCHAR(30)  NOT NULL
                CHECK (role IN ('front_desk', 'kitchen', 'manager', 'accounts', 'housekeeping')),
    email       VARCHAR(120) NOT NULL UNIQUE,
    hired_on    DATE NOT NULL
);

-- ---------- BOOKING: a guest's reservation of one room ----------
CREATE TABLE booking (
    booking_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    guest_id         INT NOT NULL REFERENCES guest(guest_id) ON DELETE RESTRICT,
    room_id          INT NOT NULL REFERENCES room(room_id)   ON DELETE RESTRICT,
    staff_id         INT REFERENCES staff(staff_id) ON DELETE SET NULL,  -- NULL = booked online
    check_in         DATE NOT NULL,
    check_out        DATE NOT NULL,
    num_guests       SMALLINT NOT NULL CHECK (num_guests > 0),
    status           VARCHAR(20) NOT NULL DEFAULT 'confirmed'
                     CHECK (status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
    booking_channel  VARCHAR(20) NOT NULL DEFAULT 'walk_in'
                     CHECK (booking_channel IN ('walk_in', 'phone', 'website')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_booking_dates CHECK (check_out > check_in),
    -- No two active bookings may overlap for the same room.
    -- '[)' = check-in day included, check-out day excluded, so a guest can
    -- check in on the same day the previous guest checks out.
    CONSTRAINT no_double_booking EXCLUDE USING gist (
        room_id WITH =,
        daterange(check_in, check_out, '[)') WITH &&
    ) WHERE (status <> 'cancelled')
);

-- ---------- PAYMENT: money received for a booking ----------
CREATE TABLE payment (
    payment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  INT NOT NULL REFERENCES booking(booking_id) ON DELETE RESTRICT,
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method      VARCHAR(20) NOT NULL CHECK (method IN ('cash', 'card', 'transfer', 'pos')),
    status      VARCHAR(20) NOT NULL DEFAULT 'successful'
                CHECK (status IN ('successful', 'failed', 'refunded')),
    paid_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- MENU_ITEM: breakfast menu ----------
CREATE TABLE menu_item (
    menu_item_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(80) NOT NULL UNIQUE,
    category      VARCHAR(30) NOT NULL CHECK (category IN ('local', 'continental', 'drink', 'side')),
    price         NUMERIC(10,2) NOT NULL CHECK (price > 0),
    is_available  BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------- BREAKFAST_ORDER: one QR-code order from a room ----------
-- Linked to the booking (not directly to guest/room): the booking already
-- tells us who the guest is and which room to deliver to (avoids redundancy).
CREATE TABLE breakfast_order (
    order_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  INT NOT NULL REFERENCES booking(booking_id) ON DELETE RESTRICT,
    ordered_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    status      VARCHAR(20) NOT NULL DEFAULT 'placed'
                CHECK (status IN ('placed', 'preparing', 'delivered', 'cancelled')),
    notes       VARCHAR(255)
);

-- ---------- ORDER_ITEM: junction table resolving the M:N between
-- breakfast_order and menu_item. Composite primary key. ----------
CREATE TABLE order_item (
    order_id      INT NOT NULL REFERENCES breakfast_order(order_id) ON DELETE CASCADE,
    menu_item_id  INT NOT NULL REFERENCES menu_item(menu_item_id)   ON DELETE RESTRICT,
    quantity      SMALLINT NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),  -- price at time of order
    PRIMARY KEY (order_id, menu_item_id)
);

-- ---------- REVIEW: at most one review per booking (1:1 via UNIQUE) ----------
CREATE TABLE review (
    review_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  INT NOT NULL UNIQUE REFERENCES booking(booking_id) ON DELETE CASCADE,
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Run it (Terminal):

```powershell
psql -U postgres -d retiro -f portfolio-1-database-design/01_schema.sql
```

The first time you'll see notices like table "review" does not exist, skipping — normal, that's the DROP TABLE IF EXISTS line. Then lots of CREATE TABLE.

What the key lines do:

- GENERATED ALWAYS AS IDENTITY — Postgres numbers rows automatically (a surrogate key).
- REFERENCES ... ON DELETE RESTRICT — a foreign key; you can't delete a guest who still has bookings. ON DELETE CASCADE on order_item means deleting an order deletes its lines too.
- EXCLUDE USING gist (...) — the star of your design: the database itself refuses any two non-cancelled bookings of the same room with overlapping dates. You'll use this again in Portfolio 3.
- unit_price on order_item looks like a duplicate of menu_item.price, but it isn't: it records the price at the time of ordering, so changing the menu next month doesn't rewrite old bills. Mention this in your normalisation write-up — it shows judgment.

Commit: `git add . ; git commit -m "P1: create Retiro schema with keys and constraints" ; git push`

## 1.4 Load the sample data

Create portfolio-1-database-design/02_seed_data.sql:

```sql
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
```

Run it:

```powershell
psql -U postgres -d retiro -f portfolio-1-database-design/02_seed_data.sql
```

Expected: a table of counts — guest 10, room_type 4, room 12, staff 6, booking 12, payment 10, menu_item 9, breakfast_order 5, order_item 11, review 3. Screenshot this (p1_seed_counts.png).

Make the data yours: change a few names, prices or menu items to Retiro's real menu style. Prices and people are fictional.

## 1.5 Prove the constraints work

Create portfolio-1-database-design/03_constraint_tests.sql. Every statement except the last is supposed to fail:

```sql
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
```

Run it and save the output as evidence:

```powershell
cmd /c "psql -U postgres -d retiro -f portfolio-1-database-design/03_constraint_tests.sql > portfolio-1-database-design/constraint_test_results.txt 2>&1"
Get-Content portfolio-1-database-design/constraint_test_results.txt
```

(cmd /c "... > file 2>&1" saves both normal output and error messages to a text file. Older PowerShell mangles error text otherwise. You'll reuse this pattern.)

Expected: eight ERROR lines, e.g. violates check constraint "chk_booking_dates", conflicting key value violates exclusion constraint "no_double_booking", duplicate key value violates unique constraint "guest_email_key", violates foreign key constraint "booking_guest_id_fkey". Test 9 prints nothing (success). Screenshot the output.

Note: failed inserts still use up an ID number, so you may later see gaps like booking 12 → 15. That's normal identity behaviour.

## 1.6 Draw the ER diagram (dbdiagram.io)

1. Log in to dbdiagram.io → Create your diagram.
2. Delete the sample code on the left and paste this (DBML — a small language that describes tables):

```text
Table guest {
  guest_id int [pk, increment]
  first_name varchar
  last_name varchar
  email varchar [unique, not null]
  phone varchar
  nationality varchar
  created_at timestamptz
}

Table room_type {
  room_type_id int [pk, increment]
  name varchar [unique]
  description text
  max_occupancy smallint
  price_per_night numeric
}

Table room {
  room_id int [pk, increment]
  room_number varchar [unique]
  room_type_id int [ref: > room_type.room_type_id]
  floor smallint
  status varchar
}

Table staff {
  staff_id int [pk, increment]
  first_name varchar
  last_name varchar
  role varchar
  email varchar [unique]
  hired_on date
}

Table booking {
  booking_id int [pk, increment]
  guest_id int [ref: > guest.guest_id]
  room_id int [ref: > room.room_id]
  staff_id int [ref: > staff.staff_id, null]
  check_in date
  check_out date
  num_guests smallint
  status varchar
  booking_channel varchar
  created_at timestamptz
  Note: 'EXCLUDE: no overlapping active bookings per room'
}

Table payment {
  payment_id int [pk, increment]
  booking_id int [ref: > booking.booking_id]
  amount numeric
  method varchar
  status varchar
  paid_at timestamptz
}

Table menu_item {
  menu_item_id int [pk, increment]
  name varchar [unique]
  category varchar
  price numeric
  is_available boolean
}

Table breakfast_order {
  order_id int [pk, increment]
  booking_id int [ref: > booking.booking_id]
  ordered_at timestamptz
  status varchar
  notes varchar
}

Table order_item {
  order_id int [ref: > breakfast_order.order_id]
  menu_item_id int [ref: > menu_item.menu_item_id]
  quantity smallint
  unit_price numeric
  indexes {
    (order_id, menu_item_id) [pk]
  }
}

Table review {
  review_id int [pk, increment]
  booking_id int [unique, ref: - booking.booking_id]
  rating smallint
  comment text
  created_at timestamptz
}
```

3. The diagram draws itself on the right. Drag the boxes so lines don't cross (booking in the middle works well).
4. Export → PNG → save as portfolio-1-database-design/er-diagram.png. Also save the DBML text as portfolio-1-database-design/er-diagram.dbml.

Reading the lines: > is many-to-one (many bookings → one guest), shown with a crow's foot on the "many" side. - is one-to-one (one review ↔ one booking).

Commit: `git add . ; git commit -m "P1: add seed data, constraint tests and ER diagram" ; git push`

## 1.7 Write the Portfolio 1 README

Create portfolio-1-database-design/README.md with this structure, written in your own words:

```markdown
# Portfolio 1 — Database Design and Modelling

## Case study
(2–3 sentences on Retiro Resort and what the database supports)

## ER diagram
![ER diagram](er-diagram.png)

## Entities and relationships
(Table: entity, primary key, foreign keys, purpose — use the table in Lab 1.1)
Cardinalities: guest 1:N booking; room 1:N booking; room_type 1:N room;
booking 1:N payment; booking 1:N breakfast_order; breakfast_order M:N menu_item via order_item;
booking 1:1 review (UNIQUE booking_id).

## Keys and constraints
(Explain each type with one example from the schema: PK, surrogate vs natural key,
alternate key, FK with RESTRICT/CASCADE/SET NULL, composite key, CHECK, DEFAULT,
and the EXCLUDE constraint.)

## Normalisation
### Starting point: the front desk's paper booking sheet (unnormalised)
| BookingNo | GuestName | GuestPhone | RoomNo | RoomType | Price | CheckIn | CheckOut | BreakfastItems |
|---|---|---|---|---|---|---|---|---|
| 1 | Adaeze Okafor | 0803... | 101 | Standard | 45000 | 2026-10-02 | 2026-10-05 | Akara & Pap x2, Tea x2 |

### 1NF — atomic values
BreakfastItems holds a list → split into separate rows/table (order_item).
### 2NF — no partial dependencies
In (order_id, menu_item_id, item_name), item_name depends only on menu_item_id → moved to menu_item.
### 3NF — no transitive dependencies
RoomNo → RoomType → Price. Price depends on the type, not the room → moved to room_type.
Guest name/phone depend on the guest, not the booking → moved to guest.
### Anomalies this prevents
(Update, insert and delete anomaly — one Retiro example each.)
### Deliberate decision: order_item.unit_price
(Why storing the historical price is correct and not a 3NF violation.)

## How to run
psql -U postgres -d retiro -f 01_schema.sql
psql -U postgres -d retiro -f 02_seed_data.sql
psql -U postgres -d retiro -f 03_constraint_tests.sql

## Evidence
(Screenshots: seed counts, constraint errors, ER diagram)
```

Commit: `git add . ; git commit -m "P1: README with normalisation walkthrough" ; git push`

# Portfolio 2 lab — Query Processing & Optimisation (Oct 22–26)

You will load a big dataset, run six business queries with EXPLAIN (ANALYZE, BUFFERS), add indexes, run them again, and compare. In my test run, the guest-history query dropped from about 21 ms to 0.2 ms; your numbers will differ slightly, which is fine — use your own.

## 2.1 Generate the large dataset

Create portfolio-2-query-optimisation/01_bulk_data.sql:

```sql
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
```

Run it once (Terminal):

```powershell
psql -U postgres -d retiro -f portfolio-2-query-optimisation/01_bulk_data.sql
```

Expected (approximately): guest 100,010 · room 60 · booking 90,012 · payment ~85,400 · breakfast_order ~60,000 · order_item ~162,000. Screenshot it.

What this does: generate_series(1, 100000) produces numbers 1 to 100,000 — one row each — so a single INSERT ... SELECT creates 100,000 guests in seconds. random() varies things like payment method. ANALYZE updates the statistics the optimiser uses to estimate row counts.

If you ever need to start over: rerun Portfolio 1's 01_schema.sql and 02_seed_data.sql, then this file. Don't run this file twice on top of itself (you'd get duplicate-email errors).

Commit: `git add . ; git commit -m "P2: bulk synthetic dataset generator" ; git push`

## 2.2 The six queries with execution plans

Create portfolio-2-query-optimisation/02_explain_queries.sql:

-- =============================================================

```sql
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
```

Also save the actual results (the evidence asks for query results, not just plans): copy each query without the EXPLAIN (ANALYZE, BUFFERS) line into pgAdmin's Query Tool, press ▶, and screenshot the result grid (p2_q1_result.png …). Q1 should show 3 stays for that guest.

## 2.3 Capture the BEFORE plans

```powershell
cmd /c "psql -U postgres -d retiro -f portfolio-2-query-optimisation/02_explain_queries.sql > portfolio-2-query-optimisation/plans/before.txt 2>&1"
```

Open plans/before.txt in VS Code. Run the command a second time and keep the second file — the first run is slower because data isn't cached in memory yet.

How to read a plan (example from Q5 before indexing):

```text
Nested Loop  (cost=0.43..2774.61 rows=57 width=20) (actual time=7.728..8.785 rows=57 loops=1)
  ->  Seq Scan on booking b  (cost=0.00..2304.18 rows=57 width=12) (actual time=7.697..8.347 rows=57 loops=1)
        Filter: ((status)::text <> 'cancelled' AND check_in = '2025-03-15')
        Rows Removed by Filter: 89955
...
Execution Time: 8.807 ms
```

- Read from the most indented line upwards — the innermost step runs first.
- Seq Scan on booking = read all 90,012 rows; Rows Removed by Filter: 89955 = it threw away almost everything. That's the waste an index fixes.
- cost=0.00..2304.18 = the planner's estimate (arbitrary units). actual time=… = real milliseconds. rows=57 estimated vs rows=57 actual — a good estimate means statistics are healthy.
- Buffers: shared hit=… = pages read from memory (hit) vs disk (read).
- Execution Time = the headline number for your table.

Commit: `git add . ; git commit -m "P2: queries and baseline execution plans" ; git push`

## 2.4 Add the indexes

Create portfolio-2-query-optimisation/03_indexes.sql:

```sql
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
```

```powershell
psql -U postgres -d retiro -f portfolio-2-query-optimisation/03_indexes.sql
```

Expected: a list of six indexes with sizes from roughly 400 kB to 3 MB. Screenshot it — that's your "cost of indexing" evidence.

## 2.5 Capture the AFTER plans

```powershell
cmd /c "psql -U postgres -d retiro -f portfolio-2-query-optimisation/02_explain_queries.sql > portfolio-2-query-optimisation/plans/after.txt 2>&1"
```

(Run twice, keep the second.) Put before.txt and after.txt side by side in VS Code: right-click before.txt → Select for Compare, right-click after.txt → Compare with Selected. Screenshot the comparison for Q1 and Q5.

## 2.6 What you should see (my test run)

| Query | Before | After | What changed in the plan |
|---|---|---|---|
| Q1 guest history | 20.7 ms | 0.19 ms | Seq Scan on booking (90k rows) → Bitmap Index Scan on idx_booking_guest (3 rows) |
| Q2 availability | 14.2 ms | 1.15 ms | Planner switched from the exclusion-constraint GiST index to the B-tree idx_booking_room_dates |
| Q3 revenue 2025 | 9.7 ms | 4.4 ms | Seq Scan on payment → Bitmap Index Scan on idx_payment_paid_at; smaller gain because ~6% of rows match |
| Q4 top items | 31.1 ms | 28.4 ms | Orders now found by index, but Seq Scan on order_item (160k rows) for the hash join remains the bottleneck |
| Q5 arrivals | 8.5 ms | 0.29 ms | Seq Scan on booking → Index Scan using idx_booking_check_in |
| Q6 status count | 15.6 ms | 17.3 ms | No change: index ignored, still Seq Scan — 95% of rows match, so reading the table is cheaper |

Q2, Q4 and Q6 are the interesting ones for your analysis:

- Q2: the exclusion constraint from Portfolio 1 already created a GiST index the planner could use before you added anything — a constraint doubling as an index.
- Q4: an index only helps the step it targets; the plan's slowest step moved to the order_item join. Suggest a next step (e.g. a summary table or materialised view of daily item counts) — you don't have to build it.
- Q6: selectivity. An index helps when a condition matches few rows.

## 2.7 Write the Portfolio 2 README

```markdown
# Portfolio 2 — Query Processing and Optimisation

## Dataset
(Table sizes after 01_bulk_data.sql; why a large dataset is needed.)

## How PostgreSQL processes a query
(Parse → rewrite → plan/optimise (cost-based, uses statistics) → execute. 3–4 sentences.)

## Queries
(For each Q1–Q6: the business question, the SQL, a result screenshot.)

## Method
1. Ran 02_explain_queries.sql → plans/before.txt (second, warm-cache run)
2. Ran 03_indexes.sql (+ ANALYZE)
3. Ran 02_explain_queries.sql → plans/after.txt

## Results
(Your before/after table, with YOUR numbers.)

## Analysis
(Q2 GiST vs B-tree, Q4 bottleneck moved, Q6 selectivity. Composite index column order.)

## Cost of indexing
(Index sizes from 03_indexes.sql; indexes slow INSERT/UPDATE because each index must
also be updated — e.g. every new booking now updates 5 indexes.)
```

Commit: `git add . ; git commit -m "P2: indexes, after-plans and performance analysis" ; git push`

# Portfolio 3 lab — Transactions & Concurrency (Oct 27–Nov 1)

Five experiments: two run from a file, three need two psql windows side by side pretending to be two receptionists. All were tested; the expected output under each is what you should see.

## 3.1 Experiment 1 — COMMIT (file)

```sql
Create portfolio-3-transactions-concurrency/experiments/exp1_commit.sql:
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
```

```powershell
cmd /c "psql -U postgres -d retiro -f portfolio-3-transactions-concurrency/experiments/exp1_commit.sql > portfolio-3-transactions-concurrency/exp1_output.txt 2>&1"
Get-Content portfolio-3-transactions-concurrency/exp1_output.txt
```

Expected: BEGIN, INSERT 0 1, INSERT 0 1, COMMIT, then one row: check-in 2026-12-01, amount 300000.00, card, successful.

## 3.2 Experiment 2 — ROLLBACK and SAVEPOINT (file)

Create experiments/exp2_rollback_savepoint.sql:

```sql
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
```

Run it the same way, saving to exp2_output.txt.

Expected:

- 2a: ERROR: ... violates check constraint "payment_amount_check", then current transaction is aborted, commands ignored, then ROLLBACK, then bookings_saved = 0. Atomicity: the booking insert succeeded, yet it vanished because its partner failed.
- 2b: price shows 1.00 inside the transaction, 150000.00 after ROLLBACK.
- 2c: an error about breakfast_order_status_check, but the final row shows the booking with amount 300000.00 and breakfast_orders = 0.

Commit: `git add . ; git commit -m "P3: commit, rollback and savepoint experiments" ; git push`

## 3.3 Setting up the two-window experiments

1. Open two PowerShell windows. Snap one left (Windows key + ←) and one right (Windows key + →).
2. In both: $env:PGPASSWORD = "your-password" then psql -U postgres -d retiro.
3. Label each window so screenshots are clear. In the left window type \set PROMPT1 'A %/=# ', in the right \set PROMPT1 'B %/=# '. The prompts now read A retiro=# and B retiro=#.
4. Type \timing on in both.
5. Follow the step order exactly. Each step says which window. Don't press Enter in the wrong window early — the order is the experiment.
6. Screenshot the full screen (both windows) at the marked moments. Afterwards, save the commands you typed into experiments/exp3_session_A.sql, exp3_session_B.sql and so on, as a record.

## 3.4 Experiment 3 — isolation levels: non-repeatable read

### Part 1, READ COMMITTED (Postgres default):

| Step | Window | Type this | You should see |
|---|---|---|---|
| 1 | A | BEGIN ISOLATION LEVEL READ COMMITTED; | BEGIN |
| 2 | A | SELECT price_per_night FROM room_type WHERE name = 'Deluxe'; | 70000.00 |
| 3 | B | UPDATE room_type SET price_per_night = 80000 WHERE name = 'Deluxe'; | UPDATE 1 (auto-commits) |
| 4 | A | SELECT price_per_night FROM room_type WHERE name = 'Deluxe'; | 80000.00 — changed inside A's transaction. Screenshot. |
| 5 | A | COMMIT; | COMMIT |

### Part 2, REPEATABLE READ:

| Step | Window | Type this | You should see |
|---|---|---|---|
| 6 | A | BEGIN ISOLATION LEVEL REPEATABLE READ; | BEGIN |
| 7 | A | SELECT price_per_night FROM room_type WHERE name = 'Deluxe'; | 80000.00 |
| 8 | B | UPDATE room_type SET price_per_night = 90000 WHERE name = 'Deluxe'; | UPDATE 1 |
| 9 | A | SELECT price_per_night FROM room_type WHERE name = 'Deluxe'; | still 80000.00 — A sees its snapshot. Screenshot. |
| 10 | A | COMMIT; then the same SELECT | now 90000.00 |
| 11 | B | UPDATE room_type SET price_per_night = 70000 WHERE name = 'Deluxe'; | reset for later |

Explain in the README: under Read Committed each statement sees the latest committed data; under Repeatable Read the whole transaction sees one snapshot taken at its first query. That's MVCC: Postgres kept the old row version for A while B wrote a new one, and neither blocked the other.

## 3.5 Experiment 4 — the double booking (the headline)

Setup (either window, once). A copy of booking without the exclusion constraint, so the bug can happen:

```sql
DROP TABLE IF EXISTS booking_demo;
CREATE TABLE booking_demo (LIKE booking INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING IDENTITY);
```

LIKE ... INCLUDING CONSTRAINTS copies the CHECK constraints but not the exclusion constraint — exactly what we want.

The availability check both receptionists run (copy it somewhere handy):

```sql
SELECT count(*) AS clashes FROM booking_demo
WHERE room_id = (SELECT room_id FROM room WHERE room_number = '101')
  AND status <> 'cancelled'
  AND check_in < DATE '2026-12-22' AND check_out > DATE '2026-12-20';
```

### 4a. The problem (READ COMMITTED, no protection):

| Step | Window | Type this | You should see |
|---|---|---|---|
| 1 | A | BEGIN; |  |
| 2 | A | the availability check | clashes = 0 — room looks free |
| 3 | B | BEGIN; |  |
| 4 | B | the availability check | clashes = 0 — B also sees it free |
| 5 | A | INSERT INTO booking_demo (guest_id, room_id, check_in, check_out, num_guests) VALUES (4, (SELECT room_id FROM room WHERE room_number='101'), '2026-12-20', '2026-12-22', 1); | INSERT 0 1 |
| 6 | B | same INSERT but guest_id 7 | INSERT 0 1 |
| 7 | A | COMMIT; |  |
| 8 | B | COMMIT; |  |
| 9 | A | SELECT guest_id, check_in, check_out FROM booking_demo; | two rows, guests 4 and 7, same room, same nights. Screenshot. |

This is write skew: each transaction checked a condition that was true, then both wrote, and together they broke the rule. Then reset: TRUNCATE booking_demo;

### 4b. Fix 1 — pessimistic locking with SELECT ... FOR UPDATE:

| Step | Window | Type this | You should see |
|---|---|---|---|
| 1 | A | BEGIN; then SELECT room_id FROM room WHERE room_number = '101' FOR UPDATE; | locks room 101's row |
| 2 | A | the availability check | clashes = 0 |
| 3 | B | BEGIN; then SELECT room_id FROM room WHERE room_number = '101' FOR UPDATE; | B hangs — no prompt. It's waiting for A's lock. Screenshot. |
| 4 | A | the INSERT (guest 4), then COMMIT; | B instantly un-freezes and shows room_id 1 |
| 5 | B | the availability check | clashes = 1 — B now sees A's booking |
| 6 | B | ROLLBACK; | the receptionist tells guest 7 the room is taken |

Reset: TRUNCATE booking_demo;

### 4c. Fix 2 — SERIALIZABLE isolation (optimistic):

Repeat 4a's steps exactly, but in steps 1 and 3 type BEGIN ISOLATION LEVEL SERIALIZABLE; instead of BEGIN;.

Expected: at step 6, B gets ERROR: could not serialize access due to read/write dependencies among transactions with HINT: The transaction might succeed if retried. — SQLSTATE 40001. A commits normally; only one row exists. Screenshot. Then B types ROLLBACK;. In a real app, the code catches 40001 and retries; on retry, the check would show the clash.

Reset: TRUNCATE booking_demo;

### 4d. Fix 3 — the exclusion constraint from Portfolio 1:

Repeat 4a, but use the real booking table instead of booking_demo in both the check and the INSERT.

Expected: at step 6, B's INSERT hangs (waiting to see whether A commits). After A's COMMIT, B gets ERROR: conflicting key value violates exclusion constraint "no_double_booking" (SQLSTATE 23P01). Screenshot. B: ROLLBACK;. Clean up from A: DELETE FROM booking WHERE room_id = (SELECT room_id FROM room WHERE room_number='101') AND check_in = '2026-12-20';

Compare in the README:

| Approach | How it works | Pro | Con |
|---|---|---|---|
| No control | — | Fast | Double bookings |
| FOR UPDATE | Lock first; others wait | Simple, predictable | Waiting; risk of deadlock |
| SERIALIZABLE | Detect conflict, abort one | No manual locks | App must retry on 40001 |
| Exclusion constraint | Database rule on the data itself | Impossible to bypass, any isolation level | Only for rules expressible as a constraint |

Commit: `git add . ; git commit -m "P3: double-booking race and three fixes" ; git push`

## 3.6 Experiment 5 — deadlock

| Step | Window | Type this | You should see |
|---|---|---|---|
| 1 | A | BEGIN; then UPDATE room SET status = 'maintenance' WHERE room_number = '102'; | UPDATE 1 |
| 2 | B | BEGIN; then UPDATE room SET status = 'maintenance' WHERE room_number = '103'; | UPDATE 1 |
| 3 | A | UPDATE room SET status = 'maintenance' WHERE room_number = '103'; | A hangs (waits for B) |
| 4 | B | UPDATE room SET status = 'maintenance' WHERE room_number = '102'; | after ~1 second, one window shows ERROR: deadlock detected with details of both processes. Screenshot. |
| 5 | both | ROLLBACK; | rooms stay available |

A waited for B while B waited for A — neither could ever finish, so Postgres's deadlock detector (runs after deadlock_timeout, default 1 s) killed one. Prevention: always lock rows in the same order (e.g. by room number).

## 3.7 Write the Portfolio 3 README

```markdown
# Portfolio 3 — Transactions and Concurrency

## ACID in the Retiro context
(One sentence + Retiro example for each of A, C, I, D.)

## Experiments
For each of 1–5:
- Goal / concept tested
- Steps (or link to the .sql file)
- Expected result
- Actual result + screenshot
- What it proves

## Isolation levels
(Table of anomalies vs levels; what you observed in Experiment 3; Postgres notes:
Read Uncommitted behaves as Read Committed; MVCC.)

## Choosing a concurrency control for Retiro
(Your comparison table from 4b–4d and your recommendation, e.g.
exclusion constraint as the guarantee + FOR UPDATE in the booking API.)
```

Commit: `git add . ; git commit -m "P3: deadlock experiment and README" ; git push`

# Portfolio 4 lab — NoSQL with MongoDB and Redis (Nov 2–5)

You'll run MongoDB (document store) and Redis (key-value store) in Docker, load three collections, query and aggregate them, and prove validation and indexing work. Docker Desktop must be open and showing Engine running.

Note: I couldn't run MongoDB in my test environment, so these scripts are syntax-checked but not executed. If any line errors, copy the exact message and ask — it'll be a small fix.

## 4.1 Start MongoDB (Terminal, from the repo root)

```powershell
cd ~\Documents\advanced-database-portfolio
docker run -d --name retiro-mongo -p 27017:27017 -v "${PWD}/portfolio-4-nosql/mongo:/scripts" mongo:7
docker ps
```

What this does: downloads the official MongoDB 7 image (first time only, ~700 MB), starts a container named retiro-mongo, opens port 27017, and makes your repo's portfolio-4-nosql/mongo folder visible inside the container as /scripts. docker ps should list retiro-mongo with status Up.

Next time (after a restart): docker start retiro-mongo.

## 4.2 Create the collections

Create portfolio-4-nosql/mongo/01_setup.js:

```javascript
// =============================================================
// Retiro Resort — Portfolio 4: MongoDB collections with validation
// Run (Terminal, from the repo root, with the retiro-mongo container running):
//   docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/01_setup.js
// =============================================================

// Start clean so the script can be re-run
db.menu_items.drop();
db.guest_profiles.drop();
db.reviews.drop();

// ---------- 1. MENU ITEMS: every item has different options ----------
// $jsonSchema = rules MongoDB checks on every insert/update (schema validation)
db.createCollection("menu_items", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "category", "price", "available"],
      properties: {
        name:      { bsonType: "string", description: "item name is required" },
        category:  { enum: ["local", "continental", "drink", "side"] },
        price:     { bsonType: ["int", "double"], minimum: 1, description: "price in naira, must be > 0" },
        available: { bsonType: "bool" },
        options:   { bsonType: "object", description: "free-form: differs per item" },
        dietary_tags: { bsonType: "array", items: { bsonType: "string" } }
      }
    }
  }
});

db.menu_items.insertMany([
  { _id: "akara_pap", name: "Akara and Pap", category: "local", price: 3500, available: true,
    options: { pap_type: ["white", "yellow"], extra_akara: { price: 500 } },
    dietary_tags: ["vegetarian"] },
  { _id: "yam_egg", name: "Yam and Egg Sauce", category: "local", price: 4500, available: true,
    options: { yam_style: ["boiled", "fried"], spice_level: ["mild", "hot"] },
    dietary_tags: ["vegetarian", "gluten-free"] },
  { _id: "jollof_plate", name: "Jollof Breakfast Plate", category: "local", price: 5000, available: true,
    options: { protein: ["chicken", "fish", "egg"], spice_level: ["mild", "hot"] },
    dietary_tags: ["gluten-free"] },
  { _id: "full_english", name: "Full English Breakfast", category: "continental", price: 7500, available: true,
    options: { eggs: ["fried", "scrambled", "poached"], toast: ["white", "brown"], protein: ["sausage", "bacon"] },
    dietary_tags: [] },
  { _id: "pancakes", name: "Pancakes with Honey", category: "continental", price: 4000, available: true,
    options: { topping: ["honey", "syrup", "fruit"] }, dietary_tags: ["vegetarian"] },
  { _id: "fruit_platter", name: "Fruit Platter", category: "side", price: 3000, available: true,
    dietary_tags: ["vegan", "gluten-free"] },                         // no options at all
  { _id: "tea", name: "Tea", category: "drink", price: 1500, available: true,
    options: { milk: ["none", "regular", "soy"], sugar: true }, dietary_tags: ["vegetarian"] },
  { _id: "coffee", name: "Coffee", category: "drink", price: 2000, available: true,
    options: { style: ["black", "latte", "cappuccino"] }, dietary_tags: ["vegetarian"] },
  { _id: "orange_juice", name: "Fresh Orange Juice", category: "drink", price: 2500, available: false,
    options: { size: { regular: 2500, large: 3500 } }, dietary_tags: ["vegan"] }
]);

// ---------- 2. GUEST PROFILES: one document = everything about a guest ----------
// Preferences are EMBEDDED (always read with the guest).
// recent_stays REFERENCES PostgreSQL booking_ids and keeps only the last few,
// because a guest's full history grows without limit (16 MB document cap).
db.guest_profiles.insertMany([
  { _id: 1, name: { first: "Adaeze", last: "Okafor" }, email: "adaeze.okafor@example.com",
    preferences: { room: "garden view", pillow: "firm", dietary: ["no pork"], breakfast_time: "07:30" },
    loyalty: { tier: "gold", total_stays: 2 },
    recent_stays: [ { booking_id: 1, room: "101", check_in: ISODate("2026-10-02") },
                    { booking_id: 11, room: "C3", check_in: ISODate("2026-12-23") } ] },
  { _id: 3, name: { first: "Kofi", last: "Mensah" }, email: "kofi.mensah@example.com",
    preferences: { room: "sea view", dietary: ["vegetarian"], extra_bed: true },
    loyalty: { tier: "silver", total_stays: 1 },
    recent_stays: [ { booking_id: 3, room: "301", check_in: ISODate("2026-10-09") } ] },
  { _id: 4, name: { first: "Sarah", last: "Williams" }, email: "sarah.williams@example.com",
    preferences: { room: "beach chalet", dietary: ["gluten-free"], airport_pickup: { needed: true, flight: "BA75" } },
    loyalty: { tier: "silver", total_stays: 1 },
    recent_stays: [ { booking_id: 4, room: "C1", check_in: ISODate("2026-10-10") } ] }
]);

// ---------- 3. REVIEWS: flexible text, tags and staff replies ----------
db.reviews.insertMany([
  { booking_id: 1, guest_id: 1, rating: 5, created_at: ISODate("2026-10-05"),
    comment: "Lovely garden view and the akara was perfect.", tags: ["food", "view"],
    staff_responses: [ { staff: "Sola Hassan", text: "Thank you, Adaeze!", at: ISODate("2026-10-06") } ] },
  { booking_id: 3, guest_id: 3, rating: 4, created_at: ISODate("2026-10-12"),
    comment: "Great suite. Breakfast arrived 15 minutes late.", tags: ["room", "breakfast-delay"] },
  { booking_id: 4, guest_id: 4, rating: 5, created_at: ISODate("2026-10-14"),
    comment: "The beach chalet is worth every naira.", tags: ["room", "beach", "value"] }
]);

// Add 5,000 synthetic reviews so indexes and explain() have something to work on
const tagPool = ["food", "room", "beach", "staff", "value", "breakfast-delay", "noise", "wifi", "pool"];
const bulk = [];
for (let i = 0; i < 5000; i++) {
  bulk.push({
    booking_id: 100000 + i,
    guest_id: 1 + (i % 3000),
    rating: 1 + (Math.floor(i / 5) % 5),
    created_at: new Date(Date.UTC(2022 + (i % 5), i % 12, 1 + (i % 28))),
    comment: "Synthetic review " + i,
    tags: [tagPool[i % tagPool.length], tagPool[(i * 7) % tagPool.length]]
  });
}
db.reviews.insertMany(bulk);

print("menu_items:     " + db.menu_items.countDocuments());
print("guest_profiles: " + db.guest_profiles.countDocuments());
print("reviews:        " + db.reviews.countDocuments());
```

Run it:

```powershell
docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/01_setup.js
```

Expected: menu_items: 9, guest_profiles: 3, reviews: 5003. Screenshot.

Design decisions to explain in your README:

- Menu items are the textbook case for documents: jollof has a protein choice, tea has milk, the fruit platter has no options. In SQL that needs either many mostly-empty columns or extra option tables.
- Guest preferences are embedded — always loaded with the guest, owned by the guest, small.
- recent_stays references PostgreSQL booking_ids and keeps only a few: full history grows forever, and bookings/payments must stay in SQL for ACID.
- guest_profiles._id reuses the PostgreSQL guest_id, linking the two databases.

## 4.3 Look at it in Compass (optional, great screenshots)

Open MongoDB Compass → Add new connection → URI mongodb://localhost:27017 → Connect. Open retiro → menu_items: you'll see each document has a different shape. Click the Validation tab to show your $jsonSchema rules. Screenshot both.

## 4.4 Queries, aggregation and indexing

Create portfolio-4-nosql/mongo/02_queries.js:

// =============================================================

```javascript
// Retiro Resort — Portfolio 4: queries, updates, aggregation, indexes
//   docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/02_queries.js
// =============================================================

print("\n=== Q1. Menu items where the guest chooses a protein (query inside a nested field) ===");
printjson(db.menu_items.find(
  { "options.protein": { $exists: true } },
  { _id: 0, name: 1, "options.protein": 1 }
).toArray());

print("\n=== Q2. Available vegetarian items under N5,000, cheapest first ===");
printjson(db.menu_items.find(
  { dietary_tags: "vegetarian", available: true, price: { $lt: 5000 } },
  { _id: 0, name: 1, price: 1 }
).sort({ price: 1 }).toArray());

print("\n=== Q3. UPDATE: orange juice is back in stock, and gains a new option ===");
db.menu_items.updateOne(
  { _id: "orange_juice" },
  { $set: { available: true, "options.ice": [true, false] } }
);
printjson(db.menu_items.findOne({ _id: "orange_juice" }));

print("\n=== Q4. Guests whose profile says vegetarian (for the kitchen) ===");
printjson(db.guest_profiles.find(
  { "preferences.dietary": "vegetarian" },
  { _id: 1, name: 1, "preferences.dietary": 1 }
).toArray());

print("\n=== Q5. AGGREGATION: average rating and number of reviews per year ===");
printjson(db.reviews.aggregate([
  { $group: { _id: { $year: "$created_at" },
              avg_rating: { $avg: "$rating" },
              reviews: { $sum: 1 } } },
  { $project: { _id: 0, year: "$_id", reviews: 1, avg_rating: { $round: ["$avg_rating", 2] } } },
  { $sort: { year: 1 } }
]).toArray());

print("\n=== Q6. AGGREGATION: most common complaint tags in 1-2 star reviews ===");
printjson(db.reviews.aggregate([
  { $match: { rating: { $lte: 2 } } },
  { $unwind: "$tags" },
  { $group: { _id: "$tags", times: { $sum: 1 } } },
  { $sort: { times: -1 } },
  { $limit: 5 }
]).toArray());

print("\n=== Q7. $lookup: real reviews joined with the guest's profile (like a SQL JOIN) ===");
printjson(db.reviews.aggregate([
  { $match: { booking_id: { $lt: 100000 } } },
  { $lookup: { from: "guest_profiles", localField: "guest_id", foreignField: "_id", as: "guest" } },
  { $unwind: "$guest" },
  { $project: { _id: 0, rating: 1, comment: 1, guest: "$guest.name.first", tier: "$guest.loyalty.tier" } }
]).toArray());

// ---------- Indexing and explain() — links back to Portfolio 2 ----------
function planSummary(label, exp) {
  const plan = JSON.stringify(exp.queryPlanner.winningPlan);
  const s = exp.executionStats;
  print(label + ": " + (plan.includes("IXSCAN") ? "IXSCAN (index used)" : "COLLSCAN (every document read)")
        + " | documents examined: " + s.totalDocsExamined
        + " | returned: " + s.nReturned
        + " | time: " + s.executionTimeMillis + " ms");
}

const recentFiveStars = { rating: 5, created_at: { $gte: ISODate("2026-01-01") } };

print("\n=== Q8. explain() BEFORE index: 5-star reviews since Jan 2026 ===");
db.reviews.dropIndexes();   // remove our index if the script is re-run (keeps _id index)
planSummary("Before", db.reviews.find(recentFiveStars).explain("executionStats"));

db.reviews.createIndex({ rating: 1, created_at: -1 });   // equality field first, then range
print("Created index { rating: 1, created_at: -1 }");

planSummary("After ", db.reviews.find(recentFiveStars).explain("executionStats"));

print("\nIndexes on reviews:");
printjson(db.reviews.getIndexes().map(i => i.name));
```

Run it and save the output:

```powershell
cmd /c "docker exec retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/02_queries.js > portfolio-4-nosql/queries_output.txt 2>&1"
Get-Content portfolio-4-nosql/queries_output.txt
```

(No -it here because the output goes to a file.)

Expected: Q1 lists Jollof and Full English; Q3 shows orange juice with available: true and a new ice option — no schema change needed; Q5 shows 2022–2026 with about 1,000 reviews each; Q7 shows Adaeze (gold), Kofi and Sarah. Q8 is the key line pair: Before: COLLSCAN, ~5,003 examined → After: IXSCAN, ~200 examined, the same number returned.

## 4.5 Prove the validation works

Create portfolio-4-nosql/mongo/03_validation_test.js:

```javascript
// =============================================================
// Retiro Resort — Portfolio 4: schema validation test
// The insert below is SUPPOSED TO FAIL (negative price, missing 'available').
// =============================================================
try {
  db.menu_items.insertOne({ name: "Free Plantain", category: "side", price: -100 });
  print("Inserted — validation did NOT work (unexpected)");
} catch (e) {
  print("Rejected as expected: " + e.message);
  if (e.errInfo) printjson(e.errInfo.details);
}
```

```powershell
docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/03_validation_test.js
```

Expected: Rejected as expected: Document failed validation, followed by details naming the missing available field and the price minimum. Screenshot.

Commit: `git add . ; git commit -m "P4: MongoDB collections, queries, aggregation, validation" ; git push`

## 4.6 Redis key-value example (optional but strong)

```powershell
docker run -d --name retiro-redis -p 6379:6379 redis:7
docker exec -it retiro-redis redis-cli
```

You're now at the 127.0.0.1:6379> prompt. Type each line and screenshot the session:

```text
SET availability:2026-11-20:deluxe "201,202,203" EX 300
GET availability:2026-11-20:deluxe
TTL availability:2026-11-20:deluxe
HSET room:201 type Deluxe price 70000 status available
HGETALL room:201
INCR breakfast_orders:2026-10-13
INCR breakfast_orders:2026-10-13
GET breakfast_orders:2026-10-13
DEL availability:2026-11-20:deluxe
GET availability:2026-11-20:deluxe
exit
```

Save those commands in portfolio-4-nosql/redis_commands.txt.

What it shows:

- Cache-aside: the website checks Redis first for availability; on a miss it runs the Portfolio 2 Q2 query in PostgreSQL and stores the answer with EX 300 (expires in 5 minutes). TTL shows the seconds left.
- Invalidation: when a booking is made, the app runs DEL on that key so no guest sees stale availability. Last GET returns (nil).
- Hash = a small record under one key. INCR = an atomic counter, safe even with many simultaneous QR orders.

## 4.7 Write the Portfolio 4 README

```markdown
# Portfolio 4 — NoSQL and Advanced Data Models

## Why NoSQL for part of Retiro
(Which data is flexible/variable — menu, preferences, reviews — and which must stay relational.)

## Data model
(The three collections, an example document of each, embed vs reference decisions and why.)

## Implementation
(How to run 01–03 scripts; screenshots from mongosh/Compass.)

## Queries and aggregation
(Q1–Q7 with output and what each demonstrates.)

## Indexing
(Q8 before/after: COLLSCAN vs IXSCAN, documents examined.)

## Key-value example (Redis)
(Cache-aside availability, expiry, invalidation.)

## SQL vs NoSQL comparison for Retiro
| Data | PostgreSQL | MongoDB/Redis | Choice and why |

## What should NOT move to NoSQL
(Bookings, payments: ACID, the exclusion constraint, money. Polyglot persistence.)
```

Commit: `git add . ; git commit -m "P4: Redis example and README" ; git push`

# Portfolio 5 lab — Distributed & Cloud (Nov 6–10)

Three hands-on parts: (A) a PostgreSQL primary and a live replica in Docker, including a failover; (B) partitioning, the single-server form of sharding; (C) MongoDB Atlas in the cloud. Then the written discussion. I verified the replication, failover and partitioning steps on two real PostgreSQL 16 servers; the Docker wrapper itself couldn't be run in my environment.

## 5.1 Create the three configuration files

portfolio-5-distributed-cloud/docker-compose.yml:

```yaml
# =============================================================
# Retiro Resort — Portfolio 5: PostgreSQL primary + streaming replica
# Start:  docker compose up -d        (run inside portfolio-5-distributed-cloud)
# Stop and delete all data:  docker compose down -v
# Primary  -> localhost:5433  (reads AND writes)
# Replica  -> localhost:5434  (read-only copy, streams changes from primary)
# =============================================================
services:
  pg-primary:
    image: postgres:16
    container_name: retiro-primary
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres        # lab-only password; never use in production
      POSTGRES_DB: retiro
    command:
      - postgres
      - -c
      - wal_level=replica                # write enough WAL for a replica to replay
      - -c
      - max_wal_senders=10               # how many replicas may connect
      - -c
      - hba_file=/etc/postgresql/pg_hba.conf   # our access rules (allow replication)
    volumes:
      - ./config/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro
      - ./config/primary-init:/docker-entrypoint-initdb.d:ro   # creates the replicator user
    ports:
      - "5433:5432"

  pg-replica:
    image: postgres:16
    container_name: retiro-replica
    user: postgres
    depends_on:
      - pg-primary
    environment:
      PGPASSWORD: replpass               # password of the replicator user (see primary-init)
    ports:
      - "5434:5432"
    entrypoint: ["bash", "-c"]
    command:
      - |
        until pg_isready -h pg-primary -p 5432; do echo "waiting for primary..."; sleep 2; done
        rm -rf /var/lib/postgresql/data/*
        pg_basebackup -h pg-primary -p 5432 -U replicator -D /var/lib/postgresql/data -R -X stream -P
        chmod 0700 /var/lib/postgresql/data
        exec postgres -c hot_standby=on
```

portfolio-5-distributed-cloud/config/pg_hba.conf:

```text
# PostgreSQL client authentication rules for the PRIMARY
# TYPE  DATABASE     USER        ADDRESS       METHOD
local   all          all                       trust
host    all          all         127.0.0.1/32  trust
host    all          all         all           scram-sha-256
host    replication  replicator  all           scram-sha-256
```

portfolio-5-distributed-cloud/config/primary-init/01_replication_user.sql (create the primary-init folder first):

```sql
-- Runs once, automatically, when the primary is first created.
-- A dedicated login that is only allowed to stream replication data.
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replpass';
```

What these do:

- The primary is a normal Postgres that also writes enough of its write-ahead log (WAL) for others to replay. pg_hba.conf's last line lets the replicator user connect for replication.
- The replica waits until the primary is up, copies its entire data directory with pg_basebackup, and -R writes the settings that make it a standby. Then it starts and keeps streaming WAL from the primary, replaying every change.
- 5433/5434 avoid clashing with your local Postgres on 5432.

## 5.2 Start the cluster (Terminal)

```powershell
cd ~\Documents\advanced-database-portfolio\portfolio-5-distributed-cloud
docker compose up -d
docker compose ps
docker compose logs pg-replica
```

Expected: both containers running. The replica log ends with lines like started streaming WAL from primary and database system is ready to accept read-only connections. Screenshot the log. (Save it too: cmd /c "docker compose logs pg-replica > replica_log.txt 2>&1".)

## 5.3 Prove replication works

The cluster's password is postgres (different from your local one):

```powershell
$env:PGPASSWORD = "postgres"
```

1. The primary sees its replica:

```powershell
psql -h localhost -p 5433 -U postgres -d retiro -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn, replay_lag FROM pg_stat_replication;"
```

Expected: one row, state = streaming, sync_state = async. Screenshot.

2. Load your Retiro schema and data into the primary only:

```powershell
psql -h localhost -p 5433 -U postgres -d retiro -f ../portfolio-1-database-design/01_schema.sql
psql -h localhost -p 5433 -U postgres -d retiro -f ../portfolio-1-database-design/02_seed_data.sql
```

3. Read it from the replica (you never loaded anything there):

```powershell
psql -h localhost -p 5434 -U postgres -d retiro -c "SELECT pg_is_in_recovery() AS i_am_a_replica;" -c "SELECT count(*) FROM booking;"
```

Expected: i_am_a_replica = t and count = 12. Screenshot — this is your core replication evidence.

4. Writes on the replica are refused:

```powershell
psql -h localhost -p 5434 -U postgres -d retiro -c "INSERT INTO staff (first_name, last_name, role, email, hired_on) VALUES ('Test','User','front_desk','t@retiro.test','2026-11-01');"
```

Expected: ERROR: cannot execute INSERT in a read-only transaction. Screenshot.

5. A live change flows through: run the same INSERT on 5433 (primary), then the SELECT count(*) FROM staff on 5434 — it shows 7. Screenshot both.

Commit: `git add . ; git commit -m "P5: primary-replica streaming replication" ; git push`

## 5.4 Partitioning (on the primary)

Create portfolio-5-distributed-cloud/02_partitioning.sql:

```sql
-- =============================================================
-- Retiro Resort — Portfolio 5: horizontal partitioning by date
-- Splits booking history into one partition per year. This is the
-- single-server version of sharding: same idea (split rows by a key),
-- but all partitions live on one machine.
-- =============================================================
DROP TABLE IF EXISTS booking_history CASCADE;

CREATE TABLE booking_history (
    booking_id  INT  NOT NULL,
    guest_id    INT  NOT NULL,
    room_number VARCHAR(10) NOT NULL,
    check_in    DATE NOT NULL,
    check_out   DATE NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (booking_id, check_in)        -- partition key must be part of the PK
) PARTITION BY RANGE (check_in);

CREATE TABLE booking_history_2024 PARTITION OF booking_history
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE booking_history_2025 PARTITION OF booking_history
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE booking_history_2026 PARTITION OF booking_history
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE booking_history_other PARTITION OF booking_history DEFAULT;  -- anything else

-- 60,000 synthetic stays spread over 2023-2026
INSERT INTO booking_history
SELECT g,
       1 + (g % 30000),
       'B' || lpad((1 + g % 48)::text, 3, '0'),
       DATE '2023-01-01' + (g % 1460),
       DATE '2023-01-01' + (g % 1460) + 2,
       90000 + (g % 5) * 30000
FROM generate_series(1, 60000) AS g;

ANALYZE booking_history;

\echo '--- Rows per partition ---'
SELECT tableoid::regclass AS partition, count(*)
FROM booking_history GROUP BY 1 ORDER BY 1;

\echo '--- Partition pruning: a 2025 query only scans the 2025 partition ---'
EXPLAIN (ANALYZE)
SELECT count(*), sum(amount)
FROM booking_history
WHERE check_in >= '2025-06-01' AND check_in < '2025-07-01';
```

```powershell
cmd /c "psql -h localhost -p 5433 -U postgres -d retiro -f 02_partitioning.sql > partitioning_output.txt 2>&1"
Get-Content partitioning_output.txt
```

Expected (tested): four partitions of about 15,000 rows each, and a plan containing only Seq Scan on booking_history_2025 — the planner skipped the other three partitions entirely (partition pruning). Then confirm it replicated: psql -h localhost -p 5434 -U postgres -d retiro -c "SELECT count(*) FROM booking_history;" → 60000.

Explain the link to sharding: partitioning splits rows by a key on one server; sharding puts those partitions on different servers. For Retiro, yearly partitions suit history reports; if Retiro opened several branches, branch_id would be the natural shard key, because each branch's front desk mostly queries its own bookings.

## 5.5 Failover

Simulate the primary server dying:

```powershell
docker stop retiro-primary
psql -h localhost -p 5434 -U postgres -d retiro -c "SELECT pg_promote();" -c "SELECT pg_is_in_recovery();"
psql -h localhost -p 5434 -U postgres -d retiro -c "INSERT INTO staff (first_name, last_name, role, email, hired_on) VALUES ('After','Failover','manager','failover@retiro.test','2026-11-08');"
```

Expected (tested): pg_promote = t, pg_is_in_recovery = f (no longer a replica), and the INSERT now succeeds — the replica took over as the new primary. Screenshot all three.

Point out in your README that this failover was manual. Managed cloud databases (and MongoDB replica sets, next) do it automatically. Also note that with asynchronous replication, any writes not yet streamed when the primary died would be lost.

When finished, clean up: docker compose down -v (the -v deletes the cluster's data).

Commit: `git add . ; git commit -m "P5: partitioning and manual failover" ; git push`

## 5.6 Cloud: MongoDB Atlas (free) — sign-up and deployment

1. Go to mongodb.com/cloud/atlas/register → Sign up with Google. Answer the welcome questions with anything reasonable.
2. When asked to deploy, choose the Free (M0) tier. Provider: AWS. Region: the nearest one offered for free. Cluster name: retiro-cluster. Click Create Deployment.
3. Security quickstart:
   - Database user: username retiro_admin, click Autogenerate password, copy the password into a note on your computer (not in the repo).
   - Network access: click Add My Current IP Address. (If your internet IP changes, add it again under Security → Network Access.)
4. On the cluster, click Connect → Shell. Copy the connection string; it looks like mongodb+srv://retiro-cluster.abc12.mongodb.net/.
5. Load your Portfolio 4 collections into the cloud, using mongosh inside your Docker container (replace the address):

```powershell
docker start retiro-mongo
docker exec -it retiro-mongo mongosh "mongodb+srv://retiro-cluster.abc12.mongodb.net/retiro" --username retiro_admin /scripts/01_setup.js
```

It asks for the password (paste it; nothing shows as you type). Expected: the same 9 / 3 / 5003 counts as before.

6. Prove it's a distributed replica set:

```powershell
docker exec -it retiro-mongo mongosh "mongodb+srv://retiro-cluster.abc12.mongodb.net/retiro" --username retiro_admin --eval "const h = db.hello(); printjson({ setName: h.setName, primary: h.primary, members: h.hosts })"
```

Expected: a replica set name and three host addresses — one primary, two secondaries. Screenshot.

7. In the Atlas website, screenshot: the cluster Overview (shows the 3 nodes and region), Browse Collections (your documents in the cloud) and Metrics.

Never commit the password or full connection string with a password. If you want to keep the address, put it in a .env file — already excluded by your .gitignore.

## 5.7 Write the Portfolio 5 README

```markdown
# Portfolio 5 — Distributed and Cloud Databases

## Target architecture for Retiro
(Diagram: apps → primary for writes; replicas for reads; cloud for availability.
Export the diagram from the Portfolio Guide or draw your own in draw.io.)

## A. Replication (Docker)
(Config files explained; evidence: pg_stat_replication, replica read, read-only error,
live change; sync vs async; replication lag and what it means for a guest.)

## B. Partitioning and sharding
(Partition evidence and pruning plan; shard key choice for a multi-branch Retiro;
range vs hash sharding; cross-shard queries.)

## C. Failover
(Manual promotion evidence; manual vs automatic; data-loss risk with async.)

## D. Cloud deployment (MongoDB Atlas)
(Screenshots; 3-node replica set from db.hello(); managed-service trade-offs:
cost, control, data location.)

## E. CAP and consistency for Retiro
| Data | Consistency needed | Why | Where it reads from |
| Room allocation & payments | Strong | No double booking, money | Primary only |
| Menu, reviews | Eventual is fine | A few seconds stale is harmless | Replica / cache |
During a network partition: bookings choose Consistency (refuse rather than double-book);
menu browsing chooses Availability.
```

Commit: `git add . ; git commit -m "P5: Atlas cloud deployment and distributed design discussion" ; git push`

# Final documentation (Nov 11–13)

Three things to write: the root README (the marker's front door on GitHub), the 2–3 page summary document (the LMS file), and the evidence PDF.

## F1. Root README.md (replace the whole file)

```markdown
# MIT 8103 Advanced Database Systems — Practical Portfolio

**Student:** Damassoh Japhet Setonji · **Student ID:** 301905154 · **Matric No:** 2026/A/MIT/0067
**Programme:** Master of Information Technology, MIVA Open University · 2026/2027 First Semester

## Case study: Retiro Resort, Lagos — Reservation & Guest Services Database
**Organisation:** Retiro Resort, a resort in Lagos State, Nigeria. The database models its real
operations; all records in this repository are simulated test data.
**Nature of the business:** Hospitality — room reservations, payments, check-in/check-out, and
QR-code breakfast ordering from guest rooms.
**Database users:** Guests, front-desk staff, kitchen staff, management, accounts.
**Major data stored:** Guests, room types, rooms, bookings, payments, staff, menu items,
breakfast orders, order items, reviews.
**Key operations:** Search availability, reserve a room, take payment, check in/out, place and
fulfil breakfast orders, cancel/refund, occupancy and revenue reports.

## Portfolio index
| # | Activity | Folder | Highlights |
|---|---|---|---|
| 1 | Database Design & Modelling | [portfolio-1-database-design](portfolio-1-database-design) | 10-table 3NF schema, exclusion constraint against double-booking |
| 2 | Query Processing & Optimisation | [portfolio-2-query-optimisation](portfolio-2-query-optimisation) | 6 queries, before/after plans, e.g. guest history 21 ms → 0.2 ms |
| 3 | Transactions & Concurrency | [portfolio-3-transactions-concurrency](portfolio-3-transactions-concurrency) | Double-booking race reproduced and fixed three ways |
| 4 | NoSQL & Advanced Data Models | [portfolio-4-nosql](portfolio-4-nosql) | MongoDB menu/profiles/reviews with validation; Redis cache |
| 5 | Distributed & Cloud | [portfolio-5-distributed-cloud](portfolio-5-distributed-cloud) | Streaming replica, failover, partitioning, MongoDB Atlas |

## Technology
PostgreSQL 16 · pgAdmin 4 · MongoDB 7 · Redis 7 · Docker Desktop · MongoDB Atlas (M0) · dbdiagram.io

## How to reproduce
1. `psql -U postgres -c "CREATE DATABASE retiro;"`
2. Portfolio 1: run `01_schema.sql`, `02_seed_data.sql`, `03_constraint_tests.sql`
3. Portfolio 2: run `01_bulk_data.sql`, `02_explain_queries.sql`, `03_indexes.sql`, `02_explain_queries.sql`
4. Portfolios 3–5: see each folder's README

## Documentation
- Final summary: [docs/](docs)
- AI Use Declaration and references: see the end of the summary document
```

Replace the numbers in Highlights with your own results.

## F2. The 2–3 page summary document

Write it in Word or Google Docs (Arial or Calibri 11, single spacing keeps you within 3 pages). Structure:

1. Header block — name, Student ID 301905154, matric number, course code and title, session, GitHub link.
2. Case study — one short paragraph (from the README).
3. Portfolio 1–5 — one paragraph each, 80–120 words: what you built, the key result with a number, where the evidence is. Example for P2:

   > I generated 90,000 synthetic bookings and analysed six queries with EXPLAIN ANALYZE. A B-tree index on booking(guest_id) changed the guest-history plan from a sequential scan of 90,012 rows to a bitmap index scan of 3, cutting execution time from 20.7 ms to 0.19 ms. An index on booking(status) was ignored by the planner because 95% of rows match, showing that selectivity determines index usefulness. Evidence: portfolio-2-query-optimisation/plans.

4. Individual technical reflection (~250 words) — use the prompts in the Portfolio Guide. Be specific about what went wrong and what you learned.
5. AI Use Declaration — use the template in the Portfolio Guide. State that Claude produced the guide, lab manual and starter scripts; that you ran every script yourself, captured your own outputs, and adapted the code (name what you changed).
6. References — for example:
   - PostgreSQL Global Development Group (2025) PostgreSQL 16 Documentation. Available at: postgresql.org/docs/16
   - MongoDB Inc. (2025) MongoDB Manual. Available at: mongodb.com/docs/manual
   - Elmasri, R. and Navathe, S. (2016) Fundamentals of Database Systems. 7th edn. Pearson.
   - Kleppmann, M. (2017) Designing Data-Intensive Applications. O'Reilly.

Save a copy of the source (.docx) in docs/ and commit it.

Export to PDF: Word → File → Save As → PDF; Google Docs → File → Download → PDF. Name it Damassoh_Japhet_Documentation.pdf.

## F3. The evidence PDF

1. Open a new Word/Google doc. Add a heading per portfolio.
2. Insert your best 2–4 screenshots under each, each with a one-line caption (e.g. Fig 3.2 — Session B blocked on SELECT FOR UPDATE while Session A holds the lock).
3. Export as Damassoh_Japhet_Evidence.pdf.

Commit: `git add . ; git commit -m "Final documentation and root README" ; git push`

# Packaging and submitting (Nov 14)

## S1. Final safety check of the repo (Terminal, repo root)

```powershell
git status
git log --oneline | Measure-Object
git grep -n -i "password"
```

git status should say nothing to commit. The second line counts your commits (aim for 25+). The git grep lists every line containing "password" — you should only see lab-only values (postgres, replpass) and comments, never your real local password or the Atlas password.

## S2. Make the repository public

On github.com → your repo → Settings → scroll to Danger Zone → Change visibility → Change to public → confirm. Then open the repo URL in a private/incognito browser window — it must load without signing in.

## S3. Download the repository backup

On the repo's main page: green Code button → Download ZIP. Rename the downloaded file to Damassoh_Japhet_Repository.zip.

## S4. Write the README.txt

In VS Code, create a new file Damassoh_Japhet_README.txt on your Desktop (not in the repo):

```text
Name: Damassoh Japhet Setonji
Student ID: 301905154
Matric No: 2026/A/MIT/0067
Course: MIT 8103 Advanced Database Systems — Individual Practical Database Portfolio
Case study: Retiro Resort, Lagos — Reservation & Guest Services Database (simulated data)
GitHub repository: https://github.com/YOUR-USERNAME/advanced-database-portfolio

Contents of this submission:
- Damassoh_Japhet_Documentation.pdf — 2-3 page summary, reflection, AI Use Declaration, references
- Damassoh_Japhet_Evidence.pdf — screenshots for Portfolios 1-5
- Damassoh_Japhet_Repository.zip — full copy of the GitHub repository at submission time

Repository map:
- portfolio-1-database-design/ — ER diagram, schema, seed data, constraint tests, normalisation
- portfolio-2-query-optimisation/ — bulk data, six queries, EXPLAIN plans before/after, indexes
- portfolio-3-transactions-concurrency/ — commit, rollback, isolation, double-booking, deadlock
- portfolio-4-nosql/ — MongoDB collections, queries, aggregation, validation; Redis
- portfolio-5-distributed-cloud/ — replication, failover, partitioning, MongoDB Atlas

Tools: PostgreSQL 16, MongoDB 7, Redis 7, Docker Desktop, MongoDB Atlas
```

## S5. Build the folder and zip (Terminal)

Put the three files (Damassoh_Japhet_Documentation.pdf, Damassoh_Japhet_Evidence.pdf, Damassoh_Japhet_Repository.zip) and Damassoh_Japhet_README.txt on your Desktop, then:

```powershell
cd ~\Desktop
$sub = "Damassoh_Japhet_301905154"
New-Item -ItemType Directory -Force -Path $sub | Out-Null
Copy-Item Damassoh_Japhet_README.txt, Damassoh_Japhet_Documentation.pdf, Damassoh_Japhet_Evidence.pdf, Damassoh_Japhet_Repository.zip -Destination $sub
Compress-Archive -Path $sub -DestinationPath "$sub.zip" -Force
Get-ChildItem $sub
```

Expected: the listing shows exactly four files with the correct names, and Damassoh_Japhet_301905154.zip appears on your Desktop. Double-click the zip to check it opens and contains the folder.

## S6. Upload

1. Log in to the Miva LMS → MIT 8103 → the CA submission.
2. Upload Damassoh_Japhet_301905154.zip and Damassoh_Japhet_README.txt.
3. Tick the naming-convention confirmation and submit.
4. Screenshot the confirmation page.
5. Stop pushing to the repo.

# Troubleshooting

| Error or symptom | Cause | Fix |
|---|---|---|
| psql : The term 'psql' is not recognized | PostgreSQL's bin folder isn't on PATH | Redo A4 step 3, then open a new terminal. Check the version number in the path matches what you installed (16 or 17) |
| password authentication failed for user "postgres" | Wrong password, or $env:PGPASSWORD set to the Docker one (postgres) while using local 5432 | Set $env:PGPASSWORD to the right password for the server you're connecting to |
| database "retiro" does not exist | Database not created | psql -U postgres -c "CREATE DATABASE retiro;" |
| relation "booking" does not exist | Scripts run out of order | Run P1 01_schema.sql then 02_seed_data.sql first |
| duplicate key value violates unique constraint "guest_email_key" when running 01_bulk_data.sql | Bulk script ran twice | Rerun P1 01_schema.sql, 02_seed_data.sql, then bulk once |
| could not open file ... No such file or directory with -f | Terminal isn't in the repo root | cd ~\Documents\advanced-database-portfolio first |
| psql prompt shows retiro-# or retiro(# and nothing runs | An unfinished statement — missing ; or an open bracket/quote | Type ; and Enter, or press Ctrl+C to cancel |
| psql stuck showing a wall of text with : at the bottom | Output pager | Press q. To disable: \pset pager off |
| Experiment window "frozen" in Portfolio 3 | It's waiting for the other window's lock — that's the experiment | Continue in the other window. If stuck, COMMIT; or ROLLBACK; in the other window |
| current transaction is aborted, commands ignored | An earlier error inside BEGIN | Type ROLLBACK; and start the transaction again |
| Docker: WSL 2 installation is incomplete or Virtualization not enabled | Virtualisation is off in BIOS | Restart → enter BIOS (usually F2, F10 or Del) → enable Intel VT-x / AMD-V / SVM → save. Then wsl --install again |
| error during connect ... docker_engine | Docker Desktop isn't running | Open Docker Desktop, wait for Engine running |
| Conflict. The container name "/retiro-mongo" is already in use | Container already exists | docker start retiro-mongo instead of docker run |
| port is already allocated | Something already uses that port | docker ps to find it; stop it with docker stop &lt;name> |
| mongosh: Could not find file /scripts/... | The volume path didn't map | Run docker run from the repo root; or docker rm -f retiro-mongo and redo 4.1 from the repo root |
| Replica log repeats waiting for primary... | Primary still initialising, or failed | docker compose logs pg-primary; if it errored, docker compose down -v then docker compose up -d |
| Replica: no pg_hba.conf entry for replication connection | pg_hba.conf not mounted (wrong folder or name) | Check the file is at portfolio-5-distributed-cloud/config/pg_hba.conf; docker compose down -v; up -d |
| After failover, replica won't restart | Its start command re-copies from the stopped primary | docker compose down -v and docker compose up -d for a fresh cluster |
| Atlas: connection times out | Your IP isn't in the access list | Atlas → Security → Network Access → Add Current IP Address |
| git push rejected (fetch first) | You edited files on github.com | git pull then git push |
| cd ~\Desktop fails | Desktop is inside OneDrive | Use cd ~\OneDrive\Desktop |
| A script's output differs slightly from "Expected" | Random data and timing vary by machine | Fine — report your numbers. If an error appears that isn't listed as expected, copy the exact message and ask |
