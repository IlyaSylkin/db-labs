-- Проверка ограничений целостности (запускать после schema.sql и data.sql)'

\echo 'NOT NULL'
INSERT INTO users (first_name, email)
VALUES ('Безфамильный', 'nolastname@example.com');

\echo 'UNIQUE: email уже занят'
INSERT INTO users (first_name, last_name, email)
VALUES ('Алексей', 'Двойников', 'gromov@example.com');

\echo 'CHECK: формат email'
INSERT INTO users (first_name, last_name, email)
VALUES ('Иван', 'Ошибкин', 'not-an-email');

\echo 'CHECK: роль'
INSERT INTO users (first_name, last_name, email, role)
VALUES ('Админ', 'Админов', 'admin@example.com', 'admin');

\echo 'GENERATED ALWAYS: id вручную'
INSERT INTO users (id, first_name, last_name, email)
VALUES (100, 'Ручной', 'Айди', 'manual.id@example.com');

\echo 'CHECK: широта'
INSERT INTO venues (name, city, latitude, longitude)
VALUES ('Северный полюс+', 'Нигде', 95.0, 30.0);

\echo 'составной UNIQUE: второй «Партер» в том же зале'
INSERT INTO venue_zones (venue_id, name, seats_count)
VALUES (1, 'Партер', 100);

\echo 'CHECK: число мест'
INSERT INTO venue_zones (venue_id, name, seats_count)
VALUES (2, 'Ложа', -10);

\echo 'FK: несуществующий зал'
INSERT INTO events (venue_id, name, starts_at)
VALUES (999, 'Концерт в никуда', '2026-12-31 22:00+03');

\echo 'CHECK: статус'
UPDATE events SET status = 'postponed' WHERE id = 1;

\echo 'CHECK: дата рождения в будущем'
INSERT INTO artists (full_name, birth_date)
VALUES ('Ещё Не Родился', '2030-01-01');

\echo 'составной PK: артист дважды на одном мероприятии'
INSERT INTO event_artists (event_id, artist_id)
VALUES (1, 1);

\echo 'CHECK: отрицательная цена'
UPDATE event_zones SET price = -100
WHERE event_id = 1 AND zone_id = 1;

\echo 'CHECK: мест осталось 47, списываем 50'
UPDATE event_zones SET seats_available = seats_available - 50
WHERE event_id = 1 AND zone_id = 3;

\echo 'составной CHECK: нет ни телефона, ни email'
INSERT INTO orders (user_id, total_price, contact_phone, contact_email)
VALUES (4, 1000.00, NULL, NULL);

\echo 'составной FK: VIP-ложа на фестиваль не продаётся'
INSERT INTO tickets (order_id, event_id, zone_id, holder_first_name, holder_last_name, price)
VALUES (1, 2, 3, 'Иван', 'Петров', 15000.00);

\echo 'RESTRICT: на мероприятие проданы билеты'
DELETE FROM events WHERE id = 1;

\echo 'RESTRICT: в зале есть мероприятия'
DELETE FROM venues WHERE id = 1;


\echo 'Демонстрация ON DELETE (изменения откатываются)'
BEGIN;

\echo 'SET NULL: заказы удалённого пользователя остаются'
DELETE FROM users WHERE id = 4;
SELECT id, user_id FROM orders WHERE id IN (1, 6);

\echo 'SET NULL: билеты удалённого заказа остаются'
DELETE FROM orders WHERE id = 1;
SELECT id, order_id FROM tickets WHERE id IN (1, 2);

\echo 'CASCADE: мероприятие без билетов удаляется вместе со связями'
DELETE FROM events WHERE id = 6;
SELECT
    (SELECT count(*) FROM event_zones      WHERE event_id = 6) AS zones,
    (SELECT count(*) FROM event_artists    WHERE event_id = 6) AS artists,
    (SELECT count(*) FROM event_organizers WHERE event_id = 6) AS organizers;

ROLLBACK;
