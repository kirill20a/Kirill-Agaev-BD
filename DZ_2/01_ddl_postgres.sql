

-- Скрипт 1. DDL структуры OLAP-базы (pgAdmin, база dataparts)

-- Ресурсы по направлениям: закупки, продажи, персонал, остатки.


-- Единицы измерения (ресурс «Единица измерения»)
CREATE SEQUENCE IF NOT EXISTS seq_dim_ranges;

CREATE TABLE IF NOT EXISTS dim_ranges
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_ranges'),
    -- Код в Front
    external_id bigint NOT NULL UNIQUE,
    name text,
    factor double precision,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Категории товаров (иерархия)
CREATE SEQUENCE IF NOT EXISTS seq_dim_categories;

CREATE TABLE IF NOT EXISTS dim_categories
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_categories'),
    -- Код в Front
    external_id bigint NOT NULL UNIQUE,
    name text,
    parent_external_id bigint,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Номенклатура (ресурс «Товар»)
CREATE SEQUENCE IF NOT EXISTS seq_dim_products;

CREATE TABLE IF NOT EXISTS dim_products
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_products'),
    -- Код в Front
    external_id bigint NOT NULL UNIQUE,
    code text,
    name text,
    category_external_id bigint,
    range_external_id bigint,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Группы поставщиков
CREATE SEQUENCE IF NOT EXISTS seq_dim_vendor_groups;

CREATE TABLE IF NOT EXISTS dim_vendor_groups
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_vendor_groups'),
    -- Код в Front
    external_id int NOT NULL UNIQUE,
    name text,
    flag int,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Поставщики (ресурс «Поставщик»)
CREATE SEQUENCE IF NOT EXISTS seq_dim_vendors;

CREATE TABLE IF NOT EXISTS dim_vendors
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_vendors'),
    -- Код в Front
    external_id bigint NOT NULL UNIQUE,
    name text,
    group_external_id int,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Клиенты (ресурс «Клиент»)
CREATE SEQUENCE IF NOT EXISTS seq_dim_clients;

CREATE TABLE IF NOT EXISTS dim_clients
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_clients'),
    -- Код в Front
    external_id bigint NOT NULL UNIQUE,
    code text,
    discount numeric,
    start_date timestamp,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Сотрудники (ресурс «Сотрудник»)
CREATE SEQUENCE IF NOT EXISTS seq_dim_personnel;

CREATE TABLE IF NOT EXISTS dim_personnel
(
    -- Внутренний код
    id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_personnel'),
    -- Код в Front
    external_id int NOT NULL UNIQUE,
    last_name text,
    first_name text,
    is_pos int,
    is_sales int,
    is_deleted int,
    -- Дата появления
    date_add timestamp NOT NULL DEFAULT now()
);

-- Проверка: список созданных таблиц ресурсов
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name LIKE 'dim\_%' ORDER BY table_name;
