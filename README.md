# Базы данных — лабораторные работы

5 семестр, 2026. СУБД — PostgreSQL 17 (в Docker).

| № | Тема | Папка | Срок |
|---|------|-------|------|
| 1 | Проектирование и реализация реляционной БД (вариант 12 — продажа билетов на мероприятия) | [lab1](lab1/) | 20.10 |

## Запуск PostgreSQL

```bash
docker compose up -d                                   # поднять сервер
docker compose exec db psql -U student -d labs         # консоль psql
```

Папка репозитория смонтирована в контейнер как `/labs`, поэтому скрипты запускаются так:

```bash
docker compose exec db psql -U student -d labs -f /labs/lab1/schema.sql
```

Подключение из GUI (DBeaver, DataGrip, pgAdmin): `localhost:5432`, база `labs`, пользователь и пароль `student`.

## Структура

```
labN/
├── README.md             — описание лабы и как её запустить
└── *.sql                 — скрипты по заданию
```
