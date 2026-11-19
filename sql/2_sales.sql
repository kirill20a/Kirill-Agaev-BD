USE Front;
GO
/* ===== 2. Анализ продажи товара (шаг: месяц) ===== */

-- 2.1 Состав журнала по типам операций: подтверждает, что продажи — transtype = 101.
SELECT j.transtype, t.description, COUNT(*) AS rows_cnt, SUM(j.amount) AS amount_sum
FROM journal j LEFT JOIN transtype t ON t.transtypeid = j.transtype
GROUP BY j.transtype, t.description ORDER BY rows_cnt DESC;

-- 2.2 Продажи по месяцам: чеки, позиции, выручка, средний чек.
SELECT DATEFROMPARTS(YEAR(j.dater), MONTH(j.dater), 1) AS month_start,
       COUNT(DISTINCT j.receiptn) AS receipts,
       COUNT(*)                   AS positions,
       SUM(j.amount)              AS revenue,
       CAST(SUM(j.amount) / NULLIF(COUNT(DISTINCT j.receiptn), 0) AS DECIMAL(12,2)) AS avg_check
FROM journal j
WHERE j.transtype = 101
GROUP BY DATEFROMPARTS(YEAR(j.dater), MONTH(j.dater), 1)
ORDER BY month_start;

-- 2.3 ABC-анализ продаж по позициям меню (A до 80 %, B до 95 %, C остальное).
WITH p AS (
    SELECT j.id AS item_id, MAX(j.description) AS item_name, SUM(j.amount) AS amount
    FROM journal j WHERE j.transtype = 101 GROUP BY j.id
), r AS (
    SELECT *, SUM(amount) OVER (ORDER BY amount DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(amount) OVER () AS cum_share FROM p
)
SELECT TOP 50 item_id, item_name, amount,
       CAST(cum_share * 100 AS DECIMAL(6,2)) AS cum_percent,
       CASE WHEN cum_share <= 0.80 THEN 'A' WHEN cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class
FROM r ORDER BY amount DESC;

-- 2.4 Итоги ABC по классам.
WITH p AS (
    SELECT j.id, SUM(j.amount) AS amount FROM journal j WHERE j.transtype = 101 GROUP BY j.id
), r AS (
    SELECT amount, SUM(amount) OVER (ORDER BY amount DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(amount) OVER () AS cum_share FROM p
), c AS (
    SELECT amount, CASE WHEN cum_share <= 0.80 THEN 'A' WHEN cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class FROM r
)
SELECT abc_class, COUNT(*) AS items, SUM(amount) AS amount,
       CAST(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER () AS DECIMAL(6,2)) AS amount_percent
FROM c GROUP BY abc_class ORDER BY abc_class;

-- 2.5 Проверка суммы позиции: amount ≈ price * quantity (с учётом скидки).
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN ABS(amount - price * quantity) <= 0.01 THEN 1 ELSE 0 END) AS equals_price_x_qty,
       SUM(CASE WHEN ABS(amount - (price * quantity - ISNULL(discountamount, 0))) <= 0.01 THEN 1 ELSE 0 END) AS equals_with_discount
FROM journal WHERE transtype = 101;

-- 2.6 Связь с расшифровкой: сколько продаж имеют строки списания ингредиентов в bm_Journal_Details.
SELECT COUNT(*) AS sales_rows,
       SUM(CASE WHEN d.SourceID IS NOT NULL THEN 1 ELSE 0 END) AS with_details,
       SUM(CASE WHEN d.SourceID IS NULL THEN 1 ELSE 0 END)     AS without_details
FROM journal j
LEFT JOIN (SELECT DISTINCT SourceID FROM bm_Journal_Details) d ON d.SourceID = j.transnumber
WHERE j.transtype = 101;

-- 2.7 Бонусная программа по месяцам: число операций и клиентов. BonusValue НЕ суммируем: значения за месяц достигают миллиардов
--     (при выручке ~1 млн), т.е. это не сумма начисления, а накопленный баланс/служебное значение.
SELECT DATEFROMPARTS(YEAR(b.Period), MONTH(b.Period), 1) AS month_start,
       COUNT(*) AS bonus_ops, COUNT(DISTINCT b.ClientID) AS clients
FROM bm_BonusHistory b
GROUP BY DATEFROMPARTS(YEAR(b.Period), MONTH(b.Period), 1) ORDER BY month_start;

-- 2.8 Скидки в продажах: amount = price * quantity (проверено в 2.5), т.е. сумма до скидки. Сколько строк со скидкой и на какую сумму.
SELECT COUNT(*) AS sales_rows,
       SUM(CASE WHEN ISNULL(discountamount, 0) <> 0 THEN 1 ELSE 0 END) AS rows_with_discount,
       SUM(amount) AS gross_amount, SUM(ISNULL(discountamount, 0)) AS discount_sum,
       SUM(amount - ISNULL(discountamount, 0)) AS net_amount
FROM journal WHERE transtype = 101;

-- 2.9 Сверка продаж с оплатами: сумма продаж (101) против оплат (211 Cash + 216 Visa), итога (501) и списаний по себестоимости (111).
SELECT transtype, SUM(amount) AS amount_sum
FROM journal WHERE transtype IN (101, 111, 211, 216, 501) GROUP BY transtype ORDER BY transtype;