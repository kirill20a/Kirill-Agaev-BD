--Код номер 6

--24.10.2026

-- PL/pgSQL-скрипт (DO $$): расчет строки бюллетеня для
-- стандартных высот до 4 км (вариант ДМК) - H, TT, HH, CC.
--
-- Требует выполненных ранее:
--   1_meteo_probl.sql  (ΔTv, константы)
--   3_meteo11_header.sql   (fn_format_bbbtt и пр.)
--   5_altitude_tables_ddl.sql (таблицы 2 и 3)


do $outer$
begin

	-- 1. Отклонение приземной виртуальной температуры 
	-- используется как "Δτ0" для разложения по таблице 2.
	execute $def1$
		create or replace function public.fn_ground_temp_deviation(p_temperature numeric)
		returns integer
		language plpgsql
		stable
		as $body1$
		declare
			v_bounds   public.interpolation_bounds;
			v_delta_tv numeric;
			v_t0       numeric;
		begin
			v_bounds   := public.get_virtual_temp_bounds(p_temperature);
			v_delta_tv := public.calc_interpolation(p_temperature, v_bounds);
			v_t0       := p_temperature + v_delta_tv;
			return round(v_t0 - public.get_meteo_constant('baseline_virtual_temp_c'))::integer;
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.fn_ground_temp_deviation(numeric) is
			'ΔT0 - отклонение приземной виртуальной температуры (целое, без кодирования знака), используется как Δτ0 для таблицы 2'
	$comment_func1$;

	-- 2. Среднее отклонение температуры Δt_Y для одной стандартной высоты
	
	execute $def2$
		create or replace function public.fn_altitude_temp_code(p_height integer, p_delta_t0 integer)
		returns text
		language plpgsql
		stable
		as $body2$
		declare
			v_is_negative boolean := (p_delta_t0 < 0);
			v_abs         integer := abs(p_delta_t0);
			v_tens        integer := (v_abs / 10) * 10;
			v_ones        integer := v_abs % 10;
			v_sum         integer := 0;
			v_component   integer;
		begin
			if v_tens > 0 then
				select value into v_component
				from public.altitude_temp_deviation
				where height_m = p_height and delta_magnitude = v_tens and is_negative = v_is_negative;

				if v_component is null then
					raise exception 'Таблица 2: нет данных для высоты % / разряда % / знака %', p_height, v_tens, v_is_negative;
				end if;
				v_sum := v_sum + v_component;
			end if;

			if v_ones > 0 then
				select value into v_component
				from public.altitude_temp_deviation
				where height_m = p_height and delta_magnitude = v_ones and is_negative = v_is_negative;

				if v_component is null then
					raise exception 'Таблица 2: нет данных для высоты % / разряда % / знака %', p_height, v_ones, v_is_negative;
				end if;
				v_sum := v_sum + v_component;
			end if;

			if v_sum < 0 then
				return lpad((abs(v_sum) + 50)::text, 2, '0');
			else
				return lpad(v_sum::text, 2, '0');
			end if;
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.fn_altitude_temp_code(integer, integer) is
			'Группа TT тела бюллетеня: среднее отклонение температуры Δt_Y для стандартной высоты (раскладка Δτ0 на десятки+единицы по таблице 2, кодирование "+50" для отрицательных)'
	$comment_func2$;

	-- 3. Скорость и направление среднего ветра для одной высоты.
	--    Скорость приземного ветра < 3 м/с -> везде нули.
	execute $def3$
		create or replace function public.fn_altitude_wind(
			p_height           integer,
			p_ground_speed     integer,
			p_ground_direction numeric
		)
		returns table (wind_speed integer, wind_direction integer)
		language plpgsql
		stable
		as $body3$
		declare
			v_speed integer;
			v_delta integer;
		begin
			if p_ground_speed < 3 then
				wind_speed     := 0;
				wind_direction := 0;
				return next;
				return;
			end if;

			select value into v_speed
			from public.altitude_wind_speed
			where height_m = p_height and ground_speed = p_ground_speed;

			if v_speed is null then
				raise exception 'Таблица 3: нет скорости ветра для высоты % / приземной скорости %', p_height, p_ground_speed;
			end if;

			select delta_angle into v_delta
			from public.altitude_wind_direction
			where height_m = p_height;

			wind_speed     := v_speed;
			wind_direction := (round(p_ground_direction)::integer + v_delta) % 60;  -- угломер: 60 больших делений в круге
			return next;
		end;
		$body3$;
	$def3$;

	execute $comment_func3$
		comment on function public.fn_altitude_wind(integer, integer, numeric) is
			'Группы HH/CC тела бюллетеня: направление (дирекционный угол) и скорость среднего ветра для стандартной высоты (таблица 3; при приземной скорости < 3 м/с - нули)'
	$comment_func3$;

	-- 4. Вся строка таблицы Метео-11 ПРИБЛИЖЕННЫЙ (9 стандартных
	--    высот до 4 км) для варианта ДМК.
	execute $def4$
		create or replace function public.fn_build_meteo11_body(
			p_pressure          numeric,
			p_temperature       numeric,
			p_ground_wind_dir   numeric,
			p_ground_wind_speed integer
		)
		returns table (
			"H"  text,
			"TT" text,
			"HH" text,
			"CC" text
		)
		language plpgsql
		stable
		as $body4$
		declare
			v_delta_t0 integer := public.fn_ground_temp_deviation(p_temperature);
			v_height   integer;
			v_wind     record;
		begin
			for v_height in
				select unnest(array[200,400,800,1200,1600,2000,2400,3000,4000])
			loop
				select * into v_wind
				from public.fn_altitude_wind(v_height, p_ground_wind_speed, p_ground_wind_dir);

				"H"  := lpad((v_height / 100)::text, 2, '0');
				"TT" := public.fn_altitude_temp_code(v_height, v_delta_t0);
				"HH" := lpad(v_wind.wind_direction::text, 2, '0');
				"CC" := lpad(v_wind.wind_speed::text, 2, '0');
				return next;
			end loop;
		end;
		$body4$;
	$def4$;

	execute $comment_func4$
		comment on function public.fn_build_meteo11_body(numeric, numeric, numeric, integer) is
			'Полная таблица бюллетеня Метео-11 ПРИБЛИЖЕННЫЙ (вариант ДМК) для 9 стандартных высот до 4 км: H, TT, HH, CC'
	$comment_func4$;

end $outer$;