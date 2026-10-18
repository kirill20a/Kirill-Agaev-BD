--Часть 1


-- PL/pgSQL-скрипт (DO $$): структура для линейной интерполяции.


do $outer$
begin

	-- 1. Тип данных - структура для интерполяции
	begin
		execute 'create type public.interpolation_bounds as (
			x0 numeric,
			y0 numeric,
			x1 numeric,
			y1 numeric
		)';
	exception when duplicate_object then
		raise notice 'Тип public.interpolation_bounds уже существует - пропускаем';
	end;

	-- 2. Функция: по температуре определяет границы интерполяции
	execute $def1$
		create or replace function public.get_interpolation_bounds(p_temperature numeric)
		returns public.interpolation_bounds
		language sql
		stable
		as $body1$
			select
				coalesce(b.table_lower_t, p_temperature) as x0,
				case
					when b.table_lower_t is not null then
						(select correction from public.calc_temperature_correction
							where temperature = b.table_lower_t)
					else
						(select correction from public.calc_temperature_correction
							where temperature = b.table_upper_t)
				end as y0,
				coalesce(b.table_upper_t, p_temperature) as x1,
				case
					when b.table_upper_t is not null then
						(select correction from public.calc_temperature_correction
							where temperature = b.table_upper_t)
					else
						(select correction from public.calc_temperature_correction
							where temperature = b.table_lower_t)
				end as y1
			from (
				select
					(select max(temperature) from public.calc_temperature_correction
						where temperature <= p_temperature) as table_lower_t,
					(select min(temperature) from public.calc_temperature_correction
						where temperature >= p_temperature) as table_upper_t
			) b;
		$body1$;
	$def1$;

	-- 3. Функция: расчёт интерполированного значения y по
	--    произвольному x и структуре границ interpolation_bounds.
	
	execute $def2$
		create or replace function public.calc_interpolation(
			p_x numeric,
			p_bounds public.interpolation_bounds
		)
		returns numeric
		language sql
		stable
		as $body2$
			select case
				when p_bounds.x1 = p_bounds.x0 then p_bounds.y0
				else p_bounds.y0 + (p_bounds.y1 - p_bounds.y0)
					* (p_x - p_bounds.x0) / (p_bounds.x1 - p_bounds.x0)
			end;
		$body2$;
	$def2$;

end $outer$;



--Часть 2

-- Проверочный PL/pgSQL-скрипт (DO $$): тесты расчёта
-- интерполяции по примерам из Технического задания.

do $$
declare
	rec             record;
	v_bounds        public.interpolation_bounds;
	v_actual        numeric;
	v_passed_count  integer := 0;
	v_failed_count  integer := 0;
begin

	raise notice '================ Проверка интерполяции по ТЗ ================';

	for rec in
		select * from (values
			-- (описание теста, температура, ожидаемый результат)
			('Пример из ТЗ (26 градусов)',                26::numeric, 2.3::numeric),
			('Точное попадание в таблицу (25 градусов)',   25,          2.0),
			('Точное попадание в таблицу (0 градусов)',    0,           0.5),
			('Между точками 0 и 5 (3 градуса)',            3,           0.5),
			('Между точками 10 и 20 (15 градусов)',        15,          1.0),
			('Граничное условие: выше 40 (200 градусов)',  200,         4.5),
			('Граничное условие: ниже 0 (-10 градусов)',   -10,         0.5),
			('Ровно верхняя граница (40 градусов)',        40,          4.5)
		) as t(test_label, test_temperature, test_expected)
	loop
		v_bounds := public.get_interpolation_bounds(rec.test_temperature);
		v_actual := public.calc_interpolation(rec.test_temperature, v_bounds);

		if abs(v_actual - rec.test_expected) < 0.0001 then
			v_passed_count := v_passed_count + 1;
			raise notice '[PASS] % (t=%): граница x0=% y0=% / x1=% y1=% -> y=% (ожидалось %)',
				rec.test_label, rec.test_temperature,
				v_bounds.x0, v_bounds.y0, v_bounds.x1, v_bounds.y1,
				v_actual, rec.test_expected;
		else
			v_failed_count := v_failed_count + 1;
			raise notice '[FAIL] % (t=%): граница x0=% y0=% / x1=% y1=% -> y=% (ожидалось %)',
				rec.test_label, rec.test_temperature,
				v_bounds.x0, v_bounds.y0, v_bounds.x1, v_bounds.y1,
				v_actual, rec.test_expected;
		end if;
	end loop;

	raise notice '================================================================';
	raise notice 'Итого: % пройдено, % провалено', v_passed_count, v_failed_count;

end $$;