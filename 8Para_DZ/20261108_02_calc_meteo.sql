-- Расчет МЕТЕО-11 (ДМК / ВР). Выполнять после 20261108_01_migration.sql
-- Процедура не может вернуть набор строк, поэтому функция с returns table

do $$
begin

	-- Тип "входящие параметры"
	begin
		create type meteo_input_params as
		(
			station_height integer,   -- высота метеопоста, м
			temperature numeric(8,2), -- температура, град C (-58..58)
			pressure integer,         -- давление, мм рт. ст. (500..900)
			wind_direction integer,   -- направление ветра, большие деления угломера (0..59)
			wind_speed integer,       -- скорость ветра, м/с (0..15), только ДМК
			bullet_drift integer      -- дальность сноса пуль, м (0..150), только ВР
		);
	exception when duplicate_object then
		raise notice 'Тип meteo_input_params уже существует';
	end;

	comment on type meteo_input_params is 'Входящие параметры расчета МЕТЕО-11';

	-- Таблица 1
	create or replace function fn_calc_delta_tv(par_temperature numeric)
	returns numeric
	language plpgsql
	as $BODY$
	declare
		var_interpolation interpolation_type;
	begin
		if par_temperature < 0 then
			return 0;
		end if;

		select max(temperature) into var_interpolation.x0 from calc_correction_temperature where temperature <= par_temperature;
		select min(temperature) into var_interpolation.x1 from calc_correction_temperature where temperature >= par_temperature;

		if var_interpolation.x1 is null then
			select correction into var_interpolation.y0 from calc_correction_temperature
			where temperature = var_interpolation.x0;
			return var_interpolation.y0;
		end if;

		select correction into var_interpolation.y0 from calc_correction_temperature where temperature = var_interpolation.x0;
		select correction into var_interpolation.y1 from calc_correction_temperature where temperature = var_interpolation.x1;

		return fn_calc_interpolation(par_temperature, var_interpolation);
	end;
	$BODY$;

	-- Отклонение приземной виртуальной температуры
	create or replace function fn_calc_delta_t0(par_temperature numeric)
	returns integer
	language plpgsql
	as $BODY$
	begin
		-- T0 = t0 + dTv; dT0 = T0 - 15.9, округление до целого
		return round(par_temperature + fn_calc_delta_tv(par_temperature) - 15.9)::integer;
	end;
	$BODY$;

	-- Значение из таблицы корректировок
	-- Нет точного столбца в заголовке - интерполяция между соседними
	create or replace function fn_calc_correction_value(par_type_id integer, par_height_id integer, par_x numeric)
	returns numeric
	language plpgsql
	as $BODY$
	declare
		var_header integer[];
		var_values integer[];
		var_i integer;
		var_interpolation interpolation_type;
	begin
		select h.header_values, c.row_values
		into var_header, var_values
		from calc_correction c
		join calc_correction_types t on t.id = c.type_id
		join calc_correction_headers h on h.id = t.header_id
		where c.type_id = par_type_id and c.height_id = par_height_id;

		if par_x < var_header[1] or par_x > var_header[cardinality(var_header)] then
			raise exception 'Значение % вне заголовка таблицы (% .. %)', par_x, var_header[1], var_header[cardinality(var_header)];
		end if;

		for var_i in 1 .. cardinality(var_header) loop
			if var_header[var_i] = par_x then
				return var_values[var_i];
			end if;
			if var_header[var_i] > par_x then
				var_interpolation := row(var_header[var_i - 1], var_header[var_i], var_values[var_i - 1], var_values[var_i]);
				return fn_calc_interpolation(par_x, var_interpolation);
			end if;
		end loop;

		return null;
	end;
	$BODY$;

	-- Среднее отклонение температуры на высоте (Таблица 2)
	-- Для минуса возвращает |сумма| + 50
	create or replace function fn_calc_mean_temperature(par_delta_t0 integer, par_height_id integer)
	returns integer
	language plpgsql
	as $BODY$
	declare
		var_type_id integer;
		var_tens integer := (abs(par_delta_t0) / 10) * 10;
		var_ones integer := abs(par_delta_t0) % 10;
		var_sum integer := 0;
	begin
		if par_delta_t0 = 0 then
			return 0;
		end if;

		select id into var_type_id from calc_correction_types
		where description = case when par_delta_t0 < 0 then 'Таблица 2, Отрицательные температуры'
		                         else 'Таблица 2, Положительные температуры' end;

		if var_tens > 0 then
			var_sum := var_sum + fn_calc_correction_value(var_type_id, par_height_id, var_tens);
		end if;
		if var_ones > 0 then
			var_sum := var_sum + fn_calc_correction_value(var_type_id, par_height_id, var_ones);
		end if;

		if var_sum < 0 then
			return abs(var_sum) + 50;
		end if;
		return var_sum;
	end;
	$BODY$;

	-- Главная функция
	create or replace function fn_calc_meteo11(par_params meteo_input_params, par_equipment_id integer)
	returns table (height integer, h text, tt text, hh text, cc text)
	language plpgsql
	as $BODY$
	declare
		var_short_name text;
		var_delta_t0 integer;
		var_speed_type integer;
		var_dir_type integer;
		var_input numeric;
		var_zero boolean := false;
		var_row record;
		var_speed numeric;
		var_dir integer;
	begin
		select short_name into var_short_name from measurment_equipment where id = par_equipment_id;
		if var_short_name is null then
			raise exception 'Неизвестный тип оборудования: %', par_equipment_id;
		end if;

		if par_params.temperature not between -58 and 58 then
			raise exception 'Температура % вне диапазона -58..58', par_params.temperature;
		end if;
		if par_params.pressure not between 500 and 900 then
			raise exception 'Давление % вне диапазона 500..900', par_params.pressure;
		end if;
		if par_params.wind_direction not between 0 and 59 then
			raise exception 'Направление ветра % вне диапазона 0..59', par_params.wind_direction;
		end if;

		if var_short_name = 'ДМК' then
			var_input := par_params.wind_speed;
			if var_input is null or var_input not between 0 and 15 then
				raise exception 'Скорость ветра % вне диапазона 0..15', var_input;
			end if;
			var_zero := var_input < 3;
		else
			var_input := par_params.bullet_drift;
			if var_input is null or var_input not between 0 and 150 then
				raise exception 'Дальность сноса пуль % вне диапазона 0..150', var_input;
			end if;
			var_zero := var_input < 40;
		end if;

		-- Тип со скоростью имеет заголовок, тип с направлением - нет
		select id into var_speed_type from calc_correction_types
		where measurment_equipment_id = par_equipment_id and header_id is not null;
		select id into var_dir_type from calc_correction_types
		where measurment_equipment_id = par_equipment_id and header_id is null;

		var_delta_t0 := fn_calc_delta_t0(par_params.temperature);

		for var_row in select ch.id, ch.height from calc_correction_heights ch order by ch.height loop
			height := var_row.height;
			h := lpad((var_row.height / 100)::text, 2, '0');
			tt := lpad(fn_calc_mean_temperature(var_delta_t0, var_row.id)::text, 2, '0');

			if var_zero then
				hh := '00';
				cc := '00';
			else
				var_speed := round(fn_calc_correction_value(var_speed_type, var_row.id, var_input));
				select c.row_values[1] into var_dir from calc_correction c
				where c.type_id = var_dir_type and c.height_id = var_row.id;

				hh := lpad(((par_params.wind_direction + var_dir) % 60)::text, 2, '0');
				cc := lpad(var_speed::text, 2, '0');
			end if;

			return next;
		end loop;
	end;
	$BODY$;

	comment on function fn_calc_meteo11(meteo_input_params, integer) is 'Расчет приближенного МЕТЕО-11: по строке на каждую типовую высоту';

end $$;
