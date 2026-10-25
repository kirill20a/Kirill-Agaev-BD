--Код номер 3

--24.10.2026


-- PL/pgSQL-скрипт (DO $$): функции расчета заголовка
-- приближенного бюллетеня Метео-11 - группы ДДЧЧМ, ВВВВ, БББТТ.


do $outer$
begin

	-- 0. Константы расчёта - в таблице. Поменять значение = update одной строки.
	create table if not exists public.meteo11_constants (
		name        text primary key,
		value       numeric not null,
		description text
	);

	comment on table public.meteo11_constants is
		'Настраиваемые константы расчёта заголовка бюллетеня Метео-11';

	insert into public.meteo11_constants (name, value, description) values
		('baseline_pressure_mmhg',  750,  'Нормальное давление, мм рт. ст. (от него считается БББ)'),
		('baseline_virtual_temp_c', 15.9, 'Нормальная виртуальная температура, °C (от неё считается ТТ)'),
		('bbb_negative_offset',     500,  'Добавка к модулю отклонения давления, если оно отрицательное (признак минуса в БББ)'),
		('tt_negative_offset',      50,   'Добавка к модулю отклонения температуры, если оно отрицательное (признак минуса в ТТ)')
	on conflict (name) do nothing;

	execute $def0$
		create or replace function public.fn_meteo11_const(p_name text)
		returns numeric
		language plpgsql
		stable
		as $body0$
		declare
			v_value numeric;
		begin
			select c.value into v_value from public.meteo11_constants c where c.name = p_name;
			if v_value is null then
				raise exception 'Константа % не найдена в public.meteo11_constants', p_name;
			end if;
			return v_value;
		end;
		$body0$;
	$def0$;

	-- 1. ДДЧЧМ - день, час и десятки минут окончания зондирования.
	--    Пример: 24 число, 09:30 -> "24093".
	execute $def1$
		create or replace function public.fn_format_ddchm(p_measured_at timestamp default now())
		returns text
		language plpgsql
		stable
		as $body1$
		declare
			v_day    integer;
			v_hour   integer;
			v_tens_m integer;
		begin
			v_day    := extract(day  from p_measured_at)::integer;
			v_hour   := extract(hour from p_measured_at)::integer;
			v_tens_m := floor(extract(minute from p_measured_at) / 10)::integer;

			return lpad(v_day::text, 2, '0') || lpad(v_hour::text, 2, '0') || v_tens_m::text;
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.fn_format_ddchm(timestamp) is
			'Группа ДДЧЧМ бюллетеня Метео-11: день, час и десятки минут времени измерения (по умолчанию - текущее время)'
	$comment_func1$;

	-- 2. ВВВВ - высота метеопоста над уровнем моря, 4 разряда.
	--    Пример: 60 -> "0060".

	execute $def2$
		create or replace function public.fn_format_vvvv(p_post_height integer)
		returns text
		language plpgsql
		stable
		as $body2$
		begin
			return lpad(abs(p_post_height)::text, 4, '0');
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.fn_format_vvvv(integer) is
			'Группа ВВВВ бюллетеня Метео-11: высота метеопоста над уровнем моря (4 разряда). Знак для отрицательной высоты в ТЗ не описан - сейчас берётся модуль'
	$comment_func2$;

	-- 3. БББТТ - отклонение давления (БББ) + отклонение приземной
	--    виртуальной температуры (ТТ).

	execute $def3$
		create or replace function public.fn_format_bbbtt(p_pressure numeric, p_temperature numeric)
		returns text
		language plpgsql
		stable
		as $body3$
		declare
			v_delta_h        numeric;
			v_bbb            text;
			v_virtual_bounds public.interpolation_bounds;
			v_delta_tv       numeric;
			v_t0             numeric;
			v_delta_t0       integer;
			v_tt             text;
		begin
			-- БББ
			v_delta_h := p_pressure - public.fn_meteo11_const('baseline_pressure_mmhg');

			if v_delta_h < 0 then
				v_bbb := lpad((abs(round(v_delta_h)) + public.fn_meteo11_const('bbb_negative_offset'))::integer::text, 3, '0');
			else
				v_bbb := lpad(round(v_delta_h)::integer::text, 3, '0');
			end if;

			-- ТТ
			v_virtual_bounds := public.get_virtual_temp_bounds(p_temperature);
			v_delta_tv       := public.calc_interpolation(p_temperature, v_virtual_bounds);
			v_t0             := p_temperature + v_delta_tv;
			v_delta_t0       := round(v_t0 - public.fn_meteo11_const('baseline_virtual_temp_c'));

			if v_delta_t0 < 0 then
				v_tt := lpad((abs(v_delta_t0) + public.fn_meteo11_const('tt_negative_offset'))::integer::text, 2, '0');
			else
				v_tt := lpad(v_delta_t0::text, 2, '0');
			end if;

			return v_bbb || v_tt;
		end;
		$body3$;
	$def3$;

	execute $comment_func3$
		comment on function public.fn_format_bbbtt(numeric, numeric) is
			'Группа БББТТ бюллетеня Метео-11: БББ - отклонение давления от нормы, ТТ - округлённое отклонение приземной виртуальной температуры от нормы (нормы - в public.meteo11_constants)'
	$comment_func3$;

	-- 4. Удобная обёртка - весь заголовок одной строкой
	--    (ДДЧЧМ + ВВВВ + БББТТ через пробел, как в примере ТЗ).
	execute $def4$
		create or replace function public.fn_format_meteo11_header(
			p_post_height  integer,
			p_pressure     numeric,
			p_temperature  numeric,
			p_measured_at  timestamp default now()
		)
		returns text
		language plpgsql
		stable
		as $body4$
		begin
			return
				public.fn_format_ddchm(p_measured_at) || ' ' ||
				public.fn_format_vvvv(p_post_height)  || ' ' ||
				public.fn_format_bbbtt(p_pressure, p_temperature);
		end;
		$body4$;
	$def4$;

	execute $comment_func4$
		comment on function public.fn_format_meteo11_header(integer, numeric, numeric, timestamp) is
			'Полный заголовок приближенного бюллетеня Метео-11: ДДЧЧМ ВВВВ БББТТ'
	$comment_func4$;

end $outer$;