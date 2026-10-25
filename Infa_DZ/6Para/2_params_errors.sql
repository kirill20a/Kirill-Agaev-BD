--Код номер 2

--24.10.2026

-- 1. Новый тип - один параметр из "списка параметров"
-- 2. Проверка одного параметра  
-- 3. Проверка произвольного списка параметров 



do $outer$
begin

	-- 0. Чистим то, что было в прошлой версии
	alter table public.measurment_input_params
		drop column if exists is_error,
		drop column if exists error_description;
	drop function if exists public.fn_mark_batch_errors(integer);

	-- 1. Новый тип - один параметр из "списка параметров"
	begin
		execute 'create type public.param_value as (
			param_name   text,
			param_value  numeric
		)';
	exception when duplicate_object then
		raise notice 'Тип public.param_value уже существует - пропускаем';
	end;

	comment on type public.param_value is
		'Один параметр измерения: имя параметра (как в measurement_parameter_types.name) и его значение. "Список параметров" - это массив public.param_value[]';
	comment on column public.param_value.param_name is 'Имя параметра (сверяется с measurement_parameter_types.name)';
	comment on column public.param_value.param_value is 'Измеренное значение параметра';

	-- 2. Проверка одного параметра
	execute $def1$
		create or replace function public.fn_check_param(p_param_name text, p_value numeric)
		returns text
		language plpgsql
		stable
		as $body1$
		declare
			v_min   numeric;
			v_max   numeric;
			v_found boolean;
		begin
			select pt.min_value, pt.max_value, true
			into v_min, v_max, v_found
			from public.measurement_parameter_types pt
			where pt.name = p_param_name;

			if v_found is null then
				return p_param_name || ': неизвестный параметр (нет в measurement_parameter_types)';
			elsif p_value is null then
				return p_param_name || ': значение не задано';
			elsif v_min is null or v_max is null then
				return p_param_name || ': не заданы допустимые границы';
			elsif p_value not between v_min and v_max then
				return p_param_name || ': вне диапазона (' || v_min || '…' || v_max || '), получено ' || p_value;
			end if;

			return '';
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.fn_check_param(text, numeric) is
			'Проверяет один параметр по диапазону из measurement_parameter_types; возвращает текст ошибки или пустую строку, если ошибки нет'
	$comment_func1$;

	-- 3. Проверка произвольного списка параметров
	execute $def2$
		create or replace function public.fn_check_params(p_params public.param_value[])
		returns text
		language plpgsql
		stable
		as $body2$
		declare
			v_errors text;
		begin
			select string_agg(e.msg, '; ')
			into v_errors
			from (
				select public.fn_check_param(pv.param_name, pv.param_value) as msg
				from unnest(p_params) as pv
			) e
			where e.msg <> '';

			return coalesce(v_errors, '');
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.fn_check_params(public.param_value[]) is
			'Проверяет список параметров (public.param_value[]) через fn_check_param; возвращает одну строку со списком ошибок (пустую строку, если ошибок нет)'
	$comment_func2$;

end $outer$;