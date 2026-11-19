USE Front;
GO
/* ===== 5. Анализ остатков (шаг: одна неделя) ===== */

-- 5.1 Таблицы остатков в БД пусты — остатки надо считать из движений. Количество строк:
SELECT 'stock' AS tbl, COUNT(*) AS rows_cnt FROM stock
UNION ALL SELECT 'onhand', COUNT(*) FROM onhand
UNION ALL SELECT 'storagesonhand', COUNT(*) FROM storagesonhand
UNION ALL SELECT 'closingcount', COUNT(*) FROM closingcount
UNION ALL SELECT 'bm_StorageOperations', COUNT(*) FROM bm_StorageOperations
UNION ALL SELECT 'product.onhand заполнено', COUNT(*) FROM product WHERE onhand IS NOT NULL;

-- 5.2 Движения по неделям. В данных у списаний Count уже отрицательный (проверено: min -2000, у поступлений >= 0),
--     поэтому остаток = простая сумма Count, умножать на Factor нельзя (получится двойной минус).
SELECT DATEADD(WEEK, DATEDIFF(WEEK, 0, o.DateAdd), 0) AS week_start,
       SUM(CASE WHEN o.[Count] > 0 THEN o.[Count] ELSE 0 END) AS qty_in,
       SUM(CASE WHEN o.[Count] < 0 THEN o.[Count] ELSE 0 END) AS qty_out,
       SUM(o.[Count]) AS net_change
FROM bm_StorageOperations o JOIN bm_StorageOperationsType t ON t.ID = o.OperationID
GROUP BY DATEADD(WEEK, DATEDIFF(WEEK, 0, o.DateAdd), 0) ORDER BY week_start;

-- 5.3 Остаток всего склада на конец каждой недели (нарастающий итог).
WITH w AS (
    SELECT DATEADD(WEEK, DATEDIFF(WEEK, 0, o.DateAdd), 0) AS week_start, SUM(o.[Count]) AS net_change
    FROM bm_StorageOperations o JOIN bm_StorageOperationsType t ON t.ID = o.OperationID
    GROUP BY DATEADD(WEEK, DATEDIFF(WEEK, 0, o.DateAdd), 0)
)
SELECT week_start, net_change, SUM(net_change) OVER (ORDER BY week_start ROWS UNBOUNDED PRECEDING) AS balance_end
FROM w ORDER BY week_start;

-- 5.4 ВНИМАНИЕ: расчётные остатки ненадёжны (см. 5.3, 5.5) — запрос показывает, у каких товаров приход превышает расход.
--     Остатки по товарам на сегодня (по движениям) и ABC по стоимости остатка (по последней цене поступления).
WITH b AS (
    SELECT o.ProductID, SUM(o.[Count]) AS qty FROM bm_StorageOperations o
    JOIN bm_StorageOperationsType t ON t.ID = o.OperationID GROUP BY o.ProductID
), pr AS (
    SELECT ProductID, AVG(Price) AS avg_price FROM bm_StorageOperations WHERE OperationID = 1 GROUP BY ProductID
), v AS (
    SELECT b.ProductID, b.qty, b.qty * ISNULL(pr.avg_price, 0) AS value FROM b LEFT JOIN pr ON pr.ProductID = b.ProductID WHERE b.qty > 0
), r AS (
    SELECT *, SUM(value) OVER (ORDER BY value DESC ROWS UNBOUNDED PRECEDING) * 1.0 / NULLIF(SUM(value) OVER (), 0) AS cum_share FROM v
)
SELECT TOP 50 r.ProductID, p.description, r.qty, CAST(r.value AS DECIMAL(14,2)) AS value,
       CAST(r.cum_share * 100 AS DECIMAL(6,2)) AS cum_percent,
       CASE WHEN r.cum_share <= 0.80 THEN 'A' WHEN r.cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class
FROM r LEFT JOIN product p ON p.id = r.ProductID ORDER BY r.value DESC;

-- 5.5 Отрицательные остатки (списано больше, чем поступило) — показывает качество учёта.
SELECT TOP 30 o.ProductID, p.description, SUM(o.[Count]) AS qty
FROM bm_StorageOperations o JOIN bm_StorageOperationsType t ON t.ID = o.OperationID
LEFT JOIN product p ON p.id = o.ProductID
GROUP BY o.ProductID, p.description HAVING SUM(o.[Count]) < 0 ORDER BY qty;

-- 5.6 Соотношение bm_StorageOperations и bm_StorageOperations_Table по типам операций.
SELECT 'bm_StorageOperations' AS src, OperationID, COUNT(*) AS rows_cnt FROM bm_StorageOperations GROUP BY OperationID
UNION ALL
SELECT 'bm_StorageOperations_Table', OperationID, COUNT(*) FROM bm_StorageOperations_Table GROUP BY OperationID
ORDER BY src, OperationID;

-- 5.7 Единственный склад: подтверждает, что остатки считаются по одному складу.
SELECT s.id, s.description, COUNT(*) AS rows_cnt
FROM bm_StorageOperations o JOIN storages s ON s.id = o.StorageID GROUP BY s.id, s.description;

-- 5.8 Диагностика единиц измерения на одном товаре (4387 «Сыр Голландский, моцарелла»): приход и списание в разрезе RangeID.
--     Если единицы у прихода и списания разные — остаток считать простой суммой Count нельзя.
SELECT o.OperationID, o.RangeID, sz.description AS unit, COUNT(*) AS rows_cnt,
       SUM(o.[Count]) AS count_sum, SUM(o.Amount) AS amount_sum,
       CAST(AVG(o.Price) AS DECIMAL(12,2)) AS avg_price
FROM bm_StorageOperations o LEFT JOIN size sz ON sz.ID = o.RangeID
WHERE o.ProductID = 4387
GROUP BY o.OperationID, o.RangeID, sz.description ORDER BY o.OperationID, o.RangeID;

-- 5.9 Аномальная неделя 2021-04-05 (списано ~550 тыс. единиц): какие товары и документы.
SELECT TOP 20 o.DocumentID, o.ProductID, p.description, COUNT(*) AS rows_cnt, SUM(o.[Count]) AS count_sum, SUM(o.Amount) AS amount_sum
FROM bm_StorageOperations o LEFT JOIN product p ON p.id = o.ProductID
WHERE o.OperationID = 2 AND o.DateAdd >= '20210405' AND o.DateAdd < '20210412'
GROUP BY o.DocumentID, o.ProductID, p.description ORDER BY SUM(o.[Count]);

-- 5.10 Сверка списаний со склада и расшифровки продаж: расход ингредиентов по bm_Journal_Details против списаний операции 2, по годам.
SELECT 'bm_StorageOperations (списания)' AS src, YEAR(DateAdd) AS yr, COUNT(*) AS rows_cnt, SUM([Count]) AS count_sum
FROM bm_StorageOperations WHERE OperationID = 2 GROUP BY YEAR(DateAdd)
UNION ALL
SELECT 'bm_Journal_Details', YEAR(DateAdd), COUNT(*), SUM([Count])
FROM bm_Journal_Details GROUP BY YEAR(DateAdd)
ORDER BY yr, src;

-- 5.11 Какие продажи не имеют расшифровки (нет списания ингредиентов): возможная причина положительных остатков суши-ингредиентов (нори, тобико).
SELECT TOP 30 j.id AS item_id, MAX(j.description) AS item_name, COUNT(*) AS sales_rows, SUM(j.amount) AS amount
FROM journal j
LEFT JOIN (SELECT DISTINCT SourceID FROM bm_Journal_Details) d ON d.SourceID = j.transnumber
WHERE j.transtype = 101 AND d.SourceID IS NULL
GROUP BY j.id ORDER BY SUM(j.amount) DESC;