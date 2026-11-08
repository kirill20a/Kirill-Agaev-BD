-- Домашняя работа от 2026-11-08
-- Часть 0: очистка, часть 1: скрипт 20261102 (две правки), часть 2: корректировки
-- Нужен только 20261014.sql

-- ============================================================================
-- ЧАСТЬ 0
-- ============================================================================
do $$
begin
	drop table if exists calc_correction;
	drop table if exists calc_correction_types;
	drop table if exists calc_correction_headers;
	drop table if exists calc_correction_heights;
	drop sequence if exists calc_correction_seq;
	drop sequence if exists calc_correction_types_seq;
	drop sequence if exists calc_correction_header_seq;
	drop sequence if exists calc_correction_height_seq;
end $$;

do $$
begin
	-- Интерполяция нужна скрипту 20261102 (создается, если ее еще нет)
	begin
		create type interpolation_type as
		(
			x0 numeric(8,2),
			x1 numeric(8,2),
			y0 numeric(8,2),
			y1 numeric(8,2)
		);
	exception when duplicate_object then
		raise notice 'Тип interpolation_type уже существует';
	end;

	create or replace function fn_calc_interpolation(par_x numeric, par_interpolation interpolation_type)
	returns numeric
	language plpgsql
	as $BODY$
	begin
		if par_interpolation.x1 = par_interpolation.x0 then
			return par_interpolation.y0;
		end if;

		return round(par_interpolation.y0 + (par_x - par_interpolation.x0) * (par_interpolation.y1 - par_interpolation.y0) / (par_interpolation.x1 - par_interpolation.x0), 2);
	end;
	$BODY$;
end $$;

-- ============================================================================
-- ЧАСТЬ 1. 20261102.sql (убран OWNER TO admin, переименование с проверкой)
-- ============================================================================
-- Домашняя работа от 2026-11-02
do $$
begin

	-- Создаем новые структуры
	begin
		
		-- Таблица стандартных высот
		create sequence calc_correction_height_seq;
		create table calc_correction_heights
		(
		        id integer primary key not null default nextval('public.calc_correction_height_seq'),
		        height integer not null
		);
		
		
		insert into calc_correction_heights(height)
		values(200),(400),(800),(1200),(1600),(2000),(2400),(3000),(4000);
	
		comment on table calc_correction_heights is 'Таблица стандартных высот';
		comment on column calc_correction_heights.id is 'Уникальный код';
		comment on column calc_correction_heights.height is 'Высота';
	
		-- Справочник типов таблиц корректировок
		create sequence calc_correction_types_seq;
		create table calc_correction_types
		(
		        id integer not null primary key default nextval('public.calc_correction_types_seq'),
		        parent_id integer,
		        measurment_equipment_id integer,
		        description text not null,
		        header_values integer[]
		);
	
		comment on table calc_correction_types is 'Справочник типов таблиц с собственными заголовками';
		comment on column calc_correction_types.id is 'Уникальный код';
		comment on column calc_correction_types.parent_id is 'Уникальный код владельца - тип таблицы';
		comment on column calc_correction_types.measurment_equipment_id is 'Тип оборудования';
		comment on column calc_correction_types.description is 'Описание к таблице';
		comment on column calc_correction_types.header_values is 'Значения в заголовке таблице';

		-- Универсальная таблица корректировок
		create sequence calc_correction_seq;
		create table calc_correction
		(
		        id integer not null primary key default nextval('public.calc_correction_seq'),
		        height_id integer not null,
		        type_id integer not null,
		        row_values integer[]
		);

		comment on table calc_correction is 'Универсальная таблица корректировок';
		comment on column calc_correction.id is 'Уникальный код';
		comment on column calc_correction.height_id is 'Код высоты';
		comment on column calc_correction.type_id is 'Код типа таблиц';
		comment on column calc_correction.row_values is 'Значения с корректировками';

	end;	

	-- Добавляем данные
	begin

		
		insert into calc_correction_types(  description, header_values)
		values( 'Таблица 2', array[0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 10, 20, 30, 40, 50]),  -- 1
		( 'Таблица 3, скорость среднего ветра', null), -- 2
		( 'Таблица 3, направление среднего ветра', null);       -- 3

		insert into calc_correction_types( description, parent_id, measurment_equipment_id, header_values)
		values
		('Таблица 3, Скорость среднего ветра (ВР)', 2, 2, array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]), -- 4
		('Таблица 3, Направление среднего ветра (ВР)',3, 2, array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]), -- 5
		('Таблица 3, Скорость среднего ветра (ДМК)',2, 1, array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]), -- 6
		('Таблица 3, Направление среднего ветра (ДМК)',3, 1, array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]); -- 7
		
		insert into calc_correction_types( description, parent_id)
		values('Таблица 2, Положительные температуры', 1 ), -- 8
		('Таблица 2, Отрицательные температуры', 1 ) --9
		;

		
		insert into calc_correction(height_id, type_id, row_values )
		-- Таблица 2, отрицптельные значения
		values(1, 8, array[-1, -2, -3, -4, -5, -6, -7, -8, -8, -9, -20, -29, -39, -49]), -- 200
		(2, 8, array[-1, -2, -3, -4, -5, -6, -6, -7, -8, -9, -19, -29, -39, -48]), -- 400
		(3, 8, array[-1, -2, -3, -4, -5, -6, -6, -7, -7, -8, -18, -28, -37, -46]), -- 800
		(4, 8, array[-1, -2, -3, -4, -4, -5, -5, -6, -7, -8, -17, -26, -35, -44]), -- 1200
		-- Таблица 2, положитеьные значения
		(1, 7, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 200
		(2, 7, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 400
		(3, 7, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 800
		(4, 7, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1200
		-- Таблица 3, Скорость среднего ветра (ВР)
		(1, 4, array[3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 12]), -- 200
		(2, 4, array[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15]), -- 400
		(3, 4, array[4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15 ,16]), -- 800
		(4, 4, array[4, 5, 7, 8, 8, 9, 11, 12, 13, 15 ,15, 16]), -- 1200
		-- Таблица 3, Направление среднего ветра (ВР)
		(1, 5, array[0]), -- 200
		(2, 5, array[1]), -- 400
		(3, 5, array[2]), -- 800
		(4, 5, array[2]), -- 1200
		-- Таблица 3,Скорость среднего ветра (ДМК)
		(1, 6, array[4,6,8,9,10,12,14,15,16,18,20,21,22]), -- 200
		(2, 6, array[5,7,10,11,12,14,17,18,20,22,23,25,27]), -- 400
		(3, 6, array[5,8,10,11,13,15,18,19,21,23,25,27,28]), -- 800
		(4, 6, array[5,8,11,12,13,16,19,20,23,24,26,28,30]), -- 1200
		-- 'Таблица 3, Направление среднего ветра (ДМК)
		(1, 7, array[1]), -- 200
		(2, 7, array[2]), -- 400
		(3, 7, array[3]), -- 800
		(4, 7, array[3]) -- 1200
		;
		
	end;

	-- Прочее
	begin
		-- Наименование подправлю
		if to_regclass('public.calc_temperature_correction') is not null then
			alter table public.calc_temperature_correction rename to calc_correction_temperature;
		end if;
		
				
		CREATE OR REPLACE FUNCTION public.fn_calc_temperature_interpolation(
			par_temperature numeric)
		    RETURNS numeric
		    LANGUAGE 'plpgsql'
		    COST 100
		    VOLATILE PARALLEL UNSAFE
		AS $BODY$
				        declare 
				                var_interpolation interpolation_type;
				                var_result numeric(8,2) default 0;
				                var_min_temparure numeric(8,2) default 0;
				                var_max_temperature numeric(8,2) default 0;
				                var_denominator numeric(8,2) default 0;
				        begin
				
				                                raise notice 'Расчет интерполяции для температуры %', par_temperature;
				
				                -- Проверим, возможно температура совпадает со значением в справочнике
				                if exists (select 1 from public.calc_correction_temperature where temperature = par_temperature ) then
				                begin
				                        select correction 
				                        into  var_result 
				                        from  public.calc_correction_temperature
				                        where 
				                                temperature = par_temperature;
				                end;
				                else    
				                begin
				                        -- Получим диапазон в котором работают поправки
				                        select min(temperature), max(temperature) 
				                        into var_min_temparure, var_max_temperature
				                        from public.calc_correction_temperature;
				
				                        if par_temperature < var_min_temparure or   
				                           par_temperature > var_max_temperature then
				
				                                raise exception 'Некорректно передан параметр! Невозможно рассчитать поправку. Значение должно укладываться в диаппазон: %, %',
				                                        var_min_temparure, var_max_temperature;
				                        end if;   
				
				                        -- Получим граничные параметры
				
				                        select x0, y0, x1, y1 
				                                                 into var_interpolation.x0, var_interpolation.y0, var_interpolation.x1, var_interpolation.y1
				                        from
				                        (
				                                select t1.temperature as x0, t1.correction as y0
				                                from public.calc_correction_temperature as t1
				                                where t1.temperature <= par_temperature
				                                order by t1.temperature desc
				                                limit 1
				                        ) as leftPart
				                        cross join
				                        (
				                                select t1.temperature as x1, t1.correction as y1
				                                from public.calc_correction_temperature as t1
				                                where t1.temperature >= par_temperature
				                                order by t1.temperature 
				                                limit 1
				                        ) as rightPart;
				
				                        raise notice 'Граничные значения %', var_interpolation;
				                        var_result :=  fn_calc_interpolation( par_temperature,  var_interpolation);
				                                                 
				                end;
				                end if;
				
				                                return var_result;
				
				end;
				
		$BODY$;
		
		-- (ALTER FUNCTION ... OWNER TO admin убрано: роли admin нет, из-за неё падал весь блок)
		
		COMMENT ON FUNCTION public.fn_calc_temperature_interpolation(numeric)
		    IS 'Функция для расчета интерполяции для метео приближенный';
	end;


	
end $$;

-- ============================================================================
-- ЧАСТЬ 2. Корректировки
-- ============================================================================
do $$
declare
	var_bad integer;
begin

	-- 2.1 Исправление данных
	begin

		-- Таблица 2: отрицательные значения лежат под типом положительных
		update calc_correction c
		set type_id = (select id from calc_correction_types where description = 'Таблица 2, Отрицательные температуры')
		where c.type_id = (select id from calc_correction_types where description = 'Таблица 2, Положительные температуры')
		  and c.row_values[1] < 0;

		-- Таблица 2: положительные значения лежат под типом направления ДМК
		update calc_correction c
		set type_id = (select id from calc_correction_types where description = 'Таблица 2, Положительные температуры')
		where c.type_id = (select id from calc_correction_types where description = 'Таблица 3, Направление среднего ветра (ДМК)')
		  and cardinality(c.row_values) > 1;

		-- Опечатка: Таблица 2, 400 м, столбец 40: было -39, по таблице ТЗ -38 (13-й элемент)
		update calc_correction c
		set row_values[13] = -38
		from calc_correction_heights h, calc_correction_types t
		where h.id = c.height_id and t.id = c.type_id
		  and h.height = 400
		  and t.description = 'Таблица 2, Отрицательные температуры'
		  and c.row_values[13] = -39;

		-- Опечатка: Таблица 3 (ДМК), 1200 м, V0 = 11: было 23, по таблице ТЗ 22 (9-й элемент)
		update calc_correction c
		set row_values[9] = 22
		from calc_correction_heights h, calc_correction_types t
		where h.id = c.height_id and t.id = c.type_id
		  and h.height = 1200
		  and t.description = 'Таблица 3, Скорость среднего ветра (ДМК)'
		  and c.row_values[9] = 23;

		-- Таблица 1 по ТЗ (23 -> 1.8, +3 -> 0.3)
		insert into calc_correction_temperature (temperature, correction)
		values (0, 0), (5, 0.5), (10, 1), (15, 1), (20, 1.5), (25, 2), (30, 3.5), (40, 4.5)
		on conflict (temperature) do update set correction = excluded.correction;

	end;

	-- 2.2 Добавление отсутствующих данных: высоты 1600, 2000, 2400, 3000, 4000
	begin

		insert into calc_correction(height_id, type_id, row_values)
		select h.id, t.id, v.row_values
		from (values
				('Таблица 2, Отрицательные температуры', 1600, array[-1,-2,-3,-4,-4,-4,-5,-6,-7,-7,-17,-25,-34,-42]),
				('Таблица 2, Положительные температуры', 1600, array[1,2,3,4,5,6,7,8,9,10,20,30]),
				('Таблица 3, Скорость среднего ветра (ВР)', 1600, array[4,6,7,8,9,10,11,13,14,15,17,17]),
				('Таблица 3, Направление среднего ветра (ВР)', 1600, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 1600, array[6,8,11,13,14,17,20,21,23,25,27,29,32]),
				('Таблица 3, Направление среднего ветра (ДМК)', 1600, array[4]),
				('Таблица 2, Отрицательные температуры', 2000, array[-1,-2,-3,-3,-4,-4,-5,-6,-6,-7,-16,-24,-32,-40]),
				('Таблица 2, Положительные температуры', 2000, array[1,2,3,4,5,6,7,8,9,10,20,30]),
				('Таблица 3, Скорость среднего ветра (ВР)', 2000, array[4,6,7,8,9,10,11,13,14,16,17,18]),
				('Таблица 3, Направление среднего ветра (ВР)', 2000, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 2000, array[6,9,11,13,14,17,20,21,24,26,28,30,32]),
				('Таблица 3, Направление среднего ветра (ДМК)', 2000, array[4]),
				('Таблица 2, Отрицательные температуры', 2400, array[-1,-2,-2,-3,-4,-4,-5,-5,-6,-7,-15,-23,-31,-38]),
				('Таблица 2, Положительные температуры', 2400, array[1,2,3,4,5,6,7,8,9,10,20,30]),
				('Таблица 3, Скорость среднего ветра (ВР)', 2400, array[4,6,8,9,9,10,12,14,15,16,18,19]),
				('Таблица 3, Направление среднего ветра (ВР)', 2400, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 2400, array[6,9,12,14,15,18,21,22,25,27,29,32,34]),
				('Таблица 3, Направление среднего ветра (ДМК)', 2400, array[4]),
				('Таблица 2, Отрицательные температуры', 3000, array[-1,-2,-2,-3,-4,-4,-4,-5,-5,-6,-15,-22,-30,-37]),
				('Таблица 2, Положительные температуры', 3000, array[1,2,3,4,5,6,7,8,9,10,20,30]),
				('Таблица 3, Скорость среднего ветра (ВР)', 3000, array[5,6,8,9,10,11,12,14,15,17,18,19]),
				('Таблица 3, Направление среднего ветра (ВР)', 3000, array[4]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 3000, array[6,9,12,14,15,18,21,23,25,28,30,32,36]),
				('Таблица 3, Направление среднего ветра (ДМК)', 3000, array[5]),
				('Таблица 2, Отрицательные температуры', 4000, array[-1,-2,-2,-3,-4,-4,-4,-4,-5,-6,-14,-20,-27,-34]),
				('Таблица 2, Положительные температуры', 4000, array[1,2,3,4,5,6,7,8,9,10,20,30]),
				('Таблица 3, Скорость среднего ветра (ВР)', 4000, array[5,6,8,9,10,11,12,14,16,18,19,20]),
				('Таблица 3, Направление среднего ветра (ВР)', 4000, array[4]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 4000, array[6,10,12,14,16,19,22,24,26,29,32,34,36]),
				('Таблица 3, Направление среднего ветра (ДМК)', 4000, array[5])
		) v(type_description, height, row_values)
		join calc_correction_types t on t.description = v.type_description
		join calc_correction_heights h on h.height = v.height
		where not exists (select 1 from calc_correction x where x.height_id = h.id and x.type_id = t.id);

	end;

	-- 2.3 Отдельная таблица для хранения заголовков
	begin

		begin
			create sequence calc_correction_header_seq;
		exception when duplicate_table then
			raise notice 'Последовательность calc_correction_header_seq уже существует';
		end;

		create table if not exists calc_correction_headers
		(
			id integer not null default nextval('public.calc_correction_header_seq'),
			description text not null,
			header_values integer[] not null,
			constraint pk_calc_correction_headers primary key (id),
			constraint uq_calc_correction_headers_description unique (description)
		);

		comment on table calc_correction_headers is 'Заголовки таблиц корректировок (значения входов по столбцам)';
		comment on column calc_correction_headers.id is 'Уникальный код';
		comment on column calc_correction_headers.description is 'Описание заголовка';
		comment on column calc_correction_headers.header_values is 'Значения столбцов; позиция значения = позиция в calc_correction.row_values';

		-- У положительных температур в таблице нет столбцов 40 и 50
		insert into calc_correction_headers(description, header_values)
		values
			('Таблица 2, положительные температуры: отклонение, град', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]),
			('Таблица 2, отрицательные температуры: отклонение, град', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
			('Таблица 3 (ВР): дальность сноса ветровых пуль, м',        array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]),
			('Таблица 3 (ДМК): скорость приземного ветра, м/с',          array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
		on conflict (description) do nothing;

	end;

	-- 2.4 Справочник типов таблиц: ссылка на заголовок вместо массива
	begin

		alter table calc_correction_types add column if not exists header_id integer;

		update calc_correction_types t
		set header_id = h.id
		from (values
			('Таблица 2, Положительные температуры',          'Таблица 2, положительные температуры: отклонение, град'),
			('Таблица 2, Отрицательные температуры',          'Таблица 2, отрицательные температуры: отклонение, град'),
			('Таблица 3, Скорость среднего ветра (ВР)',       'Таблица 3 (ВР): дальность сноса ветровых пуль, м'),
			('Таблица 3, Скорость среднего ветра (ДМК)',      'Таблица 3 (ДМК): скорость приземного ветра, м/с')
		) m(type_description, header_description)
		join calc_correction_headers h on h.description = m.header_description
		where t.description = m.type_description;

		alter table calc_correction_types drop column if exists header_values;

		comment on column calc_correction_types.header_id is 'Код заголовка таблицы (calc_correction_headers). Пусто у корневых типов и у направления ветра - там нет столбцов';

	end;

	-- 2.5 Связи и ограничения
	begin

		begin
			alter table calc_correction_heights add constraint uq_calc_correction_heights_height unique (height);
		exception when duplicate_object or duplicate_table then null; end;

		begin
			alter table calc_correction_types add constraint uq_calc_correction_types_description unique (description);
		exception when duplicate_object or duplicate_table then null; end;

		begin
			alter table calc_correction_types add constraint fk_calc_correction_types_parent
				foreign key (parent_id) references calc_correction_types (id);
		exception when duplicate_object then null; end;

		begin
			alter table calc_correction_types add constraint fk_calc_correction_types_equipment
				foreign key (measurment_equipment_id) references measurment_equipment (id);
		exception when duplicate_object then null; end;

		begin
			alter table calc_correction_types add constraint fk_calc_correction_types_header
				foreign key (header_id) references calc_correction_headers (id);
		exception when duplicate_object then null; end;

		begin
			alter table calc_correction add constraint fk_calc_correction_height
				foreign key (height_id) references calc_correction_heights (id);
		exception when duplicate_object then null; end;

		begin
			alter table calc_correction add constraint fk_calc_correction_type
				foreign key (type_id) references calc_correction_types (id);
		exception when duplicate_object then null; end;

		begin
			alter table calc_correction add constraint uq_calc_correction_height_type unique (height_id, type_id);
		exception when duplicate_object or duplicate_table then null; end;

	end;

	-- 2.6 Самопроверка данных
	begin

		if (select count(*) from calc_correction) <> 54 then
			raise exception 'Ожидалось 54 строки значений (9 высот x 6 типов), получено %', (select count(*) from calc_correction);
		end if;

		-- Длина значений = длина заголовка
		select count(*) into var_bad
		from calc_correction c
		join calc_correction_types t on t.id = c.type_id
		join calc_correction_headers h on h.id = t.header_id
		where cardinality(c.row_values) <> cardinality(h.header_values);

		if var_bad > 0 then
			raise exception 'Длина значений не совпадает с заголовком в % строках', var_bad;
		end if;

		raise notice 'Проверка пройдена';

	end;



end $$;
