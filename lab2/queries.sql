-- Проданный билет — статус active или used; refunded — возвращён, место свободно.
-- Выручка — только оплаченные заказы (status = 'paid').


-- ===== 2.1. Многотабличные запросы =====

\echo '2.1.1. Список зрителей мероприятия для контроля на входе'
-- Подробная информация о билетах: зона, место, держатель, покупатель.
-- LEFT JOIN orders/users: у пригласительных нет заказа, у удалённых аккаунтов нет пользователя.
SELECT e.name                             AS event,
       z.name                             AS zone,
       s.row_no,
       s.seat_no,
       t.holder_last_name || ' ' || t.holder_first_name AS holder,
       t.status                           AS ticket_status,
       o.id                               AS order_id,
       o.status                           AS order_status,
       COALESCE(u.email, o.contact_email, 'пригласительный') AS buyer
FROM tickets t
JOIN events e      ON e.id = t.event_id
JOIN venue_zones z ON z.id = t.zone_id
JOIN seats s       ON s.id = t.seat_id
LEFT JOIN orders o ON o.id = t.order_id
LEFT JOIN users u  ON u.id = o.user_id
WHERE e.name = 'Ваня Север. Большой концерт'
  AND t.status <> 'refunded'
ORDER BY z.name, s.row_no NULLS FIRST, s.seat_no;


\echo '2.1.2. Зоны предстоящих мероприятий, в которых не продано ни одного билета'
-- Условие на статус билета стоит в ON: в WHERE оно отбросило бы строки с NULL.
SELECT e.name     AS event,
       e.starts_at,
       v.name     AS venue,
       z.name     AS zone,
       ez.price
FROM events e
JOIN venues v       ON v.id = e.venue_id
JOIN event_zones ez ON ez.event_id = e.id
JOIN venue_zones z  ON z.id = ez.zone_id
LEFT JOIN tickets t ON t.event_id = ez.event_id
                   AND t.zone_id = ez.zone_id
                   AND t.status <> 'refunded'
WHERE e.status = 'planned'
  AND t.id IS NULL
ORDER BY e.starts_at, z.name;


\echo '2.1.3. Рассылка SMS: зрители предстоящих мероприятий в оплаченных заказах с телефоном'
SELECT o.contact_phone,
       t.holder_last_name || ' ' || t.holder_first_name AS holder,
       e.name     AS event,
       e.starts_at,
       v.name     AS venue,
       v.city
FROM tickets t
JOIN orders o ON o.id = t.order_id
JOIN events e ON e.id = t.event_id
JOIN venues v ON v.id = e.venue_id
WHERE e.status = 'planned'
  AND e.starts_at > now()
  AND o.status = 'paid'
  AND t.status = 'active'
  AND o.contact_phone IS NOT NULL
ORDER BY e.starts_at, o.contact_phone;


-- ===== 2.2. Агрегация и группировка =====

\echo '2.2.1. Продажи по мероприятиям: заказы, проданные и возвращённые билеты'
-- LEFT JOIN сохраняет мероприятия без билетов; COUNT по столбцу tickets даёт им 0.
SELECT e.name                                          AS event,
       e.status,
       COUNT(DISTINCT t.order_id)                      AS orders,
       COUNT(t.id) FILTER (WHERE t.status <> 'refunded') AS sold,
       COUNT(t.id) FILTER (WHERE t.status = 'refunded')  AS refunded
FROM events e
LEFT JOIN tickets t ON t.event_id = e.id
GROUP BY e.id, e.name, e.status
ORDER BY sold DESC, e.name;


\echo '2.2.2. Площадки со средней ценой проданного билета выше 2000 ₽ (оплаченные заказы)'
SELECT v.name                     AS venue,
       v.city,
       COUNT(t.id)                AS tickets,
       SUM(t.price)               AS revenue,
       ROUND(AVG(t.price), 2)     AS avg_price
FROM venues v
JOIN events e  ON e.venue_id = v.id
JOIN tickets t ON t.event_id = e.id
JOIN orders o  ON o.id = t.order_id
WHERE o.status = 'paid'
  AND t.status <> 'refunded'
GROUP BY v.id, v.name, v.city
HAVING AVG(t.price) > 2000
ORDER BY revenue DESC;


\echo '2.2.3. Сравнение по месяцам: заказы по статусам и цены проданных билетов'
SELECT to_char(date_trunc('month', o.created_at), 'YYYY-MM') AS month,
       COUNT(DISTINCT o.id)                                     AS orders,
       COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'paid')      AS paid,
       COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'cancelled') AS cancelled,
       COALESCE(SUM(t.price) FILTER (WHERE o.status = 'paid' AND t.status <> 'refunded'), 0) AS revenue,
       MIN(t.price) FILTER (WHERE o.status = 'paid')              AS min_price,
       MAX(t.price) FILTER (WHERE o.status = 'paid')              AS max_price
FROM orders o
LEFT JOIN tickets t ON t.order_id = o.id
GROUP BY date_trunc('month', o.created_at)
ORDER BY month;


-- ===== 3. Подзапросы =====

\echo '3.1. Мероприятия, где продано больше билетов, чем в среднем по мероприятиям той же площадки'
WITH event_sold AS (
    SELECT e.id, e.name, e.venue_id,
           COUNT(t.id) AS sold
    FROM events e
    LEFT JOIN tickets t ON t.event_id = e.id AND t.status <> 'refunded'
    GROUP BY e.id, e.name, e.venue_id
)
SELECT v.name AS venue,
       es.name AS event,
       es.sold,
       (SELECT ROUND(AVG(x.sold), 2) FROM event_sold x WHERE x.venue_id = es.venue_id) AS venue_avg
FROM event_sold es
JOIN venues v ON v.id = es.venue_id
WHERE es.sold > (SELECT AVG(x.sold) FROM event_sold x WHERE x.venue_id = es.venue_id)
ORDER BY v.name, es.sold DESC;


\echo '3.2. EXISTS: покупатели, хотя бы раз оплатившие билет в VIP-ложу'
SELECT u.id, u.last_name, u.first_name, u.email
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM orders o
    JOIN tickets t     ON t.order_id = o.id
    JOIN venue_zones z ON z.id = t.zone_id
    WHERE o.user_id = u.id
      AND o.status = 'paid'
      AND t.status <> 'refunded'
      AND z.name = 'VIP-ложа'
)
ORDER BY u.id;


\echo '3.3. NOT EXISTS: зарегистрированные покупатели без единого оплаченного заказа'
-- Брошенные корзины и неактивные пользователи; представители организаторов не покупатели.
SELECT u.id, u.last_name, u.first_name, u.email,
       (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS unpaid_orders
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM orders o
    WHERE o.user_id = u.id
      AND o.status = 'paid'
)
AND NOT EXISTS (
    SELECT 1 FROM organizer_members m
    WHERE m.user_id = u.id
)
ORDER BY u.id;


\echo '3.4. Коррелированный подзапрос: заполняемость каждого мероприятия'
-- Вместимость — места во всех зонах, которые продаются на мероприятие.
SELECT e.name AS event,
       e.status,
       (SELECT COUNT(*)
        FROM event_zones ez
        JOIN seats s ON s.zone_id = ez.zone_id
        WHERE ez.event_id = e.id)                     AS capacity,
       (SELECT COUNT(*)
        FROM tickets t
        WHERE t.event_id = e.id
          AND t.status <> 'refunded')                 AS sold
FROM events e
ORDER BY e.starts_at;
