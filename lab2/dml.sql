-- Задание 1.2. Операции изменения данных 

\echo '1. INSERT: новое мероприятие с организатором, артистом и зонами'
-- Площадка 3 — «Клуб Подвал», артист 6 — DJ Volk 
WITH new_event AS (
    INSERT INTO events (venue_id, name, starts_at, description)
    VALUES (3, 'DJ Volk. Новогодний сет', '2026-12-31 23:00+03', 'Ночная вечеринка')
    RETURNING id, venue_id, status
),
new_organizer AS (
    INSERT INTO event_organizers (event_id, organizer_id)
    SELECT ne.id, o.id
    FROM new_event ne
    JOIN organizers o ON o.inn = '166012345678'   -- ИНН уникален
    RETURNING event_id, organizer_id
),
new_artist AS (
    INSERT INTO event_artists (event_id, artist_id)
    SELECT ne.id, 6
    FROM new_event ne
    RETURNING event_id, artist_id
)
-- Зоны ищутся только среди зон площадки мероприятия (venue_id, name) уникально.
INSERT INTO event_zones (event_id, zone_id, price)
SELECT ne.id, z.id, p.price
FROM new_event ne
JOIN venue_zones z ON z.venue_id = ne.venue_id
JOIN (VALUES ('Танцпол', 2000.00), ('Бар-зона', 3500.00)) AS p (zone_name, price)
  ON p.zone_name = z.name
RETURNING event_id, zone_id, price;

SELECT e.id, e.name, e.status, eo.organizer_id, ea.artist_id
FROM events e
JOIN event_organizers eo ON eo.event_id = e.id
JOIN event_artists ea    ON ea.event_id = e.id
WHERE e.id = (SELECT max(id) FROM events);


\echo '2. UPDATE: заказ 26 оплачен'
UPDATE orders
SET status = 'paid'
WHERE id = 26
  AND status = 'pending'
RETURNING id, status;


\echo '3. Массовый UPDATE: прошедшие мероприятия завершены, их билеты использованы'
BEGIN;

UPDATE events
SET status = 'completed'
WHERE status = 'planned'
  AND starts_at < now()
RETURNING id, name, starts_at;

UPDATE tickets t
SET status = 'used'
FROM events e
WHERE e.id = t.event_id
  AND e.status = 'completed'
  AND t.status = 'active'
RETURNING t.id, t.event_id;

COMMIT;


\echo '4. DELETE с учётом ограничений целостности'
\echo '4а. Промокод AUTUMN10 применён в заказах — FK ON DELETE RESTRICT не даст удалить'
DELETE FROM promo_codes WHERE code = 'AUTUMN10';

\echo '4б. Промокод TEST1 создан по ошибке и нигде не использован — удаляется'
DELETE FROM promo_codes
WHERE code = 'TEST1'
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.promo_code_id = promo_codes.id)
RETURNING id, code;


\echo '5. ROLLBACK: повышение цен на фестиваль отменяется'
BEGIN;

UPDATE event_zones
SET price = price * 1.2
WHERE event_id = 2
RETURNING event_id, zone_id, price;

ROLLBACK;

SELECT event_id, zone_id, price FROM event_zones WHERE event_id = 2 ORDER BY zone_id;
