-- ИСПРАВЛЕННЫЙ СКРИПТ
-- Миграция 02: трёхуровневый справочник единиц измерения
-- Работает на основе скрипта с пары 
-- 2026-09-29

-- 1. Новый справочник базовых физических величин.

drop table if exists base_units;

create table base_units
(
	id integer,
	name character varying(50)
);


-- 2 . Заполняем базовые величины типовыми данными.

insert into base_units (id, name) values (1, 'Длина');
insert into base_units (id, name) values (2, 'Температура');
insert into base_units (id, name) values (3, 'Давление');
insert into base_units (id, name) values (4, 'Угол');
insert into base_units (id, name) values (5, 'Скорость');



-- 3 (DDL). Новый справочник единиц измерения.

drop table if exists units;

create table units
(
	id integer,
	base_unit_id integer,
	short_name character varying(20),
	full_name character varying(100)
);


-- 4 . Заполняем единицы измерения типовыми данными.
-- Направление ветра по техническому заданию измеряется в
-- больших делениях угломера, а не в градусах.

insert into units (id, base_unit_id, short_name, full_name)
values (1, 1, 'м', 'Метр');
insert into units (id, base_unit_id, short_name, full_name)
values (2, 2, '°C', 'Градус Цельсия');
insert into units (id, base_unit_id, short_name, full_name)
values (3, 3, 'мм рт. ст.', 'Миллиметр ртутного столба');
insert into units (id, base_unit_id, short_name, full_name)
values (4, 4, 'д.у.', 'Большое деление угломера');
insert into units (id, base_unit_id, short_name, full_name)
values (5, 5, 'м/с', 'Метр в секунду');


-- 5 (DDL). Новый справочник типов параметров.

drop table if exists param_types;

create table param_types
(
	id integer,
	name character varying(100),
	unit_id integer
);


-- 6. Заполняем типы параметров типовыми данными.

insert into param_types (id, name, unit_id) values (1, 'Высота', 1);
insert into param_types (id, name, unit_id) values (2, 'Температура', 2);
insert into param_types (id, name, unit_id) values (3, 'Давление', 3);
insert into param_types (id, name, unit_id) values (4, 'Направление ветра', 4);
insert into param_types (id, name, unit_id) values (5, 'Скорость ветра', 5);


-- 7. Расширяем measurment_input_params: добавляем ссылку
-- на тип параметра и единое поле значения.

alter table measurment_input_params add column param_type_id integer;
alter table measurment_input_params add column value numeric(8,2);


-- 8. Переносим данные из "широкого" формата (одна строка
-- пачки = пять колонок) в "длинный" (одна строка = одно
-- значение одного параметра). У старых строк param_type_id ещё
-- не заполнен - это признак "старая строка, требует переноса".

update measurment_input_params
set param_type_id = 1, value = height
where param_type_id is null;

insert into measurment_input_params (id, measurment_bath_id, param_type_id, value)
select id + 10000, measurment_bath_id, 2, temperature
from measurment_input_params
where param_type_id = 1;

insert into measurment_input_params (id, measurment_bath_id, param_type_id, value)
select id + 20000, measurment_bath_id, 3, pressure
from measurment_input_params
where param_type_id = 1;

insert into measurment_input_params (id, measurment_bath_id, param_type_id, value)
select id + 30000, measurment_bath_id, 4, wind_direction
from measurment_input_params
where param_type_id = 1;

insert into measurment_input_params (id, measurment_bath_id, param_type_id, value)
select id + 40000, measurment_bath_id, 5, wind_speed
from measurment_input_params
where param_type_id = 1;

-- 9 . Удаляем старые ненужные колонки.

alter table measurment_input_params drop column height;
alter table measurment_input_params drop column temperature;
alter table measurment_input_params drop column pressure;
alter table measurment_input_params drop column wind_direction;
alter table measurment_input_params drop column wind_speed;

-- Итоговый запрос.
-- Дата измерения | Номер пачки | ФИО сотрудника |
-- Наименование параметра и ед. измерения | Значение

select
	measurment_baths.started                              as "Дата измерения",
	measurment_baths.id                                   as "Номер пачки",
	employees.name                                        as "ФИО сотрудника",
	param_types.name || ', ' || units.short_name          as "Параметр (ед. измерения)",
	measurment_input_params.value                         as "Значение"
from measurment_baths
inner join employees
	on employees.id = measurment_baths.emploee_id
inner join measurment_input_params
	on measurment_input_params.measurment_bath_id = measurment_baths.id
inner join param_types
	on param_types.id = measurment_input_params.param_type_id
inner join units
	on units.id = param_types.unit_id
order by
	measurment_baths.started,
	measurment_baths.id,
	param_types.id;
