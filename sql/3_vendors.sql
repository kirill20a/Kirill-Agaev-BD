USE Front;
GO
/* ===== 3. Анализ взаимоотношений с поставщиками (шаг: месяц) ===== */

-- 3.1 Справочник поставщиков: сколько всего, активных и по группам.
SELECT g.description AS vendor_group, COUNT(*) AS vendors_cnt, SUM(CASE WHEN v.IsUse = 1 THEN 1 ELSE 0 END) AS active
FROM vendors v LEFT JOIN vendorgroup g ON g.vendorgroupid = v.clientgroup
GROUP BY g.description;

-- 3.2 Проверка логической связи (FK нет): доля поступлений, у которых VendorID найден в vendors.
SELECT COUNT(*) AS purchase_rows,
       SUM(CASE WHEN v.id IS NOT NULL THEN 1 ELSE 0 END) AS vendor_found,
       SUM(CASE WHEN v.id IS NULL THEN 1 ELSE 0 END)     AS vendor_missing
FROM bm_StorageOperations o LEFT JOIN vendors v ON v.id = o.VendorID
WHERE o.OperationID = 1;

-- 3.2b Уточнение: «не найденные» поставщики — это VendorID = 0 (закупки без поставщика) или реальные «битые» ссылки?
WITH x AS (
    SELECT CASE WHEN o.VendorID = 0 THEN 'VendorID = 0 (без поставщика)'
                WHEN v.id IS NULL   THEN 'VendorID не найден в vendors'
                ELSE 'найден' END AS vendor_status,
           d.DocumentTypeID, o.Amount
    FROM bm_StorageOperations o
    LEFT JOIN vendors v ON v.id = o.VendorID
    LEFT JOIN bm_JournalBarnetDocs d ON d.ID = o.DocumentID
    WHERE o.OperationID = 1
)
SELECT vendor_status, DocumentTypeID, COUNT(*) AS rows_cnt, SUM(Amount) AS amount
FROM x GROUP BY vendor_status, DocumentTypeID ORDER BY vendor_status, DocumentTypeID;

-- 3.3 Закупки по поставщикам и месяцам.
SELECT DATEFROMPARTS(YEAR(o.DateAdd), MONTH(o.DateAdd), 1) AS month_start,
       o.VendorID, v.firstname AS vendor_name,
       COUNT(DISTINCT o.DocumentID) AS docs, COUNT(DISTINCT o.ProductID) AS products, SUM(o.Amount) AS amount
FROM bm_StorageOperations o LEFT JOIN vendors v ON v.id = o.VendorID
WHERE o.OperationID = 1
GROUP BY DATEFROMPARTS(YEAR(o.DateAdd), MONTH(o.DateAdd), 1), o.VendorID, v.firstname
ORDER BY month_start, amount DESC;

-- 3.4 Число активных поставщиков по месяцам.
SELECT DATEFROMPARTS(YEAR(DateAdd), MONTH(DateAdd), 1) AS month_start, COUNT(DISTINCT VendorID) AS active_vendors
FROM bm_StorageOperations WHERE OperationID = 1
GROUP BY DATEFROMPARTS(YEAR(DateAdd), MONTH(DateAdd), 1) ORDER BY month_start;

-- 3.5 ABC-анализ поставщиков по сумме закупок. VendorID = 0 (закупки без поставщика) исключён — это не поставщик.
WITH p AS (
    SELECT o.VendorID, SUM(o.Amount) AS amount FROM bm_StorageOperations o WHERE o.OperationID = 1 AND o.VendorID <> 0 GROUP BY o.VendorID
), r AS (
    SELECT *, SUM(amount) OVER (ORDER BY amount DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(amount) OVER () AS cum_share FROM p
)
SELECT r.VendorID, v.firstname AS vendor_name, r.amount,
       CAST(r.cum_share * 100 AS DECIMAL(6,2)) AS cum_percent,
       CASE WHEN r.cum_share <= 0.80 THEN 'A' WHEN r.cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class
FROM r LEFT JOIN vendors v ON v.id = r.VendorID ORDER BY r.amount DESC;

-- 3.5b Дубли в справочнике: поставщики с одинаковым названием после удаления пробелов и двойных кавычек.
WITH k AS (
    SELECT id, firstname, REPLACE(REPLACE(firstname, ' ', ''), '"', '') AS name_key FROM vendors
)
SELECT name_key, COUNT(*) AS dup_cnt, MIN(id) AS id_min, MAX(id) AS id_max
FROM k WHERE name_key IS NOT NULL GROUP BY name_key HAVING COUNT(*) > 1;

-- 3.6 Поставщики, помеченные как неиспользуемые (IsUse = 0), но с поступлениями.
SELECT v.id, v.firstname, COUNT(*) AS rows_cnt, SUM(o.Amount) AS amount, MAX(o.DateAdd) AS last_delivery
FROM bm_StorageOperations o JOIN vendors v ON v.id = o.VendorID
WHERE o.OperationID = 1 AND ISNULL(v.IsUse, 0) = 0
GROUP BY v.id, v.firstname ORDER BY amount DESC;

-- 3.7 Договоры не ведутся: bm_Contracts пуста, ContractID в поступлениях.
SELECT (SELECT COUNT(*) FROM bm_Contracts) AS contracts_rows,
       (SELECT COUNT(*) FROM bm_StorageOperations WHERE OperationID = 1 AND ISNULL(ContractID, 0) <> 0) AS purchases_with_contract;

-- 3.8 Цены прайс-листа: у скольких строк указан поставщик.
SELECT COUNT(*) AS pricelist_rows, SUM(CASE WHEN vendorid IS NOT NULL AND vendorid <> '' THEN 1 ELSE 0 END) AS with_vendor FROM pricelist;