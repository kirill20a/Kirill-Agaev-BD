--Код номер 2

--24.10.2026

-- 1. Информация об ошибках
-- 2. Новый тип - один параметр из "списка параметров"
-- 3. Проверка корректности произвольного списка параметров.
-- 4. Проставляет ошибки на строках

do $outer$
begin

	-- 1. Информация об ошибках - прямо на строках measurment_input_params
	begin
		alter table public.measurment_input_params
			add column if not exists is_error          boolean,
			add column if not exists error_description  text;
	exception when duplicate_column then
		raise notice 'Колонки is_error/error_description уже существуют - пропускаем';
	end;

	comment on column public.measurment_input_params.is_error is
		'Признак того, что значение параметра вышло за допустимый диапазон (measurement_parameter_types.min_value/max_value)';
	comment on column public.measurment_input_params.error_description is
		'Текст ошибки для данного конкретного значения параметра (заполняется fn_mark_batch_errors)';

	-- 2. Новый тип - один параметр из "списка параметров"
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

	-- 3. Проверка корректности произвольного списка параметров.

	execute $def1$
		create or replace function public.fn_check_params(p_params public.param_value[])
		returns text
		language plpgsql
		stable
		as $body1$
		declare
			v_errors text[];
		begin
			select array_remove(array_agg(
				case
					when pt.name is null
						then pv.param_name || ': неизвестный параметр (нет в measurement_parameter_types)'
					when pv.param_value is null
						then pt.name || ': значение не задано'
					when pt.min_value is null or pt.max_value is null
						then pt.name || ': не заданы допустимые границы'
					when pv.param_value not between pt.min_value and pt.max_value
						then pt.name || ': вне диапазона (' || pt.min_value || '…' || pt.max_value
							|| '), получено ' || pv.param_value
				end
			), null)
			into v_errors
			from unnest(p_params) as pv
			left join public.measurement_parameter_types pt on pt.name = pv.param_name;

			return coalesce(array_to_string(v_errors, '; '), '');
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.fn_check_params(public.param_value[]) is
			'Проверяет список параметров (public.param_value[]) по диапазонам из measurement_parameter_types; возвращает одну строку со списком ошибок (пустую строку, если ошибок нет)'
	$comment_func1$;

	-- 4. Проставляет is_error/error_description на реальных строках
	--    measurment_input_params для конкретной партии измерений.
	execute $def2$
		create or replace function public.fn_mark_batch_errors(p_batch_id integer)
		returns integer
		language plpgsql
		as $body2$
		declare
			v_marked_count integer := 0;
		begin
			update public.measurment_input_params ip
			set
				is_error = (ip.measurement_value not between pt.min_value and pt.max_value),
				error_description = case
					when ip.measurement_value not between pt.min_value and pt.max_value
						then pt.name || ': вне диапазона (' || pt.min_value || '…' || pt.max_value
							|| '), получено ' || ip.measurement_value
					else null
				end
			from public.measurement_parameter_types pt
			where pt.id = ip.measurement_parameter_type_id
				and ip.measurment_batch_id = p_batch_id;

			get diagnostics v_marked_count = row_count;
			return v_marked_count;
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.fn_mark_batch_errors(integer) is
			'Проставляет is_error/error_description на строках measurment_input_params указанной партии измерений; возвращает количество обновлённых строк'
	$comment_func2$;

end $outer$;