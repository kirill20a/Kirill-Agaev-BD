
--Часть 1


-- PL/pgSQL-скрипт: собственная структура таблиц "Допуски
-- сотрудников к работе с метеокомплексами" 



-- ТРАНЗАКЦИЯ 1. Структура таблиц + sequence для каждого id.

begin;

-- Справочник типов допусков
create table public.qualification_types
(
	id    integer,
	name  character varying(100)
);

-- Сами допуски, выданные сотрудникам
create table public.employee_qualifications
(
	id                     integer,
	employee_id            integer,
	qualification_type_id  integer,
	issued_date            date,
	expiry_date            date
);

-- Последовательности - по той же схеме, что и для остальных
-- таблиц проекта (seq_no_drop.sql)
create sequence if not exists public.seq_qualification_types;
create sequence if not exists public.seq_employee_qualifications;

alter table public.qualification_types alter column id set default
	nextval('public.seq_qualification_types');
alter table public.employee_qualifications alter column id set default
	nextval('public.seq_employee_qualifications');

commit;


-- ТРАНЗАКЦИЯ 2. Наполнение тестовыми данными.
begin;

insert into public.qualification_types (name) values
	('Допуск к работе с ДМК'),
	('Допуск к работе с ВР'),
	('Допуск к самостоятельной обработке данных');

-- Каждому существующему сотруднику выдаём допуск "Допуск к
-- работе с ДМК" , а каждому второму - ещё и
-- "Допуск к работе с ВР" . Даты выдачи/окончания
-- рассчитываются от даты рождения сотрудника чисто для
-- разнообразия тестовых данных.
do $$
declare
	rec record;
begin
	for rec in select id from public.employees order by id loop
		insert into public.employee_qualifications
			(employee_id, qualification_type_id, issued_date, expiry_date)
		values
			(rec.id, 1, date '2026-01-10', date '2027-01-10');

		if rec.id % 2 = 0 then
			insert into public.employee_qualifications
				(employee_id, qualification_type_id, issued_date, expiry_date)
			values
				(rec.id, 2, date '2026-02-15', date '2027-02-15');
		end if;
	end loop;
end $$;

commit;


-- ТРАНЗАКЦИЯ 3. Связи между таблицами и ограничения.

-- Чтобы employee_qualifications.employee_id можно было связать
-- настоящим FOREIGN KEY с employees.id, на employees.id нужен
-- PRIMARY KEY либо UNIQUE (так требует сам Postgres для внешних
-- ключей).

begin;

-- Делаем employees.id пригодным для внешнего ключа
alter table public.employees
	add constraint uq_employees_id unique (id);

-- Первичные ключи новых таблиц 

alter table public.qualification_types
	add constraint pk_qualification_types primary key (id);

alter table public.employee_qualifications
	add constraint pk_employee_qualifications primary key (id);

-- Внешние ключи
alter table public.employee_qualifications
	add constraint fk_eq_employee
	foreign key (employee_id) references public.employees (id);

alter table public.employee_qualifications
	add constraint fk_eq_qualification_type
	foreign key (qualification_type_id) references public.qualification_types (id);

-- Обязательность полей
alter table public.qualification_types
	alter column name set not null;

alter table public.employee_qualifications
	alter column employee_id set not null;
alter table public.employee_qualifications
	alter column qualification_type_id set not null;
alter table public.employee_qualifications
	alter column issued_date set not null;

-- Один и тот же допуск одному сотруднику выдаётся только один раз
alter table public.employee_qualifications
	add constraint uq_eq_employee_qualification
	unique (employee_id, qualification_type_id);

-- Дата окончания действия допуска не может быть раньше выдачи
alter table public.employee_qualifications
	add constraint chk_eq_expiry_after_issue
	check (expiry_date is null or expiry_date >= issued_date);

commit;



-- Проверка

select * from public.qualification_types order by id;
select * from public.employee_qualifications order by id;


-- Часть 2



-- Отображение метаданных схемы проекта "Метео 11" через
-- information_schema.

 
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

-- Таблица 1 (как она дана в документации):
--   t0   | Ниже 0 | 0 - 5 | 10 - 15 | 20  | 25 | 30  | 40
--   ΔTv  |   0    |  0.5  |    1    | 1.5 |  2 | 3.5 | 4.5


create table public.temperature_correction
(
	id              integer,
	t0_description  character varying(20),
	t0_min          numeric(5,1),
	t0_max          numeric(5,1),
	delta_tv        numeric(4,2)
);

-- Последовательность для id, по той же схеме, что и для
-- остальных таблиц проекта
create sequence if not exists seq_temperature_correction;

select setval('seq_temperature_correction',
	(select coalesce(max(id), 0) + 1 from public.temperature_correction),
	false);

alter table public.temperature_correction alter column id set default
	nextval('seq_temperature_correction');

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

