-- Домашняя работа от 2026-11-09. Доработка структуры справочников (Таблица 2, Таблица 3)
--
-- Запускать после учебного скрипта 20261102.sql (он берется как есть, без изменений).


do $$
declare
	var_expected integer;
	var_actual integer;
begin

	-- Новые таблицы
	begin

		-- Заголовки таблиц
		create sequence if not exists calc_correction_headers_seq;
		create table if not exists calc_correction_headers
		(
			id integer not null primary key default nextval('public.calc_correction_headers_seq'),
			description text not null,
			constraint uq_calc_correction_headers_description unique (description)
		);

		comment on table calc_correction_headers is 'Заголовки таблиц корректировок';
		comment on column calc_correction_headers.id is 'Уникальный код';
		comment on column calc_correction_headers.description is 'Описание заголовка';

		-- Значения столбцов заголовка
		create sequence if not exists calc_correction_header_values_seq;
		create table if not exists calc_correction_header_values
		(
			id integer not null primary key default nextval('public.calc_correction_header_values_seq'),
			header_id integer not null,
			value integer not null,
			constraint fk_calc_correction_header_values_header foreign key (header_id) references calc_correction_headers (id),
			constraint uq_calc_correction_header_values unique (header_id, value)
		);

		comment on table calc_correction_header_values is 'Значения столбцов заголовка';
		comment on column calc_correction_header_values.id is 'Уникальный код';
		comment on column calc_correction_header_values.header_id is 'Код заголовка';
		comment on column calc_correction_header_values.value is 'Значение столбца';

		-- Значения таблиц корректировок
		create sequence if not exists calc_correction_values_seq;
		create table if not exists calc_correction_values
		(
			id integer not null primary key default nextval('public.calc_correction_values_seq'),
			correction_id integer not null,
			header_value_id integer not null,
			value integer not null,
			constraint fk_calc_correction_values_correction foreign key (correction_id) references calc_correction (id),
			constraint fk_calc_correction_values_header_value foreign key (header_value_id) references calc_correction_header_values (id),
			constraint uq_calc_correction_values unique (correction_id, header_value_id)
		);

		comment on table calc_correction_values is 'Значения корректировок (строка таблицы -> столбец заголовка)';
		comment on column calc_correction_values.id is 'Уникальный код';
		comment on column calc_correction_values.correction_id is 'Код строки таблицы корректировок (высота + тип)';
		comment on column calc_correction_values.header_value_id is 'Код значения столбца заголовка';
		comment on column calc_correction_values.value is 'Значение корректировки';

		alter table calc_correction_types add column if not exists header_id integer;
		comment on column calc_correction_types.header_id is 'Код заголовка таблицы';

	end;

	-- Дальше работаем, пока значения еще лежат в массивах
	if exists (select 1 from information_schema.columns
	           where table_schema = 'public' and table_name = 'calc_correction' and column_name = 'row_values') then

		-- Исправляем данные
		begin

			-- Отрицательные значения Таблицы 2 записаны под типом положительных
			update calc_correction
			set type_id = (select id from calc_correction_types where description = 'Таблица 2, Отрицательные температуры')
			where type_id = (select id from calc_correction_types where description = 'Таблица 2, Положительные температуры')
			  and row_values[1] < 0;

			-- Положительные значения Таблицы 2 записаны под типом направления ветра (ДМК)
			update calc_correction
			set type_id = (select id from calc_correction_types where description = 'Таблица 2, Положительные температуры')
			where type_id = (select id from calc_correction_types where description = 'Таблица 3, Направление среднего ветра (ДМК)')
			  and cardinality(row_values) > 1;

			-- Таблица 2, 400 м, столбец 40: -39 -> -38
			update calc_correction c
			set row_values[13] = -38
			from calc_correction_heights h, calc_correction_types t
			where h.id = c.height_id and t.id = c.type_id
			  and h.height = 400 and t.description = 'Таблица 2, Отрицательные температуры' and c.row_values[13] = -39;

			-- Таблица 3 (ДМК), 1200 м, скорость 11: 23 -> 22
			update calc_correction c
			set row_values[9] = 22
			from calc_correction_heights h, calc_correction_types t
			where h.id = c.height_id and t.id = c.type_id
			  and h.height = 1200 and t.description = 'Таблица 3, Скорость среднего ветра (ДМК)' and c.row_values[9] = 23;

			-- Таблица 1 по ТЗ (23 -> 1.8, +3 -> 0.3)
			insert into calc_correction_temperature (temperature, correction)
			values (0, 0), (5, 0.5), (10, 1), (15, 1), (20, 1.5), (25, 2), (30, 3.5), (40, 4.5)
			on conflict (temperature) do update set correction = excluded.correction;

		end;

		-- Добавляем отсутствующие данные
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

		-- Заголовки (у положительных температур нет столбцов 40 и 50)
		begin

			insert into calc_correction_headers(description)
			values
				('Таблица 2, положительные температуры: отклонение, град'),
				('Таблица 2, отрицательные температуры: отклонение, град'),
				('Таблица 3 (ВР): дальность сноса ветровых пуль, м'),
				('Таблица 3 (ДМК): скорость приземного ветра, м/с'),
				('Одно значение без столбцов')
			on conflict (description) do nothing;

			insert into calc_correction_header_values(header_id, value)
			select h.id, v.value
			from calc_correction_headers h
			join (values
				('Таблица 2, положительные температуры: отклонение, град', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]),
				('Таблица 2, отрицательные температуры: отклонение, град', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
				('Таблица 3 (ВР): дальность сноса ветровых пуль, м', array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]),
				('Таблица 3 (ДМК): скорость приземного ветра, м/с', array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
				('Одно значение без столбцов', array[0])
			) m(description, header_values) on m.description = h.description
			cross join lateral unnest(m.header_values) as v(value)
			on conflict (header_id, value) do nothing;

			update calc_correction_types t
			set header_id = h.id
			from (values
				('Таблица 2, Положительные температуры', 'Таблица 2, положительные температуры: отклонение, град'),
				('Таблица 2, Отрицательные температуры', 'Таблица 2, отрицательные температуры: отклонение, град'),
				('Таблица 3, Скорость среднего ветра (ВР)', 'Таблица 3 (ВР): дальность сноса ветровых пуль, м'),
				('Таблица 3, Направление среднего ветра (ВР)', 'Одно значение без столбцов'),
				('Таблица 3, Скорость среднего ветра (ДМК)', 'Таблица 3 (ДМК): скорость приземного ветра, м/с'),
				('Таблица 3, Направление среднего ветра (ДМК)', 'Одно значение без столбцов')
			) m(type_description, header_description)
			join calc_correction_headers h on h.description = m.header_description
			where t.description = m.type_description;

		end;

		-- Переносим массивы в строки: позиция в массиве = позиция значения в заголовке
		begin

			select sum(cardinality(row_values)) into var_expected from calc_correction;

			insert into calc_correction_values(correction_id, header_value_id, value)
			select c.id, hv.id, v.value
			from calc_correction c
			join calc_correction_types t on t.id = c.type_id
			cross join lateral unnest(c.row_values) with ordinality as v(value, position)
			join (
				select id, header_id, row_number() over (partition by header_id order by value) as position
				from calc_correction_header_values
			) hv on hv.header_id = t.header_id and hv.position = v.position;

			select count(*) into var_actual from calc_correction_values;

			if var_expected <> var_actual then
				raise exception 'Перенос значений: ожидалось %, перенесено %', var_expected, var_actual;
			end if;

			alter table calc_correction drop column row_values;
			alter table calc_correction_types drop column header_values;

		end;

	end if;

	-- Связи и ограничения
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

	-- Проверка: 9 высот x 6 типов, у каждой строки значения на все столбцы своего заголовка
	if (select count(*) from calc_correction) <> 54 then
		raise exception 'Ожидалось 54 строки таблиц корректировок, получено %', (select count(*) from calc_correction);
	end if;

	if exists (
		select 1
		from calc_correction c
		join calc_correction_types t on t.id = c.type_id
		where (select count(*) from calc_correction_values v where v.correction_id = c.id)
		   <> (select count(*) from calc_correction_header_values hv where hv.header_id = t.header_id)
	) then
		raise exception 'Количество значений не совпадает с количеством столбцов заголовка';
	end if;

	raise notice 'Проверка пройдена';

end $$;
