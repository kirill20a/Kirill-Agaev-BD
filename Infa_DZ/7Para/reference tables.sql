
-- измерений по допустимым диапазонам, взятым из таблицы
-- public.measurement_parameter_types 
--
-- Состав:
--   1. Дополняем measurement_parameter_types двумя колонками -
--      min_value / max_value.
--      Если колонки уже есть - пропускаем.
--   2. Заполняем диапазоны для 6 существующих параметров.
--   3. Функция public.fn_validate_batch(p_batch_id) -
--      по одному generic-условию  проверяет ВСЕ параметры партии
--      измерений (measurment_batchs). Возвращает построчно: параметр,
--      значение, границы, флаг ошибки, текст ошибки.
--   4. Функция public.fn_validate_batches_report() - сводный
--      отчёт, использует fn_validate_batch()
--      и сворачивает результат в одну строку на партию.


do $outer$
begin

	-- 1. Диапазоны допустимых значений - прямо в таблице типов параметров
	begin
		alter table public.measurement_parameter_types
			add column if not exists min_value numeric(10,2),
			add column if not exists max_value numeric(10,2);
	exception when duplicate_column then
		raise notice 'Колонки min_value/max_value уже существуют - пропускаем';
	end;

	comment on column public.measurement_parameter_types.min_value is
		'Нижняя граница допустимого диапазона значения параметра';
	comment on column public.measurement_parameter_types.max_value is
		'Верхняя граница допустимого диапазона значения параметра';

	-- 2. Диапазоны для существующих параметров (ЗАГЛУШКИ )
	update public.measurement_parameter_types set min_value = 0,    max_value = 3000 where name = 'Высота метеопаста';
	update public.measurement_parameter_types set min_value = -50,  max_value = 50   where name = 'Температура';
	update public.measurement_parameter_types set min_value = 600,  max_value = 800  where name = 'Давление';
	update public.measurement_parameter_types set min_value = 0,    max_value = 360  where name = 'Направление ветра';
	update public.measurement_parameter_types set min_value = 0,    max_value = 40   where name = 'Скорость ветра';
	update public.measurement_parameter_types set min_value = 0,    max_value = 5000 where name = 'Дальность сноса пуль';

	-- 3. Проверка одной партии измерений 
	execute $def1$
		create or replace function public.fn_validate_batch(p_batch_id integer)
		returns table (
			parameter_name     text,
			measurement_value  numeric,
			min_value          numeric,
			max_value          numeric,
			is_error           boolean,
			error_message      text
		)
		language plpgsql
		stable
		as $body1$
		begin
			return query
			select
				pt.name,
				ip.measurement_value,
				pt.min_value,
				pt.max_value,
				(ip.measurement_value is null
					or pt.min_value is null
					or pt.max_value is null
					or ip.measurement_value not between pt.min_value and pt.max_value)   as is_error,
				case
					when ip.measurement_value is null then pt.name || ': значение не задано'
					when pt.min_value is null or pt.max_value is null
						then pt.name || ': не заданы допустимые границы'
					when ip.measurement_value not between pt.min_value and pt.max_value
						then pt.name || ': вне диапазона (' || pt.min_value || '…' || pt.max_value
							|| '), получено ' || ip.measurement_value
				end as error_message
			from public.measurment_input_params ip
			join public.measurement_parameter_types pt on pt.id = ip.measurement_parameter_type_id
			where ip.measurment_batch_id = p_batch_id
			order by pt.id;
		end;
		$body1$;
	$def1$;

	execute $comment_func1$
		comment on function public.fn_validate_batch(integer) is
			'Проверка всех параметров одной партии измерений по границам min_value/max_value из measurement_parameter_types (без IF/ELSIF - одно универсальное условие)'
	$comment_func1$;

	-- 4. Сводный отчёт по всем партиям (пивот под требуемую форму таблицы)
	execute $def2$
		create or replace function public.fn_validate_batches_report()
		returns table (
			"№"                      bigint,
			"Тип оборудования"       text,
			"Высота метеопоста"      numeric,
			"Температура"            numeric,
			"Давление"               numeric,
			"Направление ветра"      numeric,
			"Скорость ветра"         numeric,
			"Дальность сноса пуль"   numeric,
			"Флаг: Есть ошибка"      boolean,
			"Описание ошибки"        text
		)
		language plpgsql
		stable
		as $body2$
		begin
			return query
			select
				row_number() over (order by b.id),
				eq.short_name::text,
				max(v.measurement_value) filter (where v.parameter_name = 'Высота метеопаста'),
				max(v.measurement_value) filter (where v.parameter_name = 'Температура'),
				max(v.measurement_value) filter (where v.parameter_name = 'Давление'),
				max(v.measurement_value) filter (where v.parameter_name = 'Направление ветра'),
				max(v.measurement_value) filter (where v.parameter_name = 'Скорость ветра'),
				max(v.measurement_value) filter (where v.parameter_name = 'Дальность сноса пуль'),
				bool_or(v.is_error),
				nullif(string_agg(v.error_message, '; ' order by v.parameter_name) filter (where v.is_error), '')
			from public.measurment_batchs b
			join public.measurment_equipment eq on eq.id = b.measurment_equipment_id
			cross join lateral public.fn_validate_batch(b.id) v
			group by b.id, eq.short_name
			order by b.id;
		end;
		$body2$;
	$def2$;

	execute $comment_func2$
		comment on function public.fn_validate_batches_report() is
			'Сводный отчёт проверки параметров по всем партиям измерений '
	$comment_func2$;

end $outer$;