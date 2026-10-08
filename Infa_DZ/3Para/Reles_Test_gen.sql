
-- Аудит качества тестовых данных (сгенерированых).

-- 2026-10-04 / 2026-10-06


-- ЧАСТЬ 1. ДИАГНОСТИКА (только select, ничего не меняет)

-- 1. Каждый пользователь имеет одинаковое количество измерений?

select
	e.id                     as employee_id,
	e.name                   as employee_name,
	count(p.id)              as measurements_count
from employees e
left join measurement_batchs b
	on b.employee_id = e.id
left join measurement_input_params p
	on p.measurement_batch_id = b.id
group by e.id, e.name
order by e.id;



-- 2. Есть ли пустые пачки измерений (без единого параметра)?

select
	b.id              as batch_id,
	count(p.id)       as params_count
from measurement_batchs b
left join measurement_input_params p
	on p.measurement_batch_id = b.id
group by b.id
having count(p.id) = 0;


-- 2б. Отдельная проверка: нет ли дублирующихся записей одного и
--     того же типа параметра внутри одной пачки
select
	measurement_batch_id,
	measurement_parameter_type_id,
	count(*) as cnt
from measurement_input_params
group by measurement_batch_id, measurement_parameter_type_id
having count(*) > 1;



-- 3. Содержит ли каждая пачка полный набор параметров для своего оборудования? 

-- 3а. Пачки, где количество фактических параметров не совпадает
--     с ожидаемым количеством для оборудования этой пачки.
select
	b.id              as batch_id,
	count(mpt.id)     as expected_cnt,
	count(p.id)       as actual_cnt
from measurement_batchs b
inner join measurement_parameter_types mpt
	on mpt.measurement_equipment_id is null
	or mpt.measurement_equipment_id = b.measurment_equipment_id
left join measurement_input_params p
	on p.measurement_batch_id = b.id
	and p.measurement_parameter_type_id = mpt.id
group by b.id
having count(mpt.id) <> count(p.id)
order by b.id;

-- 3б. Пачки, где есть параметр, не предназначенный для их
--     оборудования (например, "Скорость ветра" у пачки с ВР).
select
	b.id                              as batch_id,
	p.measurement_parameter_type_id,
	count(*)                         as cnt
from measurement_batchs b
inner join measurement_input_params p
	on p.measurement_batch_id = b.id
inner join measurement_parameter_types mpt
	on mpt.id = p.measurement_parameter_type_id
group by b.id, p.measurement_parameter_type_id,
	b.measurment_equipment_id, mpt.measurement_equipment_id
having mpt.measurement_equipment_id is not null
	and mpt.measurement_equipment_id <> b.measurment_equipment_id
order by b.id;


-- 4. Все ли значения в допустимом диапазоне (границы по ТЗ)?

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

select
	mpt.id            as param_type_id,
	mpt.name          as param_type_name,
	bu.id             as base_unit_id,
	bu.name           as base_unit_name,
	case mpt.id
		when 1 then 1   
		when 2 then 5   
		when 3 then 3   
		when 4 then 4   
		when 5 then 6   
		when 6 then 1   
		else null
	end as expected_base_unit_id
from measurement_parameter_types mpt
left join units u
	on u.id = mpt.unit_id
left join base_units bu
	on bu.id = u.base_unit_id
where
	   mpt.unit_id is null                              
	or u.id is null                                      
	or bu.id is null                                     
	or (mpt.id = 1 and bu.id <> 1)
	or (mpt.id = 2 and bu.id <> 5)
	or (mpt.id = 3 and bu.id <> 3)
	or (mpt.id = 4 and bu.id <> 4)
	or (mpt.id = 5 and bu.id <> 6)
	or (mpt.id = 6 and bu.id <> 1)
order by mpt.id;


-- ЧАСТЬ 2. ИСПРАВЛЕНИЯ

-- A. Справочники единиц измерения: устраняем разрывы и смысловые

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


-- B. Конвертация значений, сгенерированных в "чужой" шкале.


-- B1. Давление: Переводим гПа -> мм рт.ст. (1 гПа = 0.750062 мм рт.ст.)
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
--    только для своего оборудования": 

delete from measurement_input_params
where measurement_parameter_type_id = 5
	and measurement_batch_id in (
		select id from measurement_batchs where measurment_equipment_id = 2
	);
