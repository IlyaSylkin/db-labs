-- Дополнительные данные ЛР 2. Запускать после lab2/migration.sql.
-- Данные ЛР 1 сохраняются, здесь только добавление.
--
-- id новых строк продолжают счётчики после lab1/data.sql (номер указан
-- в комментарии), поэтому база должна быть собрана с нуля: lab2/setup.sql.
-- Места в билетах задаются рядом и номером, id места находит JOIN с seats.


-- ===== Пользователи =====
-- 9 — менеджер нового организатора; 19, 20 — зарегистрировались, но ничего не купили.
INSERT INTO users (first_name, last_name, email) VALUES
    ('Рустам',    'Хабибуллин', 'khabibullin@example.com'),  --  9
    ('Екатерина', 'Волкова',    'volkova@example.com'),      -- 10
    ('Артур',     'Галиев',     'galiev@example.com'),       -- 11
    ('Софья',     'Ковалёва',   'kovaleva@example.com'),     -- 12
    ('Никита',    'Беляев',     'belyaev@example.com'),      -- 13
    ('Виктория',  'Орлова',     'orlova@example.com'),       -- 14
    ('Тимур',     'Сафин',      'safin@example.com'),        -- 15
    ('Ксения',    'Фёдорова',   'fedorova@example.com'),     -- 16
    ('Денис',     'Зуев',       'zuev@example.com'),         -- 17
    ('Алина',     'Яковлева',   'yakovleva@example.com'),    -- 18
    ('Максим',    'Егоров',     'egorov@example.com'),       -- 19
    ('Полина',    'Григорьева', 'grigorieva@example.com');   -- 20


-- ===== Организаторы =====
-- Новый организатор пока не провёл ни одного мероприятия.
INSERT INTO organizers (name, inn, email) VALUES
    ('ООО «Казань Лайв»', '1655123456', 'info@kazan-live.ru');  -- 4

INSERT INTO organizer_members (organizer_id, user_id) VALUES
    (4, 9);


-- ===== Мероприятия =====
-- 9–11 — прошедшие летние, 8 и 12 — будущие. На 12 продаж ещё нет.
INSERT INTO events (venue_id, name, starts_at, status, description) VALUES
    (2, 'Щелкунчик',                 '2026-12-27 19:00+03', 'planned',
        'Новогодний спектакль'),                                       --  8
    (3, 'Джазовый вечер',            '2026-06-20 20:00+03', 'completed',
        NULL),                                                         --  9
    (1, 'Kotova. Летний тур',        '2026-07-15 20:00+03', 'completed',
        'Большой сольный концерт'),                                    -- 10
    (3, 'Стендап-вечер',             '2026-08-08 19:30+03', 'completed',
        'Открытый микрофон'),                                          -- 11
    (1, 'Новогодний концерт',        '2026-12-30 21:00+03', 'planned',
        'Сборный концерт');                                            -- 12

INSERT INTO event_organizers (event_id, organizer_id) VALUES
    (8, 2), (9, 3), (10, 1), (11, 3), (12, 1), (12, 2);


-- ===== Артисты =====
-- Рыбакова (9) пока не выступала ни на одном мероприятии.
INSERT INTO artists (full_name, stage_name, birth_date, description) VALUES
    ('Джаз-квартет «Подвал»', NULL,  NULL,         'Джазовый ансамбль'),  -- 7
    ('Сергей Лавров',         NULL,  '1990-05-05', 'Стендап-комик'),      -- 8
    ('Ольга Рыбакова',        'Ola', '2001-12-01', 'Начинающая певица');  -- 9

INSERT INTO event_artists (event_id, artist_id) VALUES
    (8, 4), (8, 5), (9, 7), (10, 2), (11, 8), (12, 1), (12, 2), (12, 6);


-- ===== Зоны на мероприятиях =====
INSERT INTO event_zones (event_id, zone_id, price) VALUES
    (8, 4,  3500.00), (8, 5,  2200.00),
    (9, 7,  1200.00), (9, 8,  2500.00),
    (10, 1, 2200.00), (10, 2, 3800.00), (10, 3, 12000.00),
    (11, 7,  900.00),
    (12, 1, 3000.00), (12, 2, 5500.00), (12, 3, 18000.00);


-- ===== Промокоды =====
-- EXPIRED20 и TEST1 ни разу не применялись.
INSERT INTO promo_codes (code, discount_type, discount_value, valid_from, valid_to) VALUES
    ('SUMMER15',   'percent',  15, '2026-06-01', '2026-08-31'),  -- 3
    ('WELCOME300', 'fixed',   300, '2026-01-01', '2026-12-31'),  -- 4
    ('EXPIRED20',  'percent',  20, '2026-01-01', '2026-01-31'),  -- 5
    ('TEST1',      'fixed',     1, '2026-10-01', '2026-10-01');  -- 6


-- ===== Заказы =====
INSERT INTO orders (user_id, created_at, promo_code_id, status, contact_phone, contact_email) VALUES
    -- «Kotova. Летний тур» (10)
    (10,   '2026-05-12 10:20+03', NULL, 'paid',      '+79031002030', 'volkova@example.com'),     --  9
    (11,   '2026-05-20 19:05+03', NULL, 'paid',      NULL,           'galiev@example.com'),      -- 10
    (4,    '2026-06-02 13:40+03', 3,    'paid',      '+79161234567', 'ivan.petrov@example.com'), -- 11
    (12,   '2026-06-15 21:10+03', NULL, 'paid',      '+79268887766', 'kovaleva@example.com'),    -- 12
    (13,   '2026-06-28 08:55+03', NULL, 'cancelled', NULL,           'belyaev@example.com'),     -- 13
    (14,   '2026-07-01 17:30+03', NULL, 'paid',      '+79057654321', 'orlova@example.com'),      -- 14
    (5,    '2026-07-10 12:00+03', 4,    'paid',      NULL,           'anna.sid@example.com'),    -- 15
    -- «Джазовый вечер» (9)
    (15,   '2026-05-25 15:15+03', NULL, 'paid',      '+79172223344', NULL),                      -- 16
    (6,    '2026-06-05 11:45+03', NULL, 'paid',      '+79035556677', NULL),                      -- 17
    (16,   '2026-06-18 22:40+03', NULL, 'cancelled', NULL,           'fedorova@example.com'),    -- 18
    -- «Стендап-вечер» (11)
    (17,   '2026-07-20 09:30+03', 3,    'paid',      '+79194445566', 'zuev@example.com'),        -- 19
    (15,   '2026-08-01 18:00+03', NULL, 'paid',      '+79172223344', NULL),                      -- 20
    (7,    '2026-08-05 14:25+03', NULL, 'paid',      '+79261112233', NULL),                      -- 21
    -- «Вишнёвый сад» (3)
    (18,   '2026-10-02 10:10+03', NULL, 'paid',      NULL,           'yakovleva@example.com'),   -- 22
    (10,   '2026-10-05 20:00+03', NULL, 'paid',      '+79031002030', 'volkova@example.com'),     -- 23
    -- «Ваня Север. Большой концерт» (1)
    (11,   '2026-10-03 16:35+03', NULL, 'paid',      NULL,           'galiev@example.com'),      -- 24
    (13,   '2026-10-08 12:50+03', 4,    'paid',      '+79099998877', 'belyaev@example.com'),     -- 25
    (14,   '2026-10-12 23:15+03', NULL, 'pending',   '+79057654321', 'orlova@example.com'),      -- 26
    (17,   '2026-10-15 07:45+03', NULL, 'cancelled', '+79194445566', NULL),                      -- 27
    -- Фестиваль «Северный ветер» (2)
    (12,   '2026-10-10 18:20+03', NULL, 'paid',      '+79268887766', 'kovaleva@example.com'),    -- 28
    (16,   '2026-10-18 13:05+03', NULL, 'pending',   NULL,           'fedorova@example.com'),    -- 29
    (4,    '2026-10-20 09:00+03', 1,    'paid',      '+79161234567', 'ivan.petrov@example.com'), -- 30
    -- «Ночь техно: DJ Volk» (4)
    (18,   '2026-10-21 22:30+03', NULL, 'paid',      NULL,           'yakovleva@example.com'),   -- 31
    (15,   '2026-10-22 01:10+03', NULL, 'pending',   '+79172223344', NULL),                      -- 32
    -- «Щелкунчик» (8)
    (5,    '2026-10-24 11:30+03', 1,    'paid',      NULL,           'anna.sid@example.com'),    -- 33
    (10,   '2026-10-26 19:40+03', NULL, 'paid',      NULL,           'volkova@example.com'),     -- 34
    (NULL, '2026-10-27 15:00+03', NULL, 'pending',   NULL,           'guest.buyer@example.com'), -- 35
    (8,    '2026-10-28 10:05+03', NULL, 'cancelled', '+79174445566', 'novikov@example.com'),     -- 36
    -- Выставка (7), бесплатно
    (12,   '2026-10-28 17:55+03', NULL, 'paid',      NULL,           'kovaleva@example.com');    -- 37


-- ===== Билеты =====
-- price = NULL в списке → берётся текущая цена зоны (цена на момент покупки).
-- Место 9 в ряду 5 партера на мероприятии 10 сдано (заказ 13) и продано
-- повторно (заказ 14) — частичный уникальный индекс это разрешает.
INSERT INTO tickets (order_id, event_id, zone_id, seat_id, holder_first_name, holder_last_name, price, status)
SELECT v.order_id, v.event_id, v.zone_id, s.id, v.first_name, v.last_name,
       COALESCE(v.price, ez.price), v.status
FROM (VALUES
    -- заказ, мероприятие, зона, ряд, место, имя, фамилия, цена, статус
    ( 9, 10, 2,    5,   7, 'Екатерина', 'Волкова',   NULL::numeric, 'used'),
    ( 9, 10, 2,    5,   8, 'Андрей',    'Волков',    NULL, 'used'),
    (10, 10, 1, NULL, 101, 'Артур',     'Галиев',    NULL, 'used'),
    (11, 10, 3,    1,   4, 'Иван',      'Петров',    NULL, 'used'),
    (11, 10, 3,    1,   5, 'Ольга',     'Петрова',   NULL, 'used'),
    (12, 10, 1, NULL, 102, 'Софья',     'Ковалёва',  NULL, 'used'),
    (12, 10, 1, NULL, 103, 'Лев',       'Ковалёв',   NULL, 'used'),
    (12, 10, 1, NULL, 104, 'Ева',       'Ковалёва',  NULL, 'used'),
    (13, 10, 2,    5,   9, 'Никита',    'Беляев',    NULL, 'refunded'),
    (14, 10, 2,    5,   9, 'Виктория',  'Орлова',    NULL, 'used'),
    (15, 10, 1, NULL, 105, 'Анна',      'Сидорова',  NULL, 'used'),
    (NULL, 10, 3,  3,   1, 'Игорь',     'Мельников', 0,    'used'),     -- пригласительный
    (16,  9, 8, NULL,  10, 'Тимур',     'Сафин',     NULL, 'used'),
    (16,  9, 8, NULL,  11, 'Лейла',     'Сафина',    NULL, 'used'),
    (17,  9, 7, NULL,  10, 'Олег',      'Кузнецов',  NULL, 'used'),
    (18,  9, 7, NULL,  11, 'Ксения',    'Фёдорова',  NULL, 'refunded'),
    (19, 11, 7, NULL,  20, 'Денис',     'Зуев',      NULL, 'used'),
    (19, 11, 7, NULL,  21, 'Марина',    'Зуева',     NULL, 'used'),
    (19, 11, 7, NULL,  22, 'Пётр',      'Зуев',      NULL, 'used'),
    (20, 11, 7, NULL,  23, 'Тимур',     'Сафин',     NULL, 'used'),
    (21, 11, 7, NULL,  24, 'Дарья',     'Морозова',  NULL, 'used'),
    (22,  3, 4,    3,   1, 'Алина',     'Яковлева',  NULL, 'active'),
    (22,  3, 4,    3,   2, 'Роман',     'Яковлев',   NULL, 'active'),
    (23,  3, 5,    2,   7, 'Екатерина', 'Волкова',   NULL, 'active'),
    (24,  1, 2,   10,   1, 'Артур',     'Галиев',    NULL, 'active'),
    (24,  1, 2,   10,   2, 'Динара',    'Галиева',   NULL, 'active'),
    (24,  1, 2,   10,   3, 'Камиль',    'Галиев',    NULL, 'active'),
    (24,  1, 2,   10,   4, 'Амир',      'Галиев',    NULL, 'active'),
    (25,  1, 1, NULL,  50, 'Никита',    'Беляев',    NULL, 'active'),
    (26,  1, 3,    2,   1, 'Виктория',  'Орлова',    NULL, 'active'),
    (27,  1, 2,   10,   5, 'Денис',     'Зуев',      NULL, 'refunded'),
    (28,  2, 1, NULL, 200, 'Софья',     'Ковалёва',  NULL, 'active'),
    (28,  2, 1, NULL, 201, 'Лев',       'Ковалёв',   NULL, 'active'),
    (29,  2, 1, NULL, 202, 'Ксения',    'Фёдорова',  NULL, 'active'),
    (30,  2, 1, NULL, 203, 'Иван',      'Петров',    NULL, 'active'),
    (31,  4, 7, NULL,  30, 'Алина',     'Яковлева',  NULL, 'active'),
    (31,  4, 7, NULL,  31, 'Роман',     'Яковлев',   NULL, 'active'),
    (31,  4, 8, NULL,  20, 'Вера',      'Яковлева',  NULL, 'active'),
    (32,  4, 8, NULL,  21, 'Тимур',     'Сафин',     NULL, 'active'),
    (33,  8, 4,    1,  10, 'Анна',      'Сидорова',  NULL, 'active'),
    (33,  8, 4,    1,  11, 'Павел',     'Сидоров',   NULL, 'active'),
    (33,  8, 4,    1,  12, 'Маша',      'Сидорова',  NULL, 'active'),
    (34,  8, 5,    1,   1, 'Екатерина', 'Волкова',   NULL, 'active'),
    (35,  8, 4,    2,   5, 'Олеся',     'Гостева',   NULL, 'active'),
    (36,  8, 4,    2,   6, 'Павел',     'Новиков',   NULL, 'refunded'),
    (37,  7, 7, NULL,   3, 'Софья',     'Ковалёва',  NULL, 'active')
) AS v (order_id, event_id, zone_id, row_no, seat_no, first_name, last_name, price, status)
JOIN seats s
  ON s.zone_id = v.zone_id
 AND s.row_no IS NOT DISTINCT FROM v.row_no   -- у стоячих зон ряд NULL, а NULL = NULL не true
 AND s.seat_no = v.seat_no
JOIN event_zones ez
  ON ez.event_id = v.event_id
 AND ez.zone_id = v.zone_id;
