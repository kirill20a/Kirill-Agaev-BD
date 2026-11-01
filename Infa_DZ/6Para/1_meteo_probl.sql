-- Код номер 1 

-- 24.10.2026

-- PL/pgSQL-скрипт (DO $$): таблицы констант для расчета
-- приближенного метеобюллетеня (Метео-11) + вспомогательные
-- функции доступа к ним.


do $outer$
begin

	-- 1. Таблица 1 ТЗ: виртуальная поправка температуры ΔTv
	--    по измеренной приземной температуре t0.
	begin
		execute 'create table public.virtual_temp_correction (
			temperature numeric(5,2) not null primary key,
			correction  numeric(5,2) not null
		)';
	exception when duplicate_table then
		raise notice 'Таблица public.virtual_temp_correction уже существует - пропускаем создание';
	end;

	comment on table public.virtual_temp_correction is
		'Таблица 1 ТЗ: виртуальная поправка ΔTv по измеренной приземной температуре t0 (используется при расчете группы ТТ бюллетеня Метео-11)';

	if not exists (select 1 from public.virtual_temp_correction) then
		insert into public.virtual_temp_correction (temperature, correction) values
			(0,   0),      
			(5,   0.5),
			(10,  1),
			(15,  1),
			(20,  1.5),
			(25,  2),
			(30,  3.5),
			(40,  4.5);
	end if;

	-- 2. Именованные скалярные константы алгоритма (табличное
	--    давление, табличная виртуальная температура и т.п.)
	begin
		execute 'create table public.meteo_constants (
			code        text not null primary key,
			value       numeric(10,2) not null,
			description text
		)';
	exception when duplicate_table then
		raise notice 'Таблица public.meteo_constants уже существует - пропускаем создание';
	end;

	comment on table public.meteo_constants is
		'Именованные скалярные константы расчета Метео-11 (табличное давление, табличная виртуальная температура и т.д.)';

	insert into public.meteo_constants (code, value, description) values
		('baseline_pressure_mmhg',       750.0, 'Табличное значение наземного давления, мм рт. ст. (используется в группе БББ)'),
		('baseline_virtual_temp_c',       15.9, 'Табличное значение приземной виртуальной температуры, °C (используется в группе ТТ)')
	on conflict (code) do update set value = excluded.value, description = excluded.description;

	-- 3. Функция доступа к скалярной константе по коду
	execute $def1$
		create or replace function public.get_meteo_constant(p_code text)
		returns numeric
		language plpgsql
		stable
		as $body1$
		declare
			v_value numeric;
		begin
			select value into v_value
			from public.meteo_constants
			where code = p_code;

			if v_value is null then
				raise exception 'Константа "%" не найдена в public.meteo_constants', p_code;
			end if;

			return v_value;
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.get_meteo_constant(text) is
			'Возвращает значение именованной константы расчета Метео-11 из public.meteo_constants'
	$comment_func1$;

	-- 4. Границы интерполяции для виртуальной поправки 
	execute $def2$
		create or replace function public.get_virtual_temp_bounds(p_temperature numeric)
		returns public.interpolation_bounds
		language plpgsql
		stable
		as $body2$
		declare
			v_result         public.interpolation_bounds;
			v_table_lower_t  numeric;
			v_table_upper_t  numeric;
		begin
			select max(temperature) into v_table_lower_t
			from public.virtual_temp_correction
			where temperature <= p_temperature;

			select min(temperature) into v_table_upper_t
			from public.virtual_temp_correction
			where temperature >= p_temperature;

			v_result.x0 := coalesce(v_table_lower_t, p_temperature);
			v_result.x1 := coalesce(v_table_upper_t, p_temperature);

			if v_table_lower_t is not null then
				select correction into v_result.y0
				from public.virtual_temp_correction
				where temperature = v_table_lower_t;
			else
				select correction into v_result.y0
				from public.virtual_temp_correction
				where temperature = v_table_upper_t;
			end if;

			if v_table_upper_t is not null then
				select correction into v_result.y1
				from public.virtual_temp_correction
				where temperature = v_table_upper_t;
			else
				select correction into v_result.y1
				from public.virtual_temp_correction
				where temperature = v_table_lower_t;
			end if;

			return v_result;
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.get_virtual_temp_bounds(numeric) is
			'Границы интерполяции (interpolation_bounds) для виртуальной поправки ΔTv по таблице 1 ТЗ (virtual_temp_correction)'
	$comment_func2$;

end $outer$;