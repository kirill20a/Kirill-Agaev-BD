USE Front;
GO
/* ===== 1. Анализ закупки продукции (шаг: месяц) ===== */

-- 1.1 Какие типы складских операций есть и сколько их: подтверждает, что поступления (OperationID=1) вообще присутствуют.
SELECT t.ID, t.Description, t.Factor, COUNT(*) AS rows_cnt, SUM(o.Amount) AS amount_sum
FROM bm_StorageOperations o
JOIN bm_StorageOperationsType t ON t.ID = o.OperationID
GROUP BY t.ID, t.Description, t.Factor
ORDER BY t.ID;

-- 1.2 Закупки по месяцам: документы, позиции, сумма. Подтверждает, что данных хватает для помесячного анализа.
SELECT DATEFROMPARTS(YEAR(o.DateAdd), MONTH(o.DateAdd), 1) AS month_start,
       COUNT(DISTINCT o.DocumentID) AS docs,
       COUNT(*)                     AS positions,
       SUM(o.Amount)                AS purchase_amount
FROM bm_StorageOperations o
WHERE o.OperationID = 1
GROUP BY DATEFROMPARTS(YEAR(o.DateAdd), MONTH(o.DateAdd), 1)
ORDER BY month_start;

-- 1.3 ABC-анализ закупок по товарам: A — до 80 % накопленной суммы, B — до 95 %, C — остальное.
WITH p AS (
    SELECT o.ProductID, SUM(o.Amount) AS amount
    FROM bm_StorageOperations o
    WHERE o.OperationID = 1
    GROUP BY o.ProductID
), r AS (
    SELECT ProductID, amount,
           SUM(amount) OVER (ORDER BY amount DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(amount) OVER () AS cum_share
    FROM p
)
SELECT TOP 50 r.ProductID, pr.description, r.amount,
       CAST(r.cum_share * 100 AS DECIMAL(6,2)) AS cum_percent,
       CASE WHEN r.cum_share <= 0.80 THEN 'A' WHEN r.cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class
FROM r LEFT JOIN product pr ON pr.id = r.ProductID
ORDER BY r.amount DESC;

-- 1.4 Итоги ABC: сколько товаров и какая доля суммы в каждом классе.
WITH p AS (
    SELECT ProductID, SUM(Amount) AS amount FROM bm_StorageOperations WHERE OperationID = 1 GROUP BY ProductID
), r AS (
    SELECT amount, SUM(amount) OVER (ORDER BY amount DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(amount) OVER () AS cum_share FROM p
), c AS (
    SELECT amount, CASE WHEN cum_share <= 0.80 THEN 'A' WHEN cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class FROM r
)
SELECT abc_class, COUNT(*) AS products, SUM(amount) AS amount,
       CAST(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER () AS DECIMAL(6,2)) AS amount_percent
FROM c GROUP BY abc_class ORDER BY abc_class;

-- 1.5 Проверка суммы: Amount ≈ Price * Count. Показывает долю строк, где сумма сходится (допуск 0,01).
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN ABS(Amount - Price * [Count]) <= 0.01 THEN 1 ELSE 0 END) AS amount_ok,
       SUM(CASE WHEN ABS(Amount - Price * [Count]) >  0.01 THEN 1 ELSE 0 END) AS amount_mismatch
FROM bm_StorageOperations WHERE OperationID = 1;

-- 1.6 Проверка связи с документами: виды документов, к которым относятся поступления.
SELECT td.ID, td.Description, COUNT(*) AS rows_cnt
FROM bm_StorageOperations o
JOIN bm_JournalBarnetDocs d ON d.ID = o.DocumentID
JOIN bm_JournalTypeDocuments td ON td.ID = d.DocumentTypeID
WHERE o.OperationID = 1
GROUP BY td.ID, td.Description ORDER BY rows_cnt DESC;

-- 1.7 Целостность: поступления без документа, товара, склада.
SELECT SUM(CASE WHEN d.ID IS NULL THEN 1 ELSE 0 END) AS no_document,
       SUM(CASE WHEN p.id IS NULL THEN 1 ELSE 0 END) AS no_product,
       SUM(CASE WHEN s.id IS NULL THEN 1 ELSE 0 END) AS no_storage
FROM bm_StorageOperations o
LEFT JOIN bm_JournalBarnetDocs d ON d.ID = o.DocumentID
LEFT JOIN product p ON p.id = o.ProductID
LEFT JOIN storages s ON s.id = o.StorageID
WHERE o.OperationID = 1;
