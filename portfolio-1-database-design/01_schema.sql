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