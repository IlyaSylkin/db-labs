DROP TABLE IF EXISTS users, venues, venue_zones, events, event_organizers,
    artists, event_artists, event_zones, orders, tickets CASCADE;


CREATE TABLE users (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE CHECK (email Like '%_@_%._%'),
    role        VARCHAR(100) NOT NULL DEfault 'user' CHECK (role IN ('user', 'organizer'))
);

CREATE TABLE venues (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    city        VARCHAR(100) NOT NULL,
    latitude    NUMERIC(9,6) NOT NULL CHECK (latitude Between -90 and 90),
    longitude    NUMERIC(9,6) NOT NULL CHECK (longitude Between -180 and 180)
);

CREATE TABLE venue_zones (
    
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_id    INTEGER NOT NULL REFERENCES venues (id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    seats_count INTEGER NOT NULL CHECK (seats_count >= 0),
    CONSTRAINT venue_zones_name_unique UNIQUE (venue_id, name)
);


CREATE TABLE events (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_id    INTEGER NOT NULL REFERENCES venues (id) ON DELETE RESTRICT,
    name        VARCHAR(100) NOT NULL,
    starts_at   TIMESTAMPTZ NOT NULL,
    status      VARCHAR(100) NOT NULL DEfault 'planned' CHECK (status IN ('planned', 'cancelled', 'completed')),
    description Text
);


CREATE TABLE event_organizers (
    event_id    INTEGER NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    user_id     INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, user_id)
);


CREATE TABLE artists (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    stage_name  VARCHAR(100),
    birth_date  DATE CHECK (birth_date < CURRENT_DATE),
    description Text
);

CREATE TABLE event_artists (
    event_id    INTEGER NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    artist_id     INTEGER NOT NULL REFERENCES artists (id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, artist_id)
);

CREATE TABLE event_zones (
    event_id    INTEGER NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    zone_id     INTEGER NOT NULL REFERENCES venue_zones (id) ON DELETE CASCADE,
    seats_available  INTEGER NOT NULL CHECK (seats_available >= 0),
    price     NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (event_id, zone_id)
);

CREATE TABLE orders (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    INTEGER REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    promo_code VARCHAR(10),
    total_price NUMERIC(10,2) NOT Null CHECK (total_price >= 0),
    contact_phone  VARCHAR(20),
    contact_email     VARCHAR(100) CHECK (contact_email Like '%_@_%._%'),
    CHECK (contact_phone IS NOT NULL OR contact_email IS NOT NULL)

);

CREATE TABLE tickets (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    INTEGER REFERENCES orders (id) ON DELETE SET NULL,
    event_id    INTEGER NOT NULL,
    zone_id    INTEGER NOT NULL,
    holder_first_name  VARCHAR(100) NOT NULL,
    holder_last_name   VARCHAR(100) NOT NULL,
    price  NUMERIC(10,2) NOT NULL CHECK(price >= 0),
    FOREIGN KEY (event_id, zone_id)
    REFERENCES event_zones(event_id, zone_id) ON DELETE RESTRICT


);
