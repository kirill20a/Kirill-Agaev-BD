-- =====================================================================
-- Скрипт 3. PL/pgSQL: вставка данных ресурсов в OLAP-базу (pgAdmin, база dataparts)


-- ЧАСТЬ 1. Функции загрузки


-- Единицы измерения (ресурс «Единица измерения»)
CREATE OR REPLACE FUNCTION load_dim_ranges(
    p_external_id bigint,
    p_name text,
    p_factor double precision
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_ranges (external_id, name, factor)
    VALUES (p_external_id, p_name, p_factor)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        factor = EXCLUDED.factor;
END
$fn$;

-- Категории товаров (иерархия)
CREATE OR REPLACE FUNCTION load_dim_categories(
    p_external_id bigint,
    p_name text,
    p_parent_external_id bigint
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_categories (external_id, name, parent_external_id)
    VALUES (p_external_id, p_name, p_parent_external_id)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        parent_external_id = EXCLUDED.parent_external_id;
END
$fn$;

-- Номенклатура (ресурс «Товар»)
CREATE OR REPLACE FUNCTION load_dim_products(
    p_external_id bigint,
    p_code text,
    p_name text,
    p_category_external_id bigint,
    p_range_external_id bigint
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_products (external_id, code, name, category_external_id, range_external_id)
    VALUES (p_external_id, p_code, p_name, p_category_external_id, p_range_external_id)
    ON CONFLICT (external_id) DO UPDATE SET
        code = EXCLUDED.code,
        name = EXCLUDED.name,
        category_external_id = EXCLUDED.category_external_id,
        range_external_id = EXCLUDED.range_external_id;
END
$fn$;

-- Группы поставщиков
CREATE OR REPLACE FUNCTION load_dim_vendor_groups(
    p_external_id int,
    p_name text,
    p_flag int
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_vendor_groups (external_id, name, flag)
    VALUES (p_external_id, p_name, p_flag)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        flag = EXCLUDED.flag;
END
$fn$;

-- Поставщики (ресурс «Поставщик»)
CREATE OR REPLACE FUNCTION load_dim_vendors(
    p_external_id bigint,
    p_name text,
    p_group_external_id int
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_vendors (external_id, name, group_external_id)
    VALUES (p_external_id, p_name, p_group_external_id)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        group_external_id = EXCLUDED.group_external_id;
END
$fn$;

-- Клиенты (ресурс «Клиент»)
CREATE OR REPLACE FUNCTION load_dim_clients(
    p_external_id bigint,
    p_code text,
    p_discount numeric,
    p_start_date timestamp
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_clients (external_id, code, discount, start_date)
    VALUES (p_external_id, p_code, p_discount, p_start_date)
    ON CONFLICT (external_id) DO UPDATE SET
        code = EXCLUDED.code,
        discount = EXCLUDED.discount,
        start_date = EXCLUDED.start_date;
END
$fn$;

-- Сотрудники (ресурс «Сотрудник»)
CREATE OR REPLACE FUNCTION load_dim_personnel(
    p_external_id int,
    p_last_name text,
    p_first_name text,
    p_is_pos int,
    p_is_sales int,
    p_is_deleted int
) RETURNS void
LANGUAGE plpgsql
AS $fn$
BEGIN
    INSERT INTO dim_personnel (external_id, last_name, first_name, is_pos, is_sales, is_deleted)
    VALUES (p_external_id, p_last_name, p_first_name, p_is_pos, p_is_sales, p_is_deleted)
    ON CONFLICT (external_id) DO UPDATE SET
        last_name = EXCLUDED.last_name,
        first_name = EXCLUDED.first_name,
        is_pos = EXCLUDED.is_pos,
        is_sales = EXCLUDED.is_sales,
        is_deleted = EXCLUDED.is_deleted;
END
$fn$;

-- ЧАСТЬ 2. ДАННЫЕ
-- Сюда вставляются строки, которые выдали генераторы из скрипта 2.

/* ПОМЕТКА ЗАМЕНИТЬ ЭТОТ УЖАС НА CSV IMPORT*/

select load_dim_personnel(897, '', 'Администратор Barnet', 1, 0, 1);
select load_dim_personnel(898, 'Безик', 'Татьяна', 0, 0, 1);
select load_dim_personnel(899, 'Шипицына', 'Ольга', 0, 0, 1);
select load_dim_personnel(900, 'Пакалюк', 'Мария', 0, 0, 1);
select load_dim_personnel(901, 'Скубало', 'Кристина', 0, 0, 1);
select load_dim_personnel(902, 'Кустикова', 'Татьяна', 0, 0, 1);
select load_dim_personnel(903, 'Нагорная', 'Анна', 0, 0, 1);
select load_dim_personnel(904, 'Кафе 1', 'Касса 1', 0, 0, 1);
select load_dim_personnel(905, 'Кафе 2', 'Касса 2', 0, 0, 1);
select load_dim_personnel(906, 'Доставка', 'Доставка', 1, 0, 1);
select load_dim_personnel(907, 'Услуги гостиниц', 'Услуги гостиниц', 0, 0, 1);
select load_dim_personnel(969, 'Кушавина', 'Алена', 0, 0, 1);
select load_dim_personnel(970, 'Макаренко', 'Татьяна', 0, 0, 1);
select load_dim_personnel(971, 'Васильева', 'Валентина', 1, 0, 1);
select load_dim_personnel(972, 'Черная', 'Наталья', 0, 0, 1);
select load_dim_personnel(973, 'Никулин', 'Александр', 0, 0, 1);
select load_dim_personnel(974, 'Быстрова', 'Татьяна', 0, 0, 1);
select load_dim_personnel(975, 'Берг', 'Яна', 1, 0, 1);
select load_dim_personnel(976, 'Черная', 'Карина', 0, 0, 1);
select load_dim_personnel(977, 'Семенова', 'Алина', 0, 0, 1);
select load_dim_personnel(978, 'Шведова', 'Анастасия', 0, 0, 1);
select load_dim_personnel(979, 'Пионова', 'Мария', 0, 0, 1);
select load_dim_personnel(980, 'Болгарова', 'Ксения', 0, 0, 1);
select load_dim_personnel(981, 'Смирнова', 'Ирина', 0, 0, 1);
select load_dim_personnel(982, 'Шевченко', 'Елена', 0, 0, 1);
select load_dim_personnel(983, 'Чернобай', 'Юлия', 0, 0, 1);
select load_dim_personnel(984, 'Ражавикин', 'Андрей', 0, 0, 1);
select load_dim_personnel(985, 'Майборский', 'Антон', 0, 0, 1);
select load_dim_personnel(986, 'Англичанова', 'Анастасия', 0, 0, 1);
select load_dim_personnel(987, 'Семенова', 'Алина', 0, 0, 1);
select load_dim_personnel(988, 'Медведева', 'Валерия', 0, 0, 1);
select load_dim_personnel(989, 'Кульпинская', 'Ирина', 0, 0, 1);
select load_dim_personnel(990, 'Горбатенко', 'Кристина', 0, 0, 1);
select load_dim_personnel(991, 'Шибаева', 'Елена', 0, 0, 1);
select load_dim_personnel(992, 'Крицкая', 'Алена', 0, 0, 1);
select load_dim_personnel(993, 'Черных', 'Дмитрий', 0, 0, 1);
select load_dim_personnel(994, 'Модина', 'Александра', 0, 0, 1);
select load_dim_personnel(995, 'Плотникова', 'Александра', 0, 0, 1);
select load_dim_personnel(996, 'Кротова', 'Наталья', 0, 0, 1);
select load_dim_personnel(997, 'Пьянкова', 'Злата', 0, 0, 1);
select load_dim_personnel(998, 'Безик', 'Татьяна', 0, 0, 1);
select load_dim_personnel(999, 'Станиславская', 'Александра', 0, 0, 1);
select load_dim_personnel(1000, 'Свешникова', 'Дарья', 0, 0, 1);
select load_dim_personnel(1001, 'Писарева', 'Вероника', 0, 0, 1);
select load_dim_personnel(1002, 'Губанова', 'Анастасия', 0, 0, 1);
select load_dim_personnel(1003, 'Баженова', 'Диана', 0, 0, 1);
select load_dim_personnel(1004, 'Емельянов', 'Максим', 1, 0, 1);
select load_dim_personnel(1005, 'Пимкин', 'Денис', 0, 0, 1);
select load_dim_personnel(1006, 'Смолина', 'Вероника', 0, 0, 1);
select load_dim_personnel(1007, 'Гострик', 'Ольга', 0, 0, 1);
select load_dim_personnel(1008, 'АЛЕНТЬЕВА  (Миронова)', 'Лидия', 0, 0, 1);
select load_dim_personnel(1009, 'Глебова', 'Яна', 0, 0, 1);
select load_dim_personnel(1010, 'Гагулина', 'Анна', 0, 0, 1);
select load_dim_personnel(1011, 'Дёмкина', 'Елена', 0, 0, 1);
select load_dim_personnel(1012, 'Кайданова', 'Татьяна', 0, 0, 1);
select load_dim_personnel(1013, 'Толмачева', 'Валентина', 0, 0, 1);
select load_dim_personnel(1014, 'Хетчикова', 'Валентина', 0, 0, 1);
select load_dim_personnel(1015, 'Борисенко', 'Алина', 0, 0, 1);
select load_dim_personnel(1016, 'Иванов', 'Павел', 0, 0, 1);
select load_dim_personnel(1017, 'Лопатина', 'Ирина', 0, 0, 1);
select load_dim_personnel(1018, 'Белова', 'Светлана', 0, 0, 1);
select load_dim_personnel(1019, 'Шатохина', 'Елена', 0, 0, 1);
select load_dim_personnel(1020, 'Морозова', 'Анна', 1, 0, 1);
select load_dim_personnel(1021, 'Базанова', 'Виктория', 0, 0, 1);
select load_dim_personnel(1022, 'Тхагапсова', 'Тамара', 0, 0, 1);
select load_dim_personnel(1023, 'Мингазова', 'Евгения', 0, 0, 1);
select load_dim_personnel(1024, 'Агальцова', 'Анастасия', 0, 0, 1);
select load_dim_personnel(1025, 'Васильчук', 'Ольга', 0, 0, 1);
select load_dim_personnel(1026, 'Раджабова', 'Роза', 0, 0, 1);
select load_dim_personnel(1027, 'Кожан', 'Артем', 0, 0, 1);
select load_dim_personnel(1028, 'Громышева', 'Полина', 0, 0, 1);
select load_dim_personnel(1029, 'Попова', 'Галина', 1, 0, 1);
select load_dim_personnel(1030, 'Крутиков', 'Алексей', 0, 0, 1);
select load_dim_personnel(1031, 'Чумак', 'Нина', 0, 0, 1);
select load_dim_personnel(1032, 'Шевченко', 'Елена', 0, 0, 1);
select load_dim_personnel(1033, 'Митрошенко', 'Татьяна', 0, 0, 1);
select load_dim_personnel(1034, 'Чеченева', 'Ольга', 0, 0, 1);
select load_dim_personnel(1035, 'Кибирев', 'Николай', 0, 0, 1);
select load_dim_personnel(1036, 'Бархатова', 'Екатерина', 0, 0, 1);
select load_dim_personnel(1037, 'Пимкин', 'Денис', 0, 0, 1);
select load_dim_personnel(1038, 'Мешков', 'Семён', 0, 0, 1);
select load_dim_personnel(1039, 'Полушина', 'Анастасия', 0, 0, 1);
select load_dim_personnel(1040, 'Зыкова', 'Виктория', 0, 0, 1);
select load_dim_personnel(1041, 'Скубало', 'Кристина', 0, 0, 1);
select load_dim_personnel(1042, 'Цапенко', 'Никита', 0, 0, 1);
select load_dim_personnel(1043, 'Уваров', 'Виталий', 0, 0, 1);
select load_dim_personnel(1044, 'Кожан', 'Артем', 0, 0, 1);
select load_dim_personnel(1045, 'Дьяченко', 'Антонина', 1, 0, 1);
select load_dim_personnel(1046, 'Чистякова', 'Татьяна', 0, 0, 1);
select load_dim_personnel(1047, 'Смирнова', 'Наталья', 1, 0, 1);
select load_dim_personnel(1048, 'Хмелевской', 'Виталий', 0, 0, 1);
select load_dim_personnel(1049, 'Панова', 'Анна', 0, 0, 1);
select load_dim_personnel(1050, 'Федоренко', 'Никита', 0, 0, 1);
select load_dim_personnel(1051, 'Калигин', 'Владислав', 0, 0, 1);
select load_dim_personnel(1052, 'Балахнин', 'Костя', 0, 0, 1);
select load_dim_personnel(1053, 'Шпак', 'Оксана', 0, 0, 1);
select load_dim_personnel(1054, 'Днепровский', 'Денис', 0, 0, 1);
select load_dim_personnel(1055, 'Хасанов', 'Муроджон', 0, 0, 1);
select load_dim_personnel(1056, 'Кондратьева', 'Екатерина', 0, 0, 1);
select load_dim_personnel(1057, 'Бабкина', 'Радэма', 0, 0, 1);
select load_dim_personnel(1058, 'Тайшихина', 'Алена', 0, 0, 1);
select load_dim_personnel(1059, 'Зайчикова', 'Валерия', 0, 0, 1);
select load_dim_personnel(1060, 'Белова', 'Света', 1, 0, 1);
select load_dim_personnel(1061, 'Бычинская', 'Кристина', 0, 0, 1);
select load_dim_personnel(1062, 'Елисеева', 'Глория', 0, 0, 1);
select load_dim_personnel(1063, 'Чирикова', 'Елизавета', 0, 0, 1);
select load_dim_personnel(1064, 'Яременко', 'Софья', 1, 0, 1);
select load_dim_personnel(1065, 'Путина', 'Екатерина', 0, 0, 1);
select load_dim_personnel(1066, 'ЯРМАТОВА', 'Зара', 1, 0, 1);




-- ЧАСТЬ 3. Проверка

SELECT 'dim_ranges' AS resource, count(*) AS cnt FROM dim_ranges
UNION ALL
SELECT 'dim_categories' AS resource, count(*) AS cnt FROM dim_categories
UNION ALL
SELECT 'dim_products' AS resource, count(*) AS cnt FROM dim_products
UNION ALL
SELECT 'dim_vendor_groups' AS resource, count(*) AS cnt FROM dim_vendor_groups
UNION ALL
SELECT 'dim_vendors' AS resource, count(*) AS cnt FROM dim_vendors
UNION ALL
SELECT 'dim_clients' AS resource, count(*) AS cnt FROM dim_clients
UNION ALL
SELECT 'dim_personnel' AS resource, count(*) AS cnt FROM dim_personnel
ORDER BY resource;

