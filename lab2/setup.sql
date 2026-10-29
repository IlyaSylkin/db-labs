-- Пересоздание базы ЛР 2 с нуля: схема и данные ЛР 1 → миграция → данные ЛР 2.
-- Запуск: psql -v ON_ERROR_STOP=1 -f lab2/setup.sql

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

\ir ../lab1/schema.sql
\ir ../lab1/data.sql
\ir migration.sql
\ir data.sql
