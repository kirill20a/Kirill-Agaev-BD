 
-- Скрипт 2. Выборка ресурсов (MS SQL, база Front)
-- Для каждого ресурса: (а) SELECT - что переносим;
-- (б) генератор - строки insert для скрипта 3 (столбец [sql]).
 

USE Front;
GO

 
-- НАПРАВЛЕНИЕ 1. Анализ закупки продукции
-- Ресурсы направления: dim_ranges, dim_categories, dim_products, dim_vendor_groups, dim_vendors
-- Время: dim_time (скрипт 04_dim_time.sql)
 

-- 1.1 Единицы измерения (ресурс «Единица измерения») -> dim_ranges
-- (а) выборка
SELECT id AS external_id,
       sizeid AS name,
       portionrate AS factor
FROM [size];

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_ranges(external_id, name, factor) values ('
     + isnull(cast(id as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(sizeid as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull(cast(cast(portionrate as decimal(28, 10)) as varchar(50)), 'null')
     + ');'
    AS [sql]
FROM [size];

-- 1.2 Категории товаров (иерархия) -> dim_categories
-- (а) выборка
SELECT id AS external_id,
       description AS name,
       case when coalesce(ParentID, 0) = 0 then null else ParentID end AS parent_external_id
FROM category;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_categories(external_id, name, parent_external_id) values ('
     + isnull(cast(id as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(description as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull(cast(case when coalesce(ParentID, 0) = 0 then null else ParentID end as varchar(50)), 'null')
     + ');'
    AS [sql]
FROM category;

-- 1.3 Номенклатура (ресурс «Товар») -> dim_products
-- (а) выборка
SELECT id AS external_id,
       productid AS code,
       description AS name
FROM product;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_products(external_id, code, name) values ('
     + isnull(cast(id as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(productid as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull('''' + replace(cast(description as nvarchar(max)), '''', '''''') + '''', 'null')
     + ');'
    AS [sql]
FROM product;

-- 1.4 Группы поставщиков -> dim_vendor_groups
-- (а) выборка
SELECT vendorgroupid AS external_id,
       description AS name
FROM vendorgroup;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_vendor_groups(external_id, name) values ('
     + isnull(cast(vendorgroupid as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(description as nvarchar(max)), '''', '''''') + '''', 'null')
     + ');'
    AS [sql]
FROM vendorgroup;

-- 1.5 Поставщики (ресурс «Поставщик») -> dim_vendors
-- (а) выборка
SELECT id AS external_id,
       clientid AS name,
       clientgroup AS group_external_id
FROM vendors;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_vendors(external_id, name, group_external_id) values ('
     + isnull(cast(id as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(clientid as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull(cast(clientgroup as varchar(50)), 'null')
     + ');'
    AS [sql]
FROM vendors;


 
-- НАПРАВЛЕНИЕ 2. Анализ продажи товара
-- Ресурсы направления: dim_clients
-- Общие ресурсы, описанные в других направлениях (повторно не переносить): dim_products, dim_categories, dim_ranges, dim_personnel
-- Время: dim_time (скрипт 04_dim_time.sql)
 

-- 2.1 Клиенты (ресурс «Клиент») -> dim_clients
-- (а) выборка
SELECT id AS external_id,
       clientid AS code,
       discount AS discount,
       startdate AS start_date
FROM clients;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_clients(external_id, code, discount, start_date) values ('
     + isnull(cast(id as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(clientid as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull(cast(cast(discount as decimal(28, 10)) as varchar(50)), 'null')
     + ', '
     + isnull('''' + convert(varchar(19), startdate, 120) + '''', 'null')
     + ');'
    AS [sql]
FROM clients;


 
-- НАПРАВЛЕНИЕ 3. Анализ работы персонала
-- Ресурсы направления: dim_personnel
-- Время: dim_time (скрипт 04_dim_time.sql)
 

-- 3.1 Сотрудники (ресурс «Сотрудник») -> dim_personnel
-- (а) выборка
SELECT personid AS external_id,
       lastname AS last_name,
       firstname AS first_name,
       flagpos AS is_pos,
       flagsales AS is_sales,
       deleteflag AS is_deleted
FROM personnel;

-- (б) генератор строк для скрипта 3
SELECT 'insert into dim_personnel(external_id, last_name, first_name, is_pos, is_sales, is_deleted) values ('
     + isnull(cast(personid as varchar(50)), 'null')
     + ', '
     + isnull('''' + replace(cast(lastname as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull('''' + replace(cast(firstname as nvarchar(max)), '''', '''''') + '''', 'null')
     + ', '
     + isnull(cast(flagpos as varchar(50)), 'null')
     + ', '
     + isnull(cast(flagsales as varchar(50)), 'null')
     + ', '
     + isnull(cast(deleteflag as varchar(50)), 'null')
     + ');'
    AS [sql]
FROM personnel;


 
-- НАПРАВЛЕНИЕ 4. Анализ остатков
-- Ресурсы направления: (новых нет)
-- Общие ресурсы, описанные в других направлениях (повторно не переносить): dim_products, dim_ranges
-- Время: dim_time (скрипт 04_dim_time.sql)
 


-- Контроль: сколько строк в источнике (сравнить с count(*) в PostgreSQL после загрузки)

SELECT 'dim_ranges' AS resource, count(*) AS cnt FROM [size]
UNION ALL
SELECT 'dim_categories' AS resource, count(*) AS cnt FROM category
UNION ALL
SELECT 'dim_products' AS resource, count(*) AS cnt FROM product
UNION ALL
SELECT 'dim_vendor_groups' AS resource, count(*) AS cnt FROM vendorgroup
UNION ALL
SELECT 'dim_vendors' AS resource, count(*) AS cnt FROM vendors
UNION ALL
SELECT 'dim_clients' AS resource, count(*) AS cnt FROM clients
UNION ALL
SELECT 'dim_personnel' AS resource, count(*) AS cnt FROM personnel;
