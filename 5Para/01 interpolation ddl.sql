-- Код 1

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

	execute $comment_type$
		comment on type public.interpolation_bounds is
			'Структура границ для линейной интерполяции: нижняя точка (x0, y0) и верхняя точка (x1, y1)'
	$comment_type$;
	execute $comment_col1$
		comment on column public.interpolation_bounds.x0 is 'Нижняя граница - значение аргумента (x)'
	$comment_col1$;
	execute $comment_col2$
		comment on column public.interpolation_bounds.y0 is 'Нижняя граница - значение функции (y / поправка)'
	$comment_col2$;
	execute $comment_col3$
		comment on column public.interpolation_bounds.x1 is 'Верхняя граница - значение аргумента (x)'
	$comment_col3$;
	execute $comment_col4$
		comment on column public.interpolation_bounds.y1 is 'Верхняя граница - значение функции (y / поправка)'
	$comment_col4$;

	-- 2. Функция: по температуре определяет границы интерполяции

	execute $def1$
		create or replace function public.get_interpolation_bounds(p_temperature numeric)
		returns public.interpolation_bounds
		language plpgsql
		stable
		as $body1$
		declare
			v_result         public.interpolation_bounds;
			v_table_lower_t  numeric;
			v_table_upper_t  numeric;
		begin
			select max(temperature) into v_table_lower_t
			from public.calc_temperature_correction
			where temperature <= p_temperature;

			select min(temperature) into v_table_upper_t
			from public.calc_temperature_correction
			where temperature >= p_temperature;

			v_result.x0 := coalesce(v_table_lower_t, p_temperature);
			v_result.x1 := coalesce(v_table_upper_t, p_temperature);

			if v_table_lower_t is not null then
				select correction into v_result.y0
				from public.calc_temperature_correction
				where temperature = v_table_lower_t;
			else
				select correction into v_result.y0
				from public.calc_temperature_correction
				where temperature = v_table_upper_t;
			end if;

			if v_table_upper_t is not null then
				select correction into v_result.y1
				from public.calc_temperature_correction
				where temperature = v_table_upper_t;
			else
				select correction into v_result.y1
				from public.calc_temperature_correction
				where temperature = v_table_lower_t;
			end if;

			return v_result;
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.get_interpolation_bounds(numeric) is
			'Определяет границы интерполяции (interpolation_bounds) по заданной температуре; за пределами диапазона таблицы calc_temperature_correction возвращает "плоскую" границу по ближайшей реальной точке'
	$comment_func1$;

	-- 3. Функция: расчёт интерполированного значения
	--    Классическая формула линейной интерполяции:
	--      y = y0 + (y1 - y0) * (x - x0) / (x1 - x0)
	--    Если x0 = x1  - деление на ноль не происходит,
	--    сразу возвращается y0 (= y1 в этом случае).
	execute $def2$
		create or replace function public.calc_interpolation(
			p_x numeric,
			p_bounds public.interpolation_bounds
		)
		returns numeric
		language plpgsql
		stable
		as $body2$
		declare
			v_result numeric;
		begin
			if p_bounds.x1 = p_bounds.x0 then
				v_result := p_bounds.y0;
			else
				v_result := p_bounds.y0 + (p_bounds.y1 - p_bounds.y0)
					* (p_x - p_bounds.x0) / (p_bounds.x1 - p_bounds.x0);
			end if;

			return v_result;
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.calc_interpolation(numeric, public.interpolation_bounds) is
			'Рассчитывает интерполированное значение y для произвольного x по структуре границ interpolation_bounds (формула линейной интерполяции)'
	$comment_func2$;

end $outer$;