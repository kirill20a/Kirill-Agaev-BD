-- Миграция 02: трёхуровневый справочник единиц измерения
-- Работает на основе скрипта с пары 
-- 2026-09-26


-- 1. Новый справочник базовых физических величин.


drop table if exists base_units;

create table base_units
(
	id integer,
	name character varying(50)
);


--2. Заполняем базовые величины типовыми данными.


insert into base_units (id, name) values (1, 'Длина');
insert into base_units (id, name) values (2, 'Температура');
insert into base_units (id, name) values (3, 'Давление');
insert into base_units (id, name) values (4, 'Угол');
insert into base_units (id, name) values (5, 'Скорость');



-- 3. Новый справочник единиц измерения 

drop table if exists units;

create table units
(
	id integer,
	base_unit_id integer,
	short_name character varying(20),
	full_name character varying(100)
);


--4. Переносим данные из measurment_units в units,


insert into units (id, base_unit_id, short_name, full_name)
select id, id, short_name, description
from measurment_units;

update units
set short_name = 'д.у.', full_name = 'Большое деление угломера'
where id = 4;



--5. Привязываем param_types к новому справочнику


alter table param_types add column unit_id integer;
alter table param_types add column name character varying(100);

--6. Переносим данные в новые колонки param_types.


update param_types
set unit_id = measurment_unit_id,
    name = description;



--7. Удаляем старые ненужные колонку и таблицу.


alter table param_types drop column measurment_unit_id;
alter table param_types drop column description;

drop table measurment_units;



-- Итоговый запрос.


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