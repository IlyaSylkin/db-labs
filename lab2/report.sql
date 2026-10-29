-- Вопрос: какие мероприятия приносят больше всего выручки с учётом скидок
-- по промокодам, насколько они заполнены и какое место занимают на своей площадке?
--
-- Исходные данные → Промежуточные показатели → Агрегация → Итоговый отчёт
--   sales             order_totals              event_stats   итоговый SELECT
--                     sales_net

WITH
-- 1. Исходные данные: проданные билеты оплаченных заказов и пригласительные.
--    Возвраты и билеты неоплаченных/отменённых заказов не учитываются.
sales AS (
    SELECT t.id AS ticket_id, t.event_id, t.order_id, t.price
    FROM tickets t
    LEFT JOIN orders o ON o.id = t.order_id
    WHERE t.status <> 'refunded'
      AND (t.order_id IS NULL OR o.status = 'paid')
),

-- 2а. Промежуточные показатели: сумма заказа без скидки и скидка по промокоду.
--     Процентная скидка — доля суммы, фиксированная — не больше суммы заказа.
order_totals AS (
    SELECT s.order_id,
           SUM(s.price) AS gross,
           CASE p.discount_type
               WHEN 'percent' THEN ROUND(SUM(s.price) * p.discount_value / 100, 2)
               WHEN 'fixed'   THEN LEAST(p.discount_value, SUM(s.price))
               ELSE 0
           END AS discount
    FROM sales s
    JOIN orders o           ON o.id = s.order_id
    LEFT JOIN promo_codes p ON p.id = o.promo_code_id
    GROUP BY s.order_id, p.discount_type, p.discount_value
),

-- 2б. Скидка заказа распределяется по билетам пропорционально цене:
--     в одном заказе могут быть билеты на разные мероприятия.
sales_net AS (
    SELECT s.ticket_id, s.event_id, s.price,
           CASE WHEN ot.gross > 0
                THEN s.price * (ot.gross - ot.discount) / ot.gross
                ELSE 0
           END AS net_price
    FROM sales s
    LEFT JOIN order_totals ot ON ot.order_id = s.order_id
),

-- 3. Агрегация по мероприятиям. Вместимость — места всех продаваемых зон.
event_stats AS (
    SELECT e.id, e.name, e.venue_id, e.starts_at, e.status,
           (SELECT COUNT(*)
            FROM event_zones ez
            JOIN seats st ON st.zone_id = ez.zone_id
            WHERE ez.event_id = e.id)             AS capacity,
           COUNT(sn.ticket_id)                    AS sold,
           COALESCE(SUM(sn.price), 0)             AS gross_revenue,
           COALESCE(SUM(sn.net_price), 0)         AS net_revenue
    FROM events e
    LEFT JOIN sales_net sn ON sn.event_id = e.id
    WHERE e.status <> 'cancelled'
    GROUP BY e.id, e.name, e.venue_id, e.starts_at, e.status
)

-- 4. Итоговый отчёт: заполняемость, средняя цена, доля и место на площадке.
SELECT v.name                                              AS venue,
       es.name                                             AS event,
       es.starts_at::date                                  AS date,
       es.status,
       es.sold || ' / ' || es.capacity                     AS sold_of_capacity,
       ROUND(100.0 * es.sold / NULLIF(es.capacity, 0), 2)  AS fill_pct,
       ROUND(es.gross_revenue, 2)                          AS gross,
       ROUND(es.gross_revenue - es.net_revenue, 2)         AS discounts,
       ROUND(es.net_revenue, 2)                            AS net,
       ROUND(es.net_revenue / NULLIF(es.sold, 0), 2)       AS avg_net_price,
       ROUND(100 * es.net_revenue
             / NULLIF(SUM(es.net_revenue) OVER (PARTITION BY es.venue_id), 0), 1) AS venue_share_pct,
       RANK() OVER (PARTITION BY es.venue_id ORDER BY es.net_revenue DESC)        AS venue_rank
FROM event_stats es
JOIN venues v ON v.id = es.venue_id
ORDER BY v.name, venue_rank, es.starts_at;
