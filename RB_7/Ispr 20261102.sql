-- Домашняя работа от 2026-11-02 (исправленная версия)

/*№	Проблема	Как исправлено

1	Отрицательные значения Таблицы 2 записаны с type_id = 8 («Положительные»), а положительные с type_id = 7,
то есть в тип «Направление среднего ветра (ДМК)»	типы ищутся по описанию, а не по номеру

2	Заголовок Таблицы 2: {0,1,...,8,8,10,...}, 15 значений вместо 14: лишний 0 и двойная 8 (должна быть 9)	{1..9,10,20,30,40,50}

3	Таблица 2, 400 м, столбец 40: в скрипте -39, в таблице ТЗ -38	исправлено

4	Таблица 3 (ДМК), 1200 м, V0=11: в скрипте 23, в таблице ТЗ 22	исправлено

5	Данные есть только для 4 высот из 9 (до 1200 м)	добавлены 1600, 2000, 2400, 3000, 4000

6	Положительные значения Таблицы 2 короче заголовка (12 вместо 14)	дополнены null 
на месте прочерков 40 и 50, позиция в массиве = позиция в заголовке

7	У типов «Направление» заголовок скопирован у скорости, но значение одно на высоту	заголовок убран (null)

8	Нет внешних ключей и уникальных ограничений: можно записать несуществующую высоту или тип, дубли строк	добавлены FK и unique

9	rename calc_temperature_correction падает при повторном запуске	выполняется только если старое имя ещё есть
*/

do $$
begin

	-- Чистим объекты этой миграции (повторный запуск)
	drop table if exists calc_correction;
	drop table if exists calc_correction_types;
	drop table if exists calc_correction_heights;
	drop sequence if exists calc_correction_seq;
	drop sequence if exists calc_correction_types_seq;
	drop sequence if exists calc_correction_height_seq;

	-- Создаем новые структуры
	begin

		-- Таблица стандартных высот
		create sequence calc_correction_height_seq;
		create table calc_correction_heights
		(
			id integer not null default nextval('public.calc_correction_height_seq'),
			height integer not null,
			constraint pk_calc_correction_heights primary key (id),
			constraint uq_calc_correction_heights_height unique (height),
			constraint ck_calc_correction_heights_height check (height > 0)
		);
		alter sequence calc_correction_height_seq owned by calc_correction_heights.id;

		insert into calc_correction_heights(height)
		values(200),(400),(800),(1200),(1600),(2000),(2400),(3000),(4000);

		comment on table calc_correction_heights is 'Таблица стандартных высот';
		comment on column calc_correction_heights.id is 'Уникальный код';
		comment on column calc_correction_heights.height is 'Высота';

		-- Справочник типов таблиц корректировок
		create sequence calc_correction_types_seq;
		create table calc_correction_types
		(
			id integer not null default nextval('public.calc_correction_types_seq'),
			parent_id integer,
			measurment_equipment_id integer,
			description text not null,
			header_values integer[],
			constraint pk_calc_correction_types primary key (id),
			constraint uq_calc_correction_types_description unique (description),
			constraint fk_calc_correction_types_parent foreign key (parent_id) references calc_correction_types (id),
			constraint fk_calc_correction_types_equipment foreign key (measurment_equipment_id) references measurment_equipment (id)
		);
		alter sequence calc_correction_types_seq owned by calc_correction_types.id;

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
			id integer not null default nextval('public.calc_correction_seq'),
			height_id integer not null,
			type_id integer not null,
			row_values integer[],
			constraint pk_calc_correction primary key (id),
			constraint uq_calc_correction_height_type unique (height_id, type_id),
			constraint fk_calc_correction_height foreign key (height_id) references calc_correction_heights (id),
			constraint fk_calc_correction_type foreign key (type_id) references calc_correction_types (id)
		);
		alter sequence calc_correction_seq owned by calc_correction.id;

		comment on table calc_correction is 'Универсальная таблица корректировок';
		comment on column calc_correction.id is 'Уникальный код';
		comment on column calc_correction.height_id is 'Код высоты';
		comment on column calc_correction.type_id is 'Код типа таблиц';
		comment on column calc_correction.row_values is 'Значения с корректировками (позиция значения = позиция в header_values типа)';

	end;

	-- Добавляем данные
	begin

		-- Корневые типы
		insert into calc_correction_types(description, header_values)
		values ('Таблица 2', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
		       ('Таблица 3, скорость среднего ветра', null),
		       ('Таблица 3, направление среднего ветра', null);

		-- Таблица 2: положительные / отрицательные температуры
		insert into calc_correction_types(description, parent_id)
		select v.description, t.id
		from (values ('Таблица 2, Положительные температуры'),
		             ('Таблица 2, Отрицательные температуры')) v(description)
		cross join calc_correction_types t
		where t.description = 'Таблица 2';

		-- Таблица 3: скорость и направление, по видам оборудования
		insert into calc_correction_types(description, parent_id, measurment_equipment_id, header_values)
		select v.description, p.id, e.id, v.header_values
		from (values
			('Таблица 3, Скорость среднего ветра (ВР)',      'Таблица 3, скорость среднего ветра',    'ВР',  array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]),
			('Таблица 3, Направление среднего ветра (ВР)',   'Таблица 3, направление среднего ветра', 'ВР',  null::integer[]),
			('Таблица 3, Скорость среднего ветра (ДМК)',     'Таблица 3, скорость среднего ветра',    'ДМК', array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
			('Таблица 3, Направление среднего ветра (ДМК)',  'Таблица 3, направление среднего ветра', 'ДМК', null::integer[])
		) v(description, parent_description, equipment, header_values)
		join calc_correction_types p on p.description = v.parent_description
		join measurment_equipment e on e.short_name = v.equipment;

		-- Значения. Тип таблицы и высота ищутся по описанию/значению, а не по номеру.
		insert into calc_correction(height_id, type_id, row_values)
		select h.id, t.id, v.row_values
		from (values
				('Таблица 2, Отрицательные температуры', 200, array[-1,-2,-3,-4,-5,-6,-7,-8,-8,-9,-20,-29,-39,-49]),
				('Таблица 2, Положительные температуры', 200, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 200, array[3,4,5,6,7,7,8,9,10,11,12,12]),
				('Таблица 3, Направление среднего ветра (ВР)', 200, array[0]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 200, array[4,6,8,9,10,12,14,15,16,18,20,21,22]),
				('Таблица 3, Направление среднего ветра (ДМК)', 200, array[1]),
				('Таблица 2, Отрицательные температуры', 400, array[-1,-2,-3,-4,-5,-6,-6,-7,-8,-9,-19,-29,-38,-48]),
				('Таблица 2, Положительные температуры', 400, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 400, array[4,5,6,7,8,9,10,11,12,13,14,15]),
				('Таблица 3, Направление среднего ветра (ВР)', 400, array[1]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 400, array[5,7,10,11,12,14,17,18,20,22,23,25,27]),
				('Таблица 3, Направление среднего ветра (ДМК)', 400, array[2]),
				('Таблица 2, Отрицательные температуры', 800, array[-1,-2,-3,-4,-5,-6,-6,-7,-7,-8,-18,-28,-37,-46]),
				('Таблица 2, Положительные температуры', 800, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 800, array[4,5,6,7,8,9,10,11,13,14,15,16]),
				('Таблица 3, Направление среднего ветра (ВР)', 800, array[2]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 800, array[5,8,10,11,13,15,18,19,21,23,25,27,28]),
				('Таблица 3, Направление среднего ветра (ДМК)', 800, array[3]),
				('Таблица 2, Отрицательные температуры', 1200, array[-1,-2,-3,-4,-4,-5,-5,-6,-7,-8,-17,-26,-35,-44]),
				('Таблица 2, Положительные температуры', 1200, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 1200, array[4,5,7,8,8,9,11,12,13,15,15,16]),
				('Таблица 3, Направление среднего ветра (ВР)', 1200, array[2]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 1200, array[5,8,11,12,13,16,19,20,22,24,26,28,30]),
				('Таблица 3, Направление среднего ветра (ДМК)', 1200, array[3]),
				('Таблица 2, Отрицательные температуры', 1600, array[-1,-2,-3,-4,-4,-4,-5,-6,-7,-7,-17,-25,-34,-42]),
				('Таблица 2, Положительные температуры', 1600, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 1600, array[4,6,7,8,9,10,11,13,14,15,17,17]),
				('Таблица 3, Направление среднего ветра (ВР)', 1600, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 1600, array[6,8,11,13,14,17,20,21,23,25,27,29,32]),
				('Таблица 3, Направление среднего ветра (ДМК)', 1600, array[4]),
				('Таблица 2, Отрицательные температуры', 2000, array[-1,-2,-3,-3,-4,-4,-5,-6,-6,-7,-16,-24,-32,-40]),
				('Таблица 2, Положительные температуры', 2000, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 2000, array[4,6,7,8,9,10,11,13,14,16,17,18]),
				('Таблица 3, Направление среднего ветра (ВР)', 2000, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 2000, array[6,9,11,13,14,17,20,21,24,26,28,30,32]),
				('Таблица 3, Направление среднего ветра (ДМК)', 2000, array[4]),
				('Таблица 2, Отрицательные температуры', 2400, array[-1,-2,-2,-3,-4,-4,-5,-5,-6,-7,-15,-23,-31,-38]),
				('Таблица 2, Положительные температуры', 2400, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 2400, array[4,6,8,9,9,10,12,14,15,16,18,19]),
				('Таблица 3, Направление среднего ветра (ВР)', 2400, array[3]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 2400, array[6,9,12,14,15,18,21,22,25,27,29,32,34]),
				('Таблица 3, Направление среднего ветра (ДМК)', 2400, array[4]),
				('Таблица 2, Отрицательные температуры', 3000, array[-1,-2,-2,-3,-4,-4,-4,-5,-5,-6,-15,-22,-30,-37]),
				('Таблица 2, Положительные температуры', 3000, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 3000, array[5,6,8,9,10,11,12,14,15,17,18,19]),
				('Таблица 3, Направление среднего ветра (ВР)', 3000, array[4]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 3000, array[6,9,12,14,15,18,21,23,25,28,30,32,36]),
				('Таблица 3, Направление среднего ветра (ДМК)', 3000, array[5]),
				('Таблица 2, Отрицательные температуры', 4000, array[-1,-2,-2,-3,-4,-4,-4,-4,-5,-6,-14,-20,-27,-34]),
				('Таблица 2, Положительные температуры', 4000, array[1,2,3,4,5,6,7,8,9,10,20,30,null,null]),
				('Таблица 3, Скорость среднего ветра (ВР)', 4000, array[5,6,8,9,10,11,12,14,16,18,19,20]),
				('Таблица 3, Направление среднего ветра (ВР)', 4000, array[4]),
				('Таблица 3, Скорость среднего ветра (ДМК)', 4000, array[6,10,12,14,16,19,22,24,26,29,32,34,36]),
				('Таблица 3, Направление среднего ветра (ДМК)', 4000, array[5])
		) v(type_description, height, row_values)
		join calc_correction_types t on t.description = v.type_description
		join calc_correction_heights h on h.height = v.height;

	end;

	-- Прочее
	begin
		-- Наименование подправлю (только если ещё не переименована)
		if to_regclass('public.calc_temperature_correction') is not null then
			alter table public.calc_temperature_correction rename to calc_correction_temperature;
			alter index if exists public.calc_temperature_correction_pkey rename to calc_correction_temperature_pkey;
		end if;

		CREATE OR REPLACE FUNCTION public.fn_calc_temperature_interpolation(
			par_temperature numeric)
		    RETURNS numeric
		    LANGUAGE 'plpgsql'
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

		-- (OWNER TO admin убран: роли admin нет, владельцем остаётся тот, кто запускает скрипт)

		COMMENT ON FUNCTION public.fn_calc_temperature_interpolation(numeric)
		    IS 'Функция для расчета интерполяции для метео приближенный';
	end;

	commit;

end $$;
