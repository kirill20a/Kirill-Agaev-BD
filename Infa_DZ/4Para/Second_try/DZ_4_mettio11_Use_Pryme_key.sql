--Исправления 13.10.2026 18:30
-- PL/pgSQL-скрипт: собственная структура таблиц "Допуски
-- сотрудников к работе с метеокомплексами"
-- проекта "Метео 11".



-- ТРАНЗАКЦИЯ 1. Структура таблиц + sequence для каждого id.

begin;

do $$
begin

	-- Справочник типов допусков
	begin
		execute 'create table public.qualification_types (
			id    integer,
			name  character varying(100)
		)';
	exception when duplicate_table then
		raise notice 'Таблица qualification_types уже существует - пропускаем (вложенная транзакция откатилась только для этой команды)';
	end;

	-- Сами допуски, выданные сотрудникам
	begin
		execute 'create table public.employee_qualifications (
			id                     integer,
			employee_id            integer,
			qualification_type_id  integer,
			issued_date            date,
			expiry_date            date
		)';
	exception when duplicate_table then
		raise notice 'Таблица employee_qualifications уже существует - пропускаем';
	end;

	-- Последовательности для каждой таблицы 
	begin
		execute 'create sequence public.seq_qualification_types';
	exception when duplicate_table then
		raise notice 'Sequence seq_qualification_types уже существует - пропускаем';
	end;

	begin
		execute 'create sequence public.seq_employee_qualifications';
	exception when duplicate_table then
		raise notice 'Sequence seq_employee_qualifications уже существует - пропускаем';
	end;

	execute 'alter table public.qualification_types alter column id set default nextval(''public.seq_qualification_types'')';
	execute 'alter table public.employee_qualifications alter column id set default nextval(''public.seq_employee_qualifications'')';

end $$;

commit;



-- ТРАНЗАКЦИЯ 2. Наполнение тестовыми данными.

begin;

do $$
declare
	rec record;
begin


	if not exists (select 1 from public.qualification_types) then
		insert into public.qualification_types (name) values
			('Допуск к работе с ДМК'),
			('Допуск к работе с ВР'),
			('Допуск к самостоятельной обработке данных');
	else
		raise notice 'Справочник qualification_types уже заполнен - пропускаем';
	end if;

	-- Каждому существующему сотруднику выдаём допуск "Допуск к
	-- работе с ДМК", а каждому второму - ещё и
	-- "Допуск к работе с ВР".
	for rec in select id from public.employees order by id loop

		begin
			insert into public.employee_qualifications
				(employee_id, qualification_type_id, issued_date, expiry_date)
			values
				(rec.id, 1, date '2026-01-10', date '2027-01-10');
		exception when unique_violation then
			raise notice 'Допуск ДМК у сотрудника % уже выдан - пропускаем', rec.id;
		end;

		if rec.id % 2 = 0 then
			begin
				insert into public.employee_qualifications
					(employee_id, qualification_type_id, issued_date, expiry_date)
				values
					(rec.id, 2, date '2026-02-15', date '2027-02-15');
			exception when unique_violation then
				raise notice 'Допуск ВР у сотрудника % уже выдан - пропускаем', rec.id;
			end;
		end if;

	end loop;

end $$;

commit;



-- ТРАНЗАКЦИЯ 3. Связи между таблицами и ограничения.

begin;

do $$
begin

	
	begin
		execute 'alter table public.qualification_types add constraint pk_qualification_types primary key (id)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'pk_qualification_types уже существует - пропускаем';
	end;

	begin
		execute 'alter table public.employee_qualifications add constraint pk_employee_qualifications primary key (id)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'pk_employee_qualifications уже существует - пропускаем';
	end;

	begin
		execute 'alter table public.employee_qualifications add constraint fk_eq_employee foreign key (employee_id) references public.employees (id)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'fk_eq_employee уже существует - пропускаем';
	end;

	begin
		execute 'alter table public.employee_qualifications add constraint fk_eq_qualification_type foreign key (qualification_type_id) references public.qualification_types (id)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'fk_eq_qualification_type уже существует - пропускаем';
	end;

	execute 'alter table public.qualification_types alter column name set not null';
	execute 'alter table public.employee_qualifications alter column employee_id set not null';
	execute 'alter table public.employee_qualifications alter column qualification_type_id set not null';
	execute 'alter table public.employee_qualifications alter column issued_date set not null';

	begin
		execute 'alter table public.employee_qualifications add constraint uq_eq_employee_qualification unique (employee_id, qualification_type_id)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'uq_eq_employee_qualification уже существует - пропускаем';
	end;

	begin
		execute 'alter table public.employee_qualifications add constraint chk_eq_expiry_after_issue check (expiry_date is null or expiry_date >= issued_date)';
	exception when duplicate_object or duplicate_table or invalid_table_definition then
		raise notice 'chk_eq_expiry_after_issue уже существует - пропускаем';
	end;

end $$;

commit;



-- Проверка

select * from public.qualification_types order by id;
select * from public.employee_qualifications order by id;

-- Часть 2



-- Отображение метаданных схемы проекта "Метео 11" 


select
	row_number() over (order by table_name)  as "№",
	table_name                               as "Наименование",
	case table_type
		when 'BASE TABLE' then 'Таблица'
		when 'VIEW'       then 'Представление'
		when 'FOREIGN'    then 'Внешняя таблица'
		else table_type
	end                                       as "Тип"
from information_schema.tables
where table_schema = 'public'
order by table_name;



--Часть 3 (В другом формате)


-- Часть 4



-- Добавление в исходный скрипт новой таблицы "Расчёт
-- температуры" (Таблица 1 из алгоритма расчёта).
--
-- Источник данных - Таблица 1 из AlgoritmDmk.md / AlgoritmBp.md /
-- TechnicalTask.md: таблица виртуальной поправки ΔTv, используемой
-- при расчёте приземной виртуальной температуры:
--   T0 = t0 + ΔTv
-- где t0 - измеренная температура, ΔTv - поправка, определяемая
-- по данной таблице в зависимости от значения t0.
--
-- Таблица 1 (как она дана в документации):
--   t0   | Ниже 0 | 0 - 5 | 10 - 15 | 20  | 25 | 30  | 40
--   ΔTv  |   0    |  0.5  |    1    | 1.5 |  2 | 3.5 | 4.5
--
-- "Ниже 0" и диапазоны "0-5"/"10-15" хранятся через t0_min/t0_max,
-- одиночные точки (20, 25, 30, 40) - когда t0_min = t0_max.
-- Для t0 "Ниже 0" нижняя граница не ограничена (t0_min = null).

create table public.temperature_correction
(
	id              integer,
	t0_description  character varying(20),
	t0_min          numeric(5,1),
	t0_max          numeric(5,1),
	delta_tv        numeric(4,2)
);

-- Последовательность для id
create sequence if not exists seq_temperature_correction;

select setval('seq_temperature_correction',
	(select coalesce(max(id), 0) + 1 from public.temperature_correction),
	false);

alter table public.temperature_correction alter column id set default
	nextval('seq_temperature_correction');

alter table public.temperature_correction
	add constraint pk_temperature_correction primary key (id);

-- Заполняем данными строго по Таблице 1
insert into public.temperature_correction (t0_description, t0_min, t0_max, delta_tv)
values
	('Ниже 0',  null, 0,    0.00),
	('0 - 5',   0,    5,    0.50),
	('10 - 15', 10,   15,   1.00),
	('20',      20,   20,   1.50),
	('25',      25,   25,   2.00),
	('30',      30,   30,   3.50),
	('40',      40,   40,   4.50);

-- Проверка
select * from public.temperature_correction order by id;





