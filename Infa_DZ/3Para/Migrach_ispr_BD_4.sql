-- Аудит качества тестовых данных 
-- 2026-10-04



-- ЧАСТЬ 1. ДИАГНОСТИКА 

-- 1. Каждый пользователь имеет одинаковое количество измерений?
select
	e.id                     as employee_id,
	e.name                   as employee_name,
	count(b.id)              as batches_count
from employees e
left join measurement_batchs b
	on b.employee_id = e.id
group by e.id, e.name
order by e.id;

-- 2. Есть ли пустые пачки измерений (без единого параметра)?
select
	b.id                     as batch_id,
	b.employee_id,
	b.measurment_equipment_id
from measurement_batchs b
left join measurement_input_params p
	on p.measurement_batch_id = b.id
where p.id is null;


-- 3. Содержит ли каждая пачка полный набор параметров для своего оборудования?

-- 3а. Сводка: ожидаемое количество типов параметров против фактического
select
	b.id as batch_id,
	b.measurment_equipment_id,
	(
		select count(*)
		from measurement_parameter_types mpt
		where mpt.measurement_equipment_id is null
		   or mpt.measurement_equipment_id = b.measurment_equipment_id
	) as expected_types_count,
	(
		select count(distinct p.measurement_parameter_type_id)
		from measurement_input_params p
		where p.measurement_batch_id = b.id
	) as actual_types_count
from measurement_batchs b
order by b.id;

-- 3б. Детально, каких типов не хватает и какие лишние 
select
	b.id as batch_id,
	mpt.id as param_type_id,
	mpt.name as param_type_name,
	case when p.id is null then 'отсутствует' else 'есть' end as status,
	case
		when mpt.measurement_equipment_id is not null
		 and mpt.measurement_equipment_id <> b.measurment_equipment_id
		then 'не должно быть у этого оборудования'
		else ''
	end as equipment_mismatch
from measurement_batchs b
cross join measurement_parameter_types mpt
left join measurement_input_params p
	on p.measurement_batch_id = b.id
	and p.measurement_parameter_type_id = mpt.id
where b.id in (1, 11)
	and (
		mpt.measurement_equipment_id is null
		or mpt.measurement_equipment_id = b.measurment_equipment_id
		or p.id is not null
	)
order by b.id, mpt.id;


-- 4. Все ли значения в допустимом диапазоне (границы по ТЗ)?
--    Температура: -58..58   Давление: 500..900 мм рт.ст.
--    Направление ветра: 0..59 (больших делений угломера)
--    Скорость ветра: 0..15 м/с   Дальность сноса пуль: 0..150 м
select
	p.id,
	p.measurement_batch_id,
	mpt.name as param_type_name,
	p.measurement_value,
	case mpt.id
		when 2 then '-58..58'
		when 3 then '500..900'
		when 4 then '0..59'
		when 5 then '0..15'
		when 6 then '0..150'
		else 'без ограничения по ТЗ'
	end as expected_range
from measurement_input_params p
inner join measurement_parameter_types mpt
	on mpt.id = p.measurement_parameter_type_id
where
	   (mpt.id = 2 and (p.measurement_value < -58 or p.measurement_value > 58))
	or (mpt.id = 3 and (p.measurement_value < 500 or p.measurement_value > 900))
	or (mpt.id = 4 and (p.measurement_value < 0 or p.measurement_value > 59))
	or (mpt.id = 5 and (p.measurement_value < 0 or p.measurement_value > 15))
	or (mpt.id = 6 and (p.measurement_value < 0 or p.measurement_value > 150))
order by mpt.id, p.measurement_batch_id;


-- 5. Все ли единицы измерения корректны относительно параметров?

-- 5а. Единицы измерения без базовой единицы (разрыв в иерархии)
select
	u.id,
	u.name,
	u.base_unit_id
from units u
left join base_units bu
	on bu.id = u.base_unit_id
where bu.id is null;


-- 5б. Типы параметров без назначенной единицы измерения
select
	mpt.id,
	mpt.name,
	mpt.unit_id
from measurement_parameter_types mpt
left join units u
	on u.id = mpt.unit_id
where mpt.unit_id is null or u.id is null;

-- 5в. Единицы измерения, которые ни один тип параметра не использует
select u.id, u.name
from units u
where u.id not in (
	select unit_id from measurement_parameter_types where unit_id is not null
);

-- 5г. Смысловая ошибка: "Температура" сейчас ссылается на единицу
-- "Градус" (базовая единица "Градус" - та же, что в принципе должна
-- использоваться для углов), а не на температурную шкалу Цельсия.
select mpt.id, mpt.name, u.id as unit_id, u.name as unit_name, bu.name as base_unit_name
from measurement_parameter_types mpt
inner join units u on u.id = mpt.unit_id
inner join base_units bu on bu.id = u.base_unit_id
where mpt.id = 2;


-- ЧАСТЬ 2. ИСПРАВЛЕНИЯ

-- A. Справочники единиц измерения: устраняем разрывы и смысловые
--    ошибки.

-- A1. Новые базовые величины: отдельно "Угол", "Температура", "Скорость"
--     (сейчас "Градус" ошибочно одновременно используется для температуры)
insert into base_units (id, name) values (4, 'Угол');
insert into base_units (id, name) values (5, 'Температура');
insert into base_units (id, name) values (6, 'Скорость');

-- A2. Новые единицы измерения
insert into units (id, name, base_unit_id, convert_factor)
values (7, 'Градус Цельсия', 5, 1);
insert into units (id, name, base_unit_id, convert_factor)
values (8, 'Большое деление угломера', 4, 6);

-- A3. Линкуем уже существующие "висячие" единицы к базовым величинам
update units set base_unit_id = 3, convert_factor = 133
where id = 5; 

update units set base_unit_id = 6, convert_factor = 1
where id = 6; 

-- A4. Переназначаем типам параметров правильные единицы измерения
update measurement_parameter_types set unit_id = 7
where id = 2; 

update measurement_parameter_types set unit_id = 8
where id = 4; 

update measurement_parameter_types set unit_id = 4
where id = 6;



-- B1. Давление: значения 1010-1030 похожи на гектопаскали, а не на
--     мм рт.ст. Переводим гПа -> мм рт.ст. (1 гПа = 0.750062 мм рт.ст.)
update measurement_input_params
set measurement_value = round(measurement_value * 0.750062, 2)
where measurement_parameter_type_id = 3
	and measurement_value > 900;

-- B2. Направление ветра: значения 0-360 похожи на обычные градусы, а
--     не на большие деления угломера (0-59). Переводим градусы ->
--     деления угломера (1 деление = 6 градусов).
update measurement_input_params
set measurement_value = round(measurement_value / 6.0, 0)
where measurement_parameter_type_id = 4
	and measurement_value > 59;

-- C. Устраняем нарушение бизнес-правила "тип параметра допустим
--    только для своего оборудования": удаляем "Скорость ветра" у
--    пачек оборудования ВР (этот параметр закреплён только за ДМК).

delete from measurement_input_params
where measurement_parameter_type_id = 5
	and measurement_batch_id in (
		select id from measurement_batchs where measurment_equipment_id = 2
	);
