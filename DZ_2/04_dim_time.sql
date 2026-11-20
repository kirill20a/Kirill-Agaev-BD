
-- Скрипт 4.
-- Таблица dim_time: по одной строке на каждый месяц.
-- Выполнять в pgAdmin (база dataparts). 


CREATE TABLE IF NOT EXISTS dim_time (
    id integer PRIMARY KEY,   
    month_start date NOT NULL,     
    month_end date NOT NULL,      
    month_name text NOT NULL,      
    year_no integer NOT NULL,      
    quarter_no integer NOT NULL,      
    quarter_name text NOT NULL       
);

COMMENT ON TABLE  dim_time IS 'Ресурс «Время»: календарь по месяцам';
COMMENT ON COLUMN dim_time.id IS 'Код (год*100 + номер месяца)';
COMMENT ON COLUMN dim_time.month_start IS 'Дата начала месяца';
COMMENT ON COLUMN dim_time.month_end IS 'Дата окончания месяца';
COMMENT ON COLUMN dim_time.month_name IS 'Название месяца';
COMMENT ON COLUMN dim_time.year_no IS 'Год';
COMMENT ON COLUMN dim_time.quarter_no IS 'Номер квартала';
COMMENT ON COLUMN dim_time.quarter_name IS 'Название квартала';

-- Функция заполняет таблицу месяцами от p_from до p_to (включительно)
CREATE OR REPLACE FUNCTION fill_dim_time(p_from date, p_to date)
RETURNS integer
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_month  date := date_trunc('month', p_from)::date;
    v_last   date := date_trunc('month', p_to)::date;
    v_names  text[] := ARRAY['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
                             'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    v_cnt    integer := 0;
    v_rows   integer;
    v_q      integer;
BEGIN
    WHILE v_month <= v_last LOOP
        v_q := extract(quarter FROM v_month)::integer;
        INSERT INTO dim_time (id, month_start, month_end, month_name, year_no, quarter_no, quarter_name)
        VALUES (
            extract(year FROM v_month)::integer * 100 + extract(month FROM v_month)::integer,
            v_month,
            (v_month + interval '1 month' - interval '1 day')::date,
            v_names[extract(month FROM v_month)::integer],
            extract(year FROM v_month)::integer,
            v_q,
            v_q || ' квартал ' || extract(year FROM v_month)::integer
        )
        ON CONFLICT (id) DO NOTHING;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_cnt := v_cnt + v_rows;
        v_month := (v_month + interval '1 month')::date;
    END LOOP;
    RETURN v_cnt;
END
$fn$;

-- Период данных Front: ноябрь 2020 - декабрь 2023 
-- Чтобы расширить календарь, поменяйть даты и запустить.
SELECT fill_dim_time('2020-11-01', '2023-12-31') AS months_added;

-- Результат

--   Код | Дата начала месяца | Дата окончания месяца | Название месяца | Год | Номер квартала | Название квартала

SELECT id AS "Код",
       month_start AS "Дата начала месяца",
       month_end AS "Дата окончания месяца",
       month_name AS "Название месяца",
       year_no AS "Год",
       quarter_no AS "Номер квартала",
       quarter_name AS "Название квартала"
FROM dim_time
ORDER BY id;
