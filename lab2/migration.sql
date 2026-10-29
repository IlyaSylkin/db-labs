-- Миграция модели ЛР 1 по замечаниям преподавателя.
-- Применяется к базе после lab1/schema.sql и lab1/data.sql, данные сохраняются.
-- Всё выполняется в одной транзакции: при любой ошибке не применится ничего.
--
-- 1. Организатор — юридическое лицо, а не роль пользователя.
-- 2. Статусы заказов и билетов.
-- 3. Конкретные места вместо счётчиков seats_count / seats_available.
-- 4. Промокод — отдельная сущность.
-- 5. Удаление хранимых вычисляемых значений (total_price, seats_available).

BEGIN;


-- ===== 1. Организаторы =====

CREATE TABLE organizers (
    id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name   VARCHAR(200) NOT NULL,
    inn    VARCHAR(12)  NOT NULL,
    email  VARCHAR(100),
    CONSTRAINT uq_organizers_inn   UNIQUE (inn),
    CONSTRAINT chk_organizers_inn  CHECK (inn ~ '^([0-9]{10}|[0-9]{12})$'),  -- 10 цифр у организации, 12 у ИП
    CONSTRAINT chk_organizers_email CHECK (email LIKE '%_@_%._%')
);

-- Пользователи, которые представляют юрлицо (менеджеры организатора).
CREATE TABLE organizer_members (
    organizer_id INTEGER NOT NULL REFERENCES organizers (id) ON DELETE CASCADE,
    user_id      INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    PRIMARY KEY (organizer_id, user_id)
);

-- Юрлица для пользователей, которые в ЛР 1 имели роль organizer.
INSERT INTO organizers (name, inn, email) VALUES
    ('ООО «Громов Ивент»',          '7701234567',   'info@gromov-event.ru'),
    ('ООО «Нева Арт»',              '7812345678',   'hello@neva-art.ru'),
    ('ИП Зайцев Михаил Андреевич',  '166012345678', NULL);

-- Связь по естественным ключам (ИНН, email), а не по угаданным id.
INSERT INTO organizer_members (organizer_id, user_id)
SELECT o.id, u.id
FROM (VALUES ('7701234567',   'gromov@example.com'),
             ('7812345678',   'sokolova@example.com'),
             ('166012345678', 'zaitsev@example.com')) AS m (inn, email)
JOIN organizers o ON o.inn = m.inn
JOIN users u      ON u.email = m.email;

-- event_organizers: user_id → organizer_id (добавить → заполнить → ограничить → удалить старое).
ALTER TABLE event_organizers
    ADD COLUMN organizer_id INTEGER REFERENCES organizers (id) ON DELETE RESTRICT;

UPDATE event_organizers eo
SET organizer_id = om.organizer_id
FROM organizer_members om
WHERE om.user_id = eo.user_id;

ALTER TABLE event_organizers ALTER COLUMN organizer_id SET NOT NULL;
ALTER TABLE event_organizers DROP CONSTRAINT event_organizers_pkey;
ALTER TABLE event_organizers DROP COLUMN user_id;
ALTER TABLE event_organizers ADD PRIMARY KEY (event_id, organizer_id);

-- Роль больше не нужна: организатор определяется членством в organizer_members.
ALTER TABLE users DROP COLUMN role;


-- ===== 2. Статусы =====

-- Существующие заказы оплачены: DEFAULT 'paid' заполняет старые строки,
-- затем новый DEFAULT 'pending' действует для будущих заказов.
ALTER TABLE orders
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'paid',
    ADD CONSTRAINT chk_orders_status CHECK (status IN ('pending', 'paid', 'cancelled'));
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE tickets
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active',
    ADD CONSTRAINT chk_tickets_status CHECK (status IN ('active', 'used', 'refunded'));

-- Билеты на прошедшие мероприятия использованы.
UPDATE tickets
SET status = 'used'
WHERE event_id IN (SELECT id FROM events WHERE status = 'completed');


-- ===== 3. Места =====

-- row_no = NULL — стоячая зона: место это номер входного слота.
-- NULLS NOT DISTINCT: в стоячей зоне два слота с одним номером тоже запрещены.
CREATE TABLE seats (
    id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    zone_id  INTEGER NOT NULL REFERENCES venue_zones (id) ON DELETE CASCADE,
    row_no   INTEGER,
    seat_no  INTEGER NOT NULL,
    CONSTRAINT chk_seats_row      CHECK (row_no > 0),
    CONSTRAINT chk_seats_seat     CHECK (seat_no > 0),
    CONSTRAINT uq_seats_place     UNIQUE NULLS NOT DISTINCT (zone_id, row_no, seat_no),
    CONSTRAINT uq_seats_id_zone   UNIQUE (id, zone_id)   -- цель составного FK из tickets
);

-- Генерация мест из seats_count: в сидячих зонах по 20 мест в ряду,
-- в стоячих (танцпол, бар-зона) — слоты без ряда.
INSERT INTO seats (zone_id, row_no, seat_no)
SELECT z.id,
       CASE WHEN z.name IN ('Танцпол', 'Бар-зона') THEN NULL ELSE (n - 1) / 20 + 1 END,
       CASE WHEN z.name IN ('Танцпол', 'Бар-зона') THEN n    ELSE (n - 1) % 20 + 1 END
FROM venue_zones z
CROSS JOIN generate_series(1, z.seats_count) AS n;

-- Существующим билетам раздаём первые места своей зоны:
-- k-й билет мероприятия в зоне получает k-е место этой зоны.
ALTER TABLE tickets ADD COLUMN seat_id INTEGER;

WITH numbered_tickets AS (
    SELECT id, zone_id,
           ROW_NUMBER() OVER (PARTITION BY event_id, zone_id ORDER BY id) AS rn
    FROM tickets
),
numbered_seats AS (
    SELECT id, zone_id,
           ROW_NUMBER() OVER (PARTITION BY zone_id ORDER BY id) AS rn
    FROM seats
)
UPDATE tickets t
SET seat_id = s.id
FROM numbered_tickets nt
JOIN numbered_seats s ON s.zone_id = nt.zone_id AND s.rn = nt.rn
WHERE t.id = nt.id;

ALTER TABLE tickets ALTER COLUMN seat_id SET NOT NULL;

-- Место должно находиться в той же зоне, что указана в билете.
-- Вместе со старым FK (event_id, zone_id) → event_zones это гарантирует,
-- что место продаётся на это мероприятие.
ALTER TABLE tickets
    ADD CONSTRAINT fk_tickets_seat FOREIGN KEY (seat_id, zone_id)
        REFERENCES seats (id, zone_id) ON DELETE RESTRICT;

-- Одно место на мероприятие продаётся один раз; после возврата место снова свободно.
CREATE UNIQUE INDEX uq_tickets_event_seat
    ON tickets (event_id, seat_id)
    WHERE status <> 'refunded';


-- ===== 4. Промокоды =====

CREATE TABLE promo_codes (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            VARCHAR(20)   NOT NULL,
    discount_type   VARCHAR(10)   NOT NULL,
    discount_value  NUMERIC(10,2) NOT NULL,
    valid_from      DATE          NOT NULL,
    valid_to        DATE          NOT NULL,
    CONSTRAINT uq_promo_codes_code     UNIQUE (code),
    CONSTRAINT chk_promo_codes_type    CHECK (discount_type IN ('percent', 'fixed')),
    CONSTRAINT chk_promo_codes_value   CHECK (discount_value > 0),
    CONSTRAINT chk_promo_codes_percent CHECK (discount_type <> 'percent' OR discount_value <= 100),
    CONSTRAINT chk_promo_codes_period  CHECK (valid_to >= valid_from)
);

-- Условия промокодов, которые в ЛР 1 были только строкой в заказе.
INSERT INTO promo_codes (code, discount_type, discount_value, valid_from, valid_to) VALUES
    ('AUTUMN10', 'percent',  10, '2026-09-01', '2026-11-30'),
    ('VIP500',   'fixed',   500, '2026-09-01', '2026-12-31');

ALTER TABLE orders
    ADD COLUMN promo_code_id INTEGER REFERENCES promo_codes (id) ON DELETE RESTRICT;

UPDATE orders o
SET promo_code_id = p.id
FROM promo_codes p
WHERE p.code = o.promo_code;


-- ===== 5. Проверка и удаление устаревших столбцов =====

-- Перед удалением убеждаемся, что новые данные выражают то же, что старые.
-- RAISE EXCEPTION прерывает транзакцию, и миграция откатывается целиком.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM orders
               WHERE promo_code IS NOT NULL AND promo_code_id IS NULL) THEN
        RAISE EXCEPTION 'Не все промокоды заказов перенесены в promo_codes';
    END IF;

    -- seats_available = мест в зоне − проданных билетов
    IF EXISTS (SELECT 1
               FROM event_zones ez
               WHERE ez.seats_available <>
                     (SELECT COUNT(*) FROM seats s WHERE s.zone_id = ez.zone_id)
                   - (SELECT COUNT(*) FROM tickets t
                      WHERE t.event_id = ez.event_id AND t.zone_id = ez.zone_id)) THEN
        RAISE EXCEPTION 'seats_available расходится с количеством мест и билетов';
    END IF;

    -- total_price = сумма цен билетов заказа минус скидка по промокоду
    IF EXISTS (SELECT 1
               FROM orders o
               LEFT JOIN promo_codes p ON p.id = o.promo_code_id
               CROSS JOIN LATERAL (SELECT COALESCE(SUM(t.price), 0) AS gross
                                   FROM tickets t WHERE t.order_id = o.id) g
               WHERE o.total_price <> g.gross - CASE
                         WHEN p.discount_type = 'percent' THEN round(g.gross * p.discount_value / 100, 2)
                         WHEN p.discount_type = 'fixed'   THEN LEAST(p.discount_value, g.gross)
                         ELSE 0
                     END) THEN
        RAISE EXCEPTION 'total_price расходится с суммой билетов и скидкой';
    END IF;
END $$;

ALTER TABLE orders      DROP COLUMN promo_code;
ALTER TABLE orders      DROP COLUMN total_price;
ALTER TABLE event_zones DROP COLUMN seats_available;
ALTER TABLE venue_zones DROP COLUMN seats_count;

COMMIT;
