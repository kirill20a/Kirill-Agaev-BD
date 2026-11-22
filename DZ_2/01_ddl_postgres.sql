 
-- Скрипт 1. Структура OLAP-базы (PostgreSQL, база dataparts)
-- Только ресурсы, без внешних ключей. Ресурс «Время» - скрипт 4.
-- Перед запуском создать базу: create database dataparts;
-- DO-блок: каждая таблица во вложенном блоке, можно запускать повторно.
 

DO $ddl$
BEGIN

    -- Единицы измерения (ресурс «Единица измерения»)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_ranges;

        CREATE TABLE IF NOT EXISTS dim_ranges
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_ranges'),
            -- Код в Front
            external_id bigint,
            name text,
            factor float,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_ranges: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_ranges: ошибка %', SQLERRM;
    END;

    -- Категории товаров (иерархия)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_categories;

        CREATE TABLE IF NOT EXISTS dim_categories
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_categories'),
            -- Код в Front
            external_id bigint,
            name text,
            parent_external_id bigint,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_categories: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_categories: ошибка %', SQLERRM;
    END;

    -- Номенклатура (ресурс «Товар»)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_products;

        CREATE TABLE IF NOT EXISTS dim_products
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_products'),
            -- Код в Front
            external_id bigint,
            code text,
            name text,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_products: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_products: ошибка %', SQLERRM;
    END;

    -- Группы поставщиков
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_vendor_groups;

        CREATE TABLE IF NOT EXISTS dim_vendor_groups
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_vendor_groups'),
            -- Код в Front
            external_id bigint,
            name text,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_vendor_groups: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_vendor_groups: ошибка %', SQLERRM;
    END;

    -- Поставщики (ресурс «Поставщик»)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_vendors;

        CREATE TABLE IF NOT EXISTS dim_vendors
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_vendors'),
            -- Код в Front
            external_id bigint,
            name text,
            group_external_id int,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_vendors: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_vendors: ошибка %', SQLERRM;
    END;

    -- Клиенты (ресурс «Клиент»)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_clients;

        CREATE TABLE IF NOT EXISTS dim_clients
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_clients'),
            -- Код в Front
            external_id bigint,
            code text,
            discount numeric,
            start_date timestamp,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_clients: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_clients: ошибка %', SQLERRM;
    END;

    -- Сотрудники (ресурс «Сотрудник»)
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_dim_personnel;

        CREATE TABLE IF NOT EXISTS dim_personnel
        (
            -- Внутренний код
            id bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_personnel'),
            -- Код в Front
            external_id bigint,
            last_name text,
            first_name text,
            is_pos int,
            is_sales int,
            is_deleted int,
            -- Дата появления
            date_add timestamp NOT NULL DEFAULT now()
        );

        RAISE NOTICE 'dim_personnel: готово';
    EXCEPTION WHEN OTHERS THEN
        -- ошибка этого блока откатывает только его, остальные таблицы создаются
        RAISE WARNING 'dim_personnel: ошибка %', SQLERRM;
    END;

END
$ddl$;

-- Проверка: список созданных таблиц ресурсов (должно быть 7)
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name LIKE 'dim\_%' ORDER BY table_name;
