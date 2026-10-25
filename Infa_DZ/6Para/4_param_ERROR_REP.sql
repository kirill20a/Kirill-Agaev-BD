--Код номер 4

--24.10.2026

-- SQL-запрос "Список параметров с ошибками"


with batch_data as (
	select
		b.id                                                                        as batch_id,
		eq.short_name                                                               as equipment_type,
		array_agg(row(pt.name, ip.measurement_value)::public.param_value order by pt.id) as params,
		max(ip.measurement_value) filter (where pt.name = 'Высота метеопаста')      as post_height,
		max(ip.measurement_value) filter (where pt.name = 'Температура')           as temperature,
		max(ip.measurement_value) filter (where pt.name = 'Давление')              as pressure,
		max(ip.measurement_value) filter (where pt.name = 'Направление ветра')     as wind_direction,
		max(ip.measurement_value) filter (where pt.name = 'Скорость ветра')        as wind_speed,
		max(ip.measurement_value) filter (where pt.name = 'Дальность сноса пуль')  as bullet_drift
	from public.measurment_batchs b
	join public.measurment_equipment eq on eq.id = b.measurment_equipment_id
	join public.measurment_input_params ip on ip.measurment_batch_id = b.id
	join public.measurement_parameter_types pt on pt.id = ip.measurement_parameter_type_id
	group by b.id, eq.short_name
),
batch_errors as (
	select
		d.*,
		public.fn_check_params(d.params) as error_description
	from batch_data d
)
select
	batch_id                          as "№",
	equipment_type                    as "Тип оборудования",
	post_height                       as "Высота метеопоста",
	temperature                       as "Температура",
	pressure                          as "Давление",
	wind_direction                    as "Направление ветра",
	wind_speed                        as "Скорость ветра",
	bullet_drift                      as "Дальность сноса пуль",
	(error_description <> '')         as "Флаг: Есть ошибка",
	nullif(error_description, '')     as "Описание ошибки"
from batch_errors
order by batch_id;



-- SQL-запрос "Лучший стрелок"
-- (сотрудники + количество допущенных ошибок в параметрах,
-- через CTE + оконную функцию rank())


with param_checks as (
	select
		b.id          as batch_id,
		b.emploee_id,
		pt.name       as parameter_name,
		(public.fn_check_param(pt.name, ip.measurement_value) <> '') as is_error
	from public.measurment_batchs b
	join public.measurment_input_params ip on ip.measurment_batch_id = b.id
	join public.measurement_parameter_types pt on pt.id = ip.measurement_parameter_type_id
),
employee_stats as (
	select
		e.id                                     as employee_id,
		e.name                                    as employee_name,
		count(pc.*)                               as total_params_measured,
		count(*) filter (where pc.is_error)       as error_count
	from public.employees e
	left join param_checks pc on pc.emploee_id = e.id
	group by e.id, e.name
)
select
	employee_id                                                                  as "№",
	employee_name                                                                as "Сотрудник",
	total_params_measured                                                        as "Всего измерений",
	error_count                                                                  as "Ошибок",
	rank() over (order by error_count asc, total_params_measured desc)          as "Место"
from employee_stats
order by "Место", employee_id;