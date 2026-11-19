USE Front;
GO
/* ===== 4. Анализ работы персонала (шаг: полугодие, квартал) ===== */

-- 4.1 Сотрудники по уровню доступа и признаку активности.
SELECT s.description AS access_level, p.deleteflag, COUNT(*) AS persons
FROM personnel p LEFT JOIN securityaccess s ON s.securityaccessid = p.securityaccess
GROUP BY s.description, p.deleteflag ORDER BY persons DESC;

-- 4.2 Проверка логической связи (FK нет): журнал продаж -> сотрудник по loginid.
SELECT COUNT(*) AS sales_rows,
       SUM(CASE WHEN p.personid IS NOT NULL THEN 1 ELSE 0 END) AS person_found,
       SUM(CASE WHEN p.personid IS NULL THEN 1 ELSE 0 END)     AS person_missing
FROM journal j LEFT JOIN personnel p ON p.personid = TRY_CAST(j.loginid AS INT)
WHERE j.transtype = 101;

-- 4.3 Выручка сотрудников по кварталам.
SELECT YEAR(j.dater) AS yr, DATEPART(QUARTER, j.dater) AS quarter, p.personid, p.lastname,
       COUNT(DISTINCT j.receiptn) AS receipts, SUM(j.amount) AS revenue
FROM journal j JOIN personnel p ON p.personid = TRY_CAST(j.loginid AS INT)
WHERE j.transtype = 101
GROUP BY YEAR(j.dater), DATEPART(QUARTER, j.dater), p.personid, p.lastname
ORDER BY yr, quarter, revenue DESC;

-- 4.4 Выручка сотрудников по полугодиям.
SELECT YEAR(j.dater) AS yr, CASE WHEN MONTH(j.dater) <= 6 THEN 1 ELSE 2 END AS half_year, p.personid, p.lastname,
       COUNT(DISTINCT j.receiptn) AS receipts, SUM(j.amount) AS revenue
FROM journal j JOIN personnel p ON p.personid = TRY_CAST(j.loginid AS INT)
WHERE j.transtype = 101
GROUP BY YEAR(j.dater), CASE WHEN MONTH(j.dater) <= 6 THEN 1 ELSE 2 END, p.personid, p.lastname
ORDER BY yr, half_year, revenue DESC;

-- 4.5 ABC-анализ сотрудников по выручке за всё время. ВАЖНО: все продажи оформлены на один логин (906 «Доставка»),
--     поэтому ABC по сотрудникам вырождается в одну строку (100 %). Запрос оставлен как доказательство этого вывода.
WITH s AS (
    SELECT TRY_CAST(j.loginid AS INT) AS personid, SUM(j.amount) AS revenue
    FROM journal j WHERE j.transtype = 101 GROUP BY TRY_CAST(j.loginid AS INT)
), r AS (
    SELECT *, SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(revenue) OVER () AS cum_share FROM s
)
SELECT r.personid, p.lastname, r.revenue, CAST(r.cum_share * 100 AS DECIMAL(6,2)) AS cum_percent,
       CASE WHEN r.cum_share <= 0.80 THEN 'A' WHEN r.cum_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_class
FROM r LEFT JOIN personnel p ON p.personid = r.personid ORDER BY r.revenue DESC;

-- 4.6 Документы, созданные сотрудниками, по полугодиям (bm_JournalBarnetDocs.PersonID).
SELECT YEAR(d.DateAdd) AS yr, CASE WHEN MONTH(d.DateAdd) <= 6 THEN 1 ELSE 2 END AS half_year,
       d.PersonID, p.lastname, COUNT(*) AS docs
FROM bm_JournalBarnetDocs d LEFT JOIN personnel p ON p.personid = d.PersonID
GROUP BY YEAR(d.DateAdd), CASE WHEN MONTH(d.DateAdd) <= 6 THEN 1 ELSE 2 END, d.PersonID, p.lastname
ORDER BY yr, half_year, docs DESC;

-- 4.7 Активность в системе по кварталам (bm_JournalSessions): события и ошибки на сотрудника.
SELECT YEAR(s.DateAdd) AS yr, DATEPART(QUARTER, s.DateAdd) AS quarter, s.PersonID,
       COUNT(*) AS events, SUM(CASE WHEN s.IsError = 1 THEN 1 ELSE 0 END) AS errors
FROM bm_JournalSessions s
GROUP BY YEAR(s.DateAdd), DATEPART(QUARTER, s.DateAdd), s.PersonID ORDER BY yr, quarter, events DESC;

-- 4.8 Смены: сколько смен и какая сумма по кварталам.
SELECT YEAR(DateAdd) AS yr, DATEPART(QUARTER, DateAdd) AS quarter, COUNT(*) AS shifts, SUM(Amount) AS amount
FROM bm_ShiftsOperations GROUP BY YEAR(DateAdd), DATEPART(QUARTER, DateAdd) ORDER BY yr, quarter;

-- 4.9 Смены и входы по кварталам из журнала кассы (bm_ShiftsOperations почти пуста): 301 — вход, 386 — начало работы, 387 — окончание работы.
SELECT YEAR(j.dater) AS yr, DATEPART(QUARTER, j.dater) AS quarter, j.transtype, t.description,
       COUNT(*) AS events, COUNT(DISTINCT j.loginid) AS distinct_logins, COUNT(DISTINCT CAST(j.dater AS date)) AS work_days
FROM journal j LEFT JOIN transtype t ON t.transtypeid = j.transtype
WHERE j.transtype IN (301, 386, 387)
GROUP BY YEAR(j.dater), DATEPART(QUARTER, j.dater), j.transtype, t.description
ORDER BY yr, quarter, j.transtype;

-- 4.10 Какие логины вообще есть в журнале (все типы операций): подтверждает, что работа персонала различима только по рабочим местам, а не по людям.
SELECT j.loginid, p.lastname, COUNT(*) AS rows_cnt, MIN(j.dater) AS first_date, MAX(j.dater) AS last_date
FROM journal j LEFT JOIN personnel p ON p.personid = TRY_CAST(j.loginid AS INT)
GROUP BY j.loginid, p.lastname ORDER BY rows_cnt DESC;