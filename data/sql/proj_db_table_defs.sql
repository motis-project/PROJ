--- Table structures

-- Note on the INTEGER_OR_TEXT data type. This is a "non-standard" type
-- declaration, but this is perfectly legal as SQLite is loosely typed.
-- As this declaration contains the string INT, it is assigned INTEGER affinity.
-- Which means that values provided either as text (that contains integer value)
-- or integer will be stored as integers, whereas text values will be stored as
-- text. See paragraph 3 and 3.1 of https://www.sqlite.org/datatype3.html.
-- The "INTEGER_OR_TEXT" name is a hint for the user, and software like
-- GDAL (>= 3.3) to expose the column as string...
-- The effect of using this rather than TEXT is making the DB size go from
-- 9 MB to 8.4.

CREATE TABLE metadata(
    key TEXT NOT NULL PRIMARY KEY CHECK (length(key) >= 1),
    value TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE unit_of_measure(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    type TEXT NOT NULL CHECK (type IN ('length', 'angle', 'scale', 'time')),
    conv_factor FLOAT,
    proj_short_name TEXT, -- PROJ string name, like 'm', 'ft'. Might be NULL
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_unit_of_measure PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE celestial_body (
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    semi_major_axis FLOAT NOT NULL CHECK (semi_major_axis > 0), -- approximate (in metre)
    CONSTRAINT pk_celestial_body PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE ellipsoid (
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    celestial_body_auth_name TEXT NOT NULL,
    celestial_body_code INTEGER_OR_TEXT NOT NULL,
    semi_major_axis FLOAT NOT NULL CHECK (semi_major_axis > 0),
    uom_auth_name TEXT NOT NULL,
    uom_code INTEGER_OR_TEXT NOT NULL,
    inv_flattening FLOAT CHECK (inv_flattening = 0 OR inv_flattening >= 1.0),
    semi_minor_axis FLOAT CHECK (semi_minor_axis > 0 AND semi_minor_axis <= semi_major_axis),
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_ellipsoid PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_ellipsoid_celestial_body FOREIGN KEY (celestial_body_auth_name, celestial_body_code) REFERENCES celestial_body(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_ellipsoid_unit_of_measure FOREIGN KEY (uom_auth_name, uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT check_ellipsoid_inv_flattening_semi_minor_mutually_exclusive CHECK ((inv_flattening IS NULL AND semi_minor_axis IS NOT NULL) OR (inv_flattening IS NOT NULL AND semi_minor_axis IS NULL))
) WITHOUT ROWID;

CREATE TABLE extent(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT NOT NULL,
    south_lat FLOAT CHECK (south_lat BETWEEN -90 AND 90),
    north_lat FLOAT CHECK (north_lat BETWEEN -90 AND 90),
    west_lon FLOAT CHECK (west_lon BETWEEN -180 AND 180),
    east_lon FLOAT CHECK (east_lon BETWEEN -180 AND 180),
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_extent PRIMARY KEY (auth_name, code),
    CONSTRAINT check_extent_lat CHECK (south_lat <= north_lat)
) WITHOUT ROWID;

CREATE TABLE scope(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    scope TEXT NOT NULL CHECK (length(scope) >= 1),
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_scope PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE usage(
    auth_name TEXT CHECK (auth_name IS NULL OR length(auth_name) >= 1),
    code INTEGER_OR_TEXT CHECK (code IS NULL OR length(code) >= 1),
    object_table_name TEXT NOT NULL CHECK (object_table_name IN (
        'geodetic_datum', 'vertical_datum', 'engineering_datum',
        'geodetic_crs', 'projected_crs', 'vertical_crs', 'compound_crs',
        'engineering_crs',
        'conversion', 'grid_transformation',
        'helmert_transformation', 'other_transformation', 'concatenated_operation')),
    object_auth_name TEXT NOT NULL,
    object_code INTEGER_OR_TEXT NOT NULL,
    extent_auth_name TEXT NOT NULL,
    extent_code INTEGER_OR_TEXT NOT NULL,
    scope_auth_name TEXT NOT NULL,
    scope_code INTEGER_OR_TEXT NOT NULL,
    CONSTRAINT pk_usage PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_usage_extent FOREIGN KEY (extent_auth_name, extent_code) REFERENCES extent(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_usage_scope FOREIGN KEY (scope_auth_name, scope_code) REFERENCES scope(auth_name, code) ON DELETE CASCADE
);

CREATE INDEX idx_usage_object ON usage(object_table_name, object_auth_name, object_code);

CREATE TABLE prime_meridian(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    longitude FLOAT NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    uom_auth_name TEXT NOT NULL,
    uom_code INTEGER_OR_TEXT NOT NULL,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_prime_meridian PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_prime_meridian_unit_of_measure FOREIGN KEY (uom_auth_name, uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE TABLE geodetic_datum (
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    ellipsoid_auth_name TEXT NOT NULL,
    ellipsoid_code INTEGER_OR_TEXT NOT NULL,
    prime_meridian_auth_name TEXT NOT NULL,
    prime_meridian_code INTEGER_OR_TEXT NOT NULL,
    publication_date TEXT, --- YYYY-MM-DD format
    frame_reference_epoch FLOAT, --- only set for dynamic datum, and should be set when it is a dynamic datum
    ensemble_accuracy FLOAT CHECK (ensemble_accuracy IS NULL OR ensemble_accuracy > 0), --- only for a datum ensemble. and should be set when it is a datum ensemble
    anchor TEXT,
    anchor_epoch FLOAT,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_geodetic_datum PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_geodetic_datum_ellipsoid FOREIGN KEY (ellipsoid_auth_name, ellipsoid_code) REFERENCES ellipsoid(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_geodetic_datum_prime_meridian FOREIGN KEY (prime_meridian_auth_name, prime_meridian_code) REFERENCES prime_meridian(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE TABLE geodetic_datum_ensemble_member (
    ensemble_auth_name TEXT NOT NULL,
    ensemble_code INTEGER_OR_TEXT NOT NULL,
    member_auth_name TEXT NOT NULL,
    member_code INTEGER_OR_TEXT NOT NULL,
    sequence INTEGER NOT NULL CHECK (sequence >= 1),
    CONSTRAINT fk_geodetic_datum_ensemble_member_ensemble FOREIGN KEY (ensemble_auth_name, ensemble_code) REFERENCES geodetic_datum(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_geodetic_datum_ensemble_member_ensemble_member FOREIGN KEY (member_auth_name, member_code) REFERENCES geodetic_datum(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT unique_geodetic_datum_ensemble_member UNIQUE (ensemble_auth_name, ensemble_code, sequence)
);

CREATE TABLE vertical_datum (
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    publication_date TEXT CHECK (NULL OR length(publication_date) = 10), --- YYYY-MM-DD format
    frame_reference_epoch FLOAT, --- only set for dynamic datum, and should be set when it is a dynamic datum
    ensemble_accuracy FLOAT CHECK (ensemble_accuracy IS NULL OR ensemble_accuracy > 0), --- only for a datum ensemble. and should be set when it is a datum ensemble
    anchor TEXT,
    anchor_epoch FLOAT,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_vertical_datum PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE vertical_datum_ensemble_member (
    ensemble_auth_name TEXT NOT NULL,
    ensemble_code INTEGER_OR_TEXT NOT NULL,
    member_auth_name TEXT NOT NULL,
    member_code INTEGER_OR_TEXT NOT NULL,
    sequence INTEGER NOT NULL CHECK (sequence >= 1),
    CONSTRAINT fk_vertical_datum_ensemble_member_ensemble FOREIGN KEY (ensemble_auth_name, ensemble_code) REFERENCES vertical_datum(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_vertical_datum_ensemble_member_ensemble_member FOREIGN KEY (member_auth_name, member_code) REFERENCES vertical_datum(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT unique_vertical_datum_ensemble_member UNIQUE (ensemble_auth_name, ensemble_code, sequence)
);

CREATE TABLE engineering_datum (
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    publication_date TEXT, --- YYYY-MM-DD format
    anchor TEXT,
    anchor_epoch FLOAT,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_engineering_datum PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE coordinate_system(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    type TEXT NOT NULL CHECK (type IN ('Cartesian', 'vertical', 'ellipsoidal', 'spherical', 'ordinal')),
    dimension SMALLINT NOT NULL CHECK (dimension BETWEEN 1 AND 3),
    CONSTRAINT pk_coordinate_system PRIMARY KEY (auth_name, code),
    CONSTRAINT check_cs_vertical CHECK (type != 'vertical' OR dimension = 1),
    CONSTRAINT check_cs_cartesian CHECK (type != 'Cartesian' OR dimension IN (2,3)),
    CONSTRAINT check_cs_ellipsoidal CHECK (type != 'ellipsoidal' OR dimension IN (2,3))
);

CREATE TABLE axis(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    abbrev TEXT NOT NULL,
    orientation TEXT NOT NULL,
    coordinate_system_auth_name TEXT NOT NULL,
    coordinate_system_code INTEGER_OR_TEXT NOT NULL,
    coordinate_system_order SMALLINT NOT NULL CHECK (coordinate_system_order BETWEEN 1 AND 3),
    uom_auth_name TEXT,
    uom_code INTEGER_OR_TEXT,
    CONSTRAINT pk_axis PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_axis_coordinate_system FOREIGN KEY (coordinate_system_auth_name, coordinate_system_code) REFERENCES coordinate_system(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_axis_unit_of_measure FOREIGN KEY (uom_auth_name, uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE TABLE geodetic_crs(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('geographic 2D', 'geographic 3D', 'geocentric', 'other')),
    coordinate_system_auth_name TEXT,
    coordinate_system_code INTEGER_OR_TEXT,
    datum_auth_name TEXT,
    datum_code INTEGER_OR_TEXT,
    text_definition TEXT, -- PROJ string or WKT string. Use of this is discouraged as prone to definition ambiguities
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_geodetic_crs PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_geodetic_crs_coordinate_system FOREIGN KEY (coordinate_system_auth_name, coordinate_system_code) REFERENCES coordinate_system(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_geodetic_crs_datum FOREIGN KEY (datum_auth_name, datum_code) REFERENCES geodetic_datum(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT check_geodetic_crs_cs CHECK (NOT ((coordinate_system_auth_name IS NULL OR coordinate_system_code IS NULL) AND text_definition IS NULL)),
    CONSTRAINT check_geodetic_crs_cs_bis CHECK (NOT ((NOT(coordinate_system_auth_name IS NULL OR coordinate_system_code IS NULL)) AND text_definition IS NOT NULL)),
    CONSTRAINT check_geodetic_crs_datum CHECK (NOT ((datum_auth_name IS NULL OR datum_code IS NULL) AND text_definition IS NULL)),
    CONSTRAINT check_geodetic_crs_datum_bis CHECK (NOT ((NOT(datum_auth_name IS NULL OR datum_code IS NULL)) AND text_definition IS NOT NULL))
) WITHOUT ROWID;

CREATE TABLE vertical_crs(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    coordinate_system_auth_name TEXT NOT NULL,
    coordinate_system_code INTEGER_OR_TEXT NOT NULL,
    datum_auth_name TEXT NOT NULL,
    datum_code INTEGER_OR_TEXT NOT NULL,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_vertical_crs PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_vertical_crs_coordinate_system FOREIGN KEY (coordinate_system_auth_name, coordinate_system_code) REFERENCES coordinate_system(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_vertical_crs_datum FOREIGN KEY (datum_auth_name, datum_code) REFERENCES vertical_datum(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE TABLE engineering_crs(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    coordinate_system_auth_name TEXT NOT NULL,
    coordinate_system_code INTEGER_OR_TEXT NOT NULL,
    datum_auth_name TEXT NOT NULL,
    datum_code INTEGER_OR_TEXT NOT NULL,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_engineering_crs PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_engineering_crs_coordinate_system FOREIGN KEY (coordinate_system_auth_name, coordinate_system_code) REFERENCES coordinate_system(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_engineering_crs_datum FOREIGN KEY (datum_auth_name, datum_code) REFERENCES engineering_datum(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

-- Authorities provided by the upstream PROJ
-- This is used to check unicity of object names
CREATE TABLE builtin_authorities(auth_name TEXT NOT NULL PRIMARY KEY) WITHOUT ROWID;
INSERT INTO builtin_authorities VALUES
    ('EPSG'),
    ('ESRI'),
    ('IAU_2015'),
    ('IGNF'),
    ('NKG'),
    ('NRCAN'),
    ('OGC'),
    ('PROJ')
;

CREATE TABLE conversion_method(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    CONSTRAINT pk_conversion_method PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE conversion_param(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    CONSTRAINT pk_conversion_param PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE conversion_table(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    description TEXT,

    method_auth_name TEXT CHECK (method_auth_name IS NULL OR length(method_auth_name) >= 1),
    method_code INTEGER_OR_TEXT CHECK (method_code IS NULL OR length(method_code) >= 1),
    -- method_name TEXT,

    param1_auth_name TEXT,
    param1_code INTEGER_OR_TEXT,
    -- param1_name TEXT,
    param1_value FLOAT,
    param1_uom_auth_name TEXT,
    param1_uom_code INTEGER_OR_TEXT,

    param2_auth_name TEXT,
    param2_code INTEGER_OR_TEXT,
    --param2_name TEXT,
    param2_value FLOAT,
    param2_uom_auth_name TEXT,
    param2_uom_code INTEGER_OR_TEXT,

    param3_auth_name TEXT,
    param3_code INTEGER_OR_TEXT,
    --param3_name TEXT,
    param3_value FLOAT,
    param3_uom_auth_name TEXT,
    param3_uom_code INTEGER_OR_TEXT,

    param4_auth_name TEXT,
    param4_code INTEGER_OR_TEXT,
    --param4_name TEXT,
    param4_value FLOAT,
    param4_uom_auth_name TEXT,
    param4_uom_code INTEGER_OR_TEXT,

    param5_auth_name TEXT,
    param5_code INTEGER_OR_TEXT,
    --param5_name TEXT,
    param5_value FLOAT,
    param5_uom_auth_name TEXT,
    param5_uom_code INTEGER_OR_TEXT,

    param6_auth_name TEXT,
    param6_code INTEGER_OR_TEXT,
    --param6_name TEXT,
    param6_value FLOAT,
    param6_uom_auth_name TEXT,
    param6_uom_code INTEGER_OR_TEXT,

    param7_auth_name TEXT,
    param7_code INTEGER_OR_TEXT,
    --param7_name TEXT,
    param7_value FLOAT,
    param7_uom_auth_name TEXT,
    param7_uom_code INTEGER_OR_TEXT,

    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),

    CONSTRAINT pk_conversion PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_conversion_method FOREIGN KEY (method_auth_name, method_code) REFERENCES conversion_method(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_conversion_coordinate_operation FOREIGN KEY (auth_name, code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param1_uom FOREIGN KEY (param1_uom_auth_name, param1_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param2_uom FOREIGN KEY (param2_uom_auth_name, param2_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param3_uom FOREIGN KEY (param3_uom_auth_name, param3_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param4_uom FOREIGN KEY (param4_uom_auth_name, param4_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param5_uom FOREIGN KEY (param5_uom_auth_name, param5_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param6_uom FOREIGN KEY (param6_uom_auth_name, param6_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_conversion_param7_uom FOREIGN KEY (param7_uom_auth_name, param7_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE VIEW conversion AS SELECT
    c.auth_name,
    c.code,
    c.name,

    c.description,

    c.method_auth_name,
    c.method_code,
    m.name AS method_name,

    c.param1_auth_name,
    c.param1_code,
    param1.name AS param1_name,
    c.param1_value,
    c.param1_uom_auth_name,
    c.param1_uom_code,

    c.param2_auth_name,
    c.param2_code,
    param2.name AS param2_name,
    c.param2_value,
    c.param2_uom_auth_name,
    c.param2_uom_code,

    c.param3_auth_name,
    c.param3_code,
    param3.name AS param3_name,
    c.param3_value,
    c.param3_uom_auth_name,
    c.param3_uom_code,

    c.param4_auth_name,
    c.param4_code,
    param4.name AS param4_name,
    c.param4_value,
    c.param4_uom_auth_name,
    c.param4_uom_code,

    c.param5_auth_name,
    c.param5_code,
    param5.name AS param5_name,
    c.param5_value,
    c.param5_uom_auth_name,
    c.param5_uom_code,

    c.param6_auth_name,
    c.param6_code,
    param6.name AS param6_name,
    c.param6_value,
    c.param6_uom_auth_name,
    c.param6_uom_code,

    c.param7_auth_name,
    c.param7_code,
    param7.name AS param7_name,
    c.param7_value,
    c.param7_uom_auth_name,
    c.param7_uom_code,

    c.deprecated

    FROM conversion_table c
    LEFT JOIN conversion_method m ON c.method_auth_name = m.auth_name AND c.method_code = m.code
    LEFT JOIN conversion_param param1 ON c.param1_auth_name = param1.auth_name AND c.param1_code = param1.code
    LEFT JOIN conversion_param param2 ON c.param2_auth_name = param2.auth_name AND c.param2_code = param2.code
    LEFT JOIN conversion_param param3 ON c.param3_auth_name = param3.auth_name AND c.param3_code = param3.code
    LEFT JOIN conversion_param param4 ON c.param4_auth_name = param4.auth_name AND c.param4_code = param4.code
    LEFT JOIN conversion_param param5 ON c.param5_auth_name = param5.auth_name AND c.param5_code = param5.code
    LEFT JOIN conversion_param param6 ON c.param6_auth_name = param6.auth_name AND c.param6_code = param6.code
    LEFT JOIN conversion_param param7 ON c.param7_auth_name = param7.auth_name AND c.param7_code = param7.code
;

CREATE TRIGGER conversion_insert_trigger_method
INSTEAD OF INSERT ON conversion
    WHEN NOT EXISTS (SELECT 1 FROM conversion_method m WHERE
        m.auth_name = NEW.method_auth_name AND m.code = NEW.method_code AND m.name = NEW.method_name)
BEGIN
    INSERT INTO conversion_method VALUES (NEW.method_auth_name, NEW.method_code, NEW.method_name);
END;

CREATE TRIGGER conversion_insert_trigger_param1
INSTEAD OF INSERT ON conversion
    WHEN NEW.param1_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param1_auth_name AND p.code = NEW.param1_code AND p.name = NEW.param1_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param1_auth_name, NEW.param1_code, NEW.param1_name);
END;

CREATE TRIGGER conversion_insert_trigger_param2
INSTEAD OF INSERT ON conversion
    WHEN NEW.param2_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param2_auth_name AND p.code = NEW.param2_code AND p.name = NEW.param2_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param2_auth_name, NEW.param2_code, NEW.param2_name);
END;

CREATE TRIGGER conversion_insert_trigger_param3
INSTEAD OF INSERT ON conversion
    WHEN NEW.param3_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param3_auth_name AND p.code = NEW.param3_code AND p.name = NEW.param3_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param3_auth_name, NEW.param3_code, NEW.param3_name);
END;

CREATE TRIGGER conversion_insert_trigger_param4
INSTEAD OF INSERT ON conversion
    WHEN NEW.param4_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param4_auth_name AND p.code = NEW.param4_code AND p.name = NEW.param4_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param4_auth_name, NEW.param4_code, NEW.param4_name);
END;

CREATE TRIGGER conversion_insert_trigger_param5
INSTEAD OF INSERT ON conversion
    WHEN NEW.param5_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param5_auth_name AND p.code = NEW.param5_code AND p.name = NEW.param5_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param5_auth_name, NEW.param5_code, NEW.param5_name);
END;

CREATE TRIGGER conversion_insert_trigger_param6
INSTEAD OF INSERT ON conversion
    WHEN NEW.param6_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param6_auth_name AND p.code = NEW.param6_code AND p.name = NEW.param6_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param6_auth_name, NEW.param6_code, NEW.param6_name);
END;

CREATE TRIGGER conversion_insert_trigger_param7
INSTEAD OF INSERT ON conversion
    WHEN NEW.param7_auth_name is NOT NULL AND NOT EXISTS
        (SELECT 1 FROM conversion_param p WHERE p.auth_name = NEW.param7_auth_name AND p.code = NEW.param7_code AND p.name = NEW.param7_name)
BEGIN
    INSERT INTO conversion_param VALUES (NEW.param7_auth_name, NEW.param7_code, NEW.param7_name);
END;

CREATE TRIGGER conversion_insert_trigger_insert_into_conversion_table
INSTEAD OF INSERT ON conversion
BEGIN
INSERT INTO conversion_table VALUES
(
    NEW.auth_name,
    NEW.code,
    NEW.name,

    NEW.description,

    NEW.method_auth_name,
    NEW.method_code,
    --NEW.method_name,

    NEW.param1_auth_name,
    NEW.param1_code,
    --NEW.param1_name,
    NEW.param1_value,
    NEW.param1_uom_auth_name,
    NEW.param1_uom_code,

    NEW.param2_auth_name,
    NEW.param2_code,
    --NEW.param2_name,
    NEW.param2_value,
    NEW.param2_uom_auth_name,
    NEW.param2_uom_code,

    NEW.param3_auth_name,
    NEW.param3_code,
    --NEW.param3_name,
    NEW.param3_value,
    NEW.param3_uom_auth_name,
    NEW.param3_uom_code,

    NEW.param4_auth_name,
    NEW.param4_code,
    --NEW.param4_name,
    NEW.param4_value,
    NEW.param4_uom_auth_name,
    NEW.param4_uom_code,

    NEW.param5_auth_name,
    NEW.param5_code,
    --NEW.param5_name,
    NEW.param5_value,
    NEW.param5_uom_auth_name,
    NEW.param5_uom_code,

    NEW.param6_auth_name,
    NEW.param6_code,
    --NEW.param6_name,
    NEW.param6_value,
    NEW.param6_uom_auth_name,
    NEW.param6_uom_code,

    NEW.param7_auth_name,
    NEW.param7_code,
    --NEW.param7_name,
    NEW.param7_value,
    NEW.param7_uom_auth_name,
    NEW.param7_uom_code,

    NEW.deprecated
);
END;

CREATE TABLE projected_crs(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    coordinate_system_auth_name TEXT,
    coordinate_system_code INTEGER_OR_TEXT,
    geodetic_crs_auth_name TEXT,
    geodetic_crs_code INTEGER_OR_TEXT,
    conversion_auth_name TEXT,
    conversion_code INTEGER_OR_TEXT,
    text_definition TEXT, -- PROJ string or WKT string. Use of this is discouraged as prone to definition ambiguities
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_projected_crs PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_projected_crs_coordinate_system FOREIGN KEY (coordinate_system_auth_name, coordinate_system_code) REFERENCES coordinate_system(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_projected_crs_geodetic_crs FOREIGN KEY (geodetic_crs_auth_name, geodetic_crs_code) REFERENCES geodetic_crs(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_projected_crs_conversion FOREIGN KEY (conversion_auth_name, conversion_code) REFERENCES conversion_table(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT check_projected_crs_cs CHECK (NOT((coordinate_system_auth_name IS NULL OR coordinate_system_code IS NULL) AND text_definition IS NULL)),
    CONSTRAINT check_projected_crs_cs_bis CHECK (NOT((NOT(coordinate_system_auth_name IS NULL OR coordinate_system_code IS NULL)) AND text_definition IS NOT NULL)),
    CONSTRAINT check_projected_crs_geodetic_crs CHECK (NOT((geodetic_crs_auth_name IS NULL OR geodetic_crs_code IS NULL) AND text_definition IS NULL)),
    CONSTRAINT check_projected_crs_conversion CHECK (NOT((NOT(conversion_auth_name IS NULL OR conversion_code IS NULL)) AND text_definition IS NOT NULL))
) WITHOUT ROWID;

CREATE TABLE compound_crs(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),
    description TEXT,
    horiz_crs_auth_name TEXT NOT NULL,
    horiz_crs_code INTEGER_OR_TEXT NOT NULL,
    vertical_crs_auth_name TEXT NOT NULL,
    vertical_crs_code INTEGER_OR_TEXT NOT NULL,
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_compound_crs PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_compound_crs_vertical_crs FOREIGN KEY (vertical_crs_auth_name, vertical_crs_code) REFERENCES vertical_crs(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE TABLE coordinate_metadata(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    description TEXT,
    crs_auth_name TEXT,
    crs_code INTEGER_OR_TEXT,
    crs_text_definition TEXT, -- WKT string or PROJJSON string. Mutually exclusive with (crs_auth_name, crs_code)
    coordinate_epoch DOUBLE, -- may be NULL
    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),
    CONSTRAINT pk_coordinate_metadata PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE coordinate_operation_method(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    CONSTRAINT pk_coordinate_operation_method PRIMARY KEY (auth_name, code)
) WITHOUT ROWID;

CREATE TABLE helmert_transformation_table(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    description TEXT,

    method_auth_name TEXT NOT NULL CHECK (length(method_auth_name) >= 1),
    method_code INTEGER_OR_TEXT NOT NULL CHECK (length(method_code) >= 1),
    --method_name TEXT NOT NULL CHECK (length(method_name) >= 2),

    source_crs_auth_name TEXT NOT NULL,
    source_crs_code INTEGER_OR_TEXT NOT NULL,
    target_crs_auth_name TEXT NOT NULL,
    target_crs_code INTEGER_OR_TEXT NOT NULL,

    accuracy FLOAT CHECK (accuracy >= 0),

    tx FLOAT NOT NULL,
    ty FLOAT NOT NULL,
    tz FLOAT NOT NULL,
    translation_uom_auth_name TEXT NOT NULL,
    translation_uom_code INTEGER_OR_TEXT NOT NULL,
    rx FLOAT,
    ry FLOAT,
    rz FLOAT,
    rotation_uom_auth_name TEXT,
    rotation_uom_code INTEGER_OR_TEXT,
    scale_difference FLOAT,
    scale_difference_uom_auth_name TEXT,
    scale_difference_uom_code INTEGER_OR_TEXT,
    rate_tx FLOAT,
    rate_ty FLOAT,
    rate_tz FLOAT,
    rate_translation_uom_auth_name TEXT,
    rate_translation_uom_code INTEGER_OR_TEXT,
    rate_rx FLOAT,
    rate_ry FLOAT,
    rate_rz FLOAT,
    rate_rotation_uom_auth_name TEXT,
    rate_rotation_uom_code INTEGER_OR_TEXT,
    rate_scale_difference FLOAT,
    rate_scale_difference_uom_auth_name TEXT,
    rate_scale_difference_uom_code INTEGER_OR_TEXT,
    epoch FLOAT,
    epoch_uom_auth_name TEXT,
    epoch_uom_code INTEGER_OR_TEXT,
    px FLOAT, -- Pivot / evaluation point for Molodensky-Badekas
    py FLOAT,
    pz FLOAT,
    pivot_uom_auth_name TEXT,
    pivot_uom_code INTEGER_OR_TEXT,

    operation_version TEXT, -- normally mandatory in OGC Topic 2 but optional here

    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),

    CONSTRAINT pk_helmert_transformation PRIMARY KEY (auth_name, code),
    CONSTRAINT fk_helmert_transformation_source_crs FOREIGN KEY (source_crs_auth_name, source_crs_code) REFERENCES geodetic_crs(auth_name, code) ON DELETE CASCADE,
    -- below not true for EPSG:10905 ("ETRS89/DREF91/2016 to Asse 2025 + Asse 2025 height (1)") whose target CRS is a compound CRS
    -- CONSTRAINT fk_helmert_transformation_target_crs FOREIGN KEY (target_crs_auth_name, target_crs_code) REFERENCES geodetic_crs(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_transformation_method FOREIGN KEY (method_auth_name, method_code) REFERENCES coordinate_operation_method(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_helmert_transformation_coordinate_operation FOREIGN KEY (auth_name, code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_translation_uom FOREIGN KEY (translation_uom_auth_name, translation_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_rotation_uom FOREIGN KEY (rotation_uom_auth_name, rotation_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_scale_difference_uom FOREIGN KEY (scale_difference_uom_auth_name, scale_difference_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_rate_translation_uom FOREIGN KEY (rate_translation_uom_auth_name, rate_translation_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_rate_rotation_uom FOREIGN KEY (rate_rotation_uom_auth_name, rate_rotation_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_rate_scale_difference_uom FOREIGN KEY (rate_scale_difference_uom_auth_name, rate_scale_difference_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_epoch_uom FOREIGN KEY (epoch_uom_auth_name, epoch_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_helmert_pivot_uom FOREIGN KEY (pivot_uom_auth_name, pivot_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE VIEW helmert_transformation AS SELECT
    h.auth_name,
    h.code,
    h.name,

    h.description,

    h.method_auth_name,
    h.method_code,
    m.name AS method_name,

    h.source_crs_auth_name,
    h.source_crs_code,
    h.target_crs_auth_name,
    h.target_crs_code,

    h.accuracy,

    h.tx,
    h.ty,
    h.tz,
    h.translation_uom_auth_name,
    h.translation_uom_code,
    h.rx,
    h.ry,
    h.rz,
    h.rotation_uom_auth_name,
    h.rotation_uom_code,
    h.scale_difference,
    h.scale_difference_uom_auth_name,
    h.scale_difference_uom_code,
    h.rate_tx,
    h.rate_ty,
    h.rate_tz,
    h.rate_translation_uom_auth_name,
    h.rate_translation_uom_code,
    h.rate_rx,
    h.rate_ry,
    h.rate_rz,
    h.rate_rotation_uom_auth_name,
    h.rate_rotation_uom_code,
    h.rate_scale_difference,
    h.rate_scale_difference_uom_auth_name,
    h.rate_scale_difference_uom_code,
    h.epoch,
    h.epoch_uom_auth_name,
    h.epoch_uom_code,
    h.px,
    h.py,
    h.pz,
    h.pivot_uom_auth_name,
    h.pivot_uom_code,

    h.operation_version,

    h.deprecated

    FROM helmert_transformation_table h
    LEFT JOIN coordinate_operation_method m ON h.method_auth_name = m.auth_name AND h.method_code = m.code
;

CREATE TRIGGER helmert_transformation_insert_trigger_method
INSTEAD OF INSERT ON helmert_transformation
    WHEN NOT EXISTS (SELECT 1 FROM coordinate_operation_method m WHERE
        m.auth_name = NEW.method_auth_name AND m.code = NEW.method_code AND m.name = NEW.method_name)
BEGIN
    INSERT INTO coordinate_operation_method VALUES (NEW.method_auth_name, NEW.method_code, NEW.method_name);
END;

CREATE TRIGGER helmert_transformation_insert_trigger_into_helmert_transformation_table
INSTEAD OF INSERT ON helmert_transformation
BEGIN
INSERT INTO helmert_transformation_table VALUES
(
    NEW.auth_name,
    NEW.code,
    NEW.name,

    NEW.description,

    NEW.method_auth_name,
    NEW.method_code,
    -- method_name

    NEW.source_crs_auth_name,
    NEW.source_crs_code,
    NEW.target_crs_auth_name,
    NEW.target_crs_code,

    NEW.accuracy,

    NEW.tx,
    NEW.ty,
    NEW.tz,
    NEW.translation_uom_auth_name,
    NEW.translation_uom_code,
    NEW.rx,
    NEW.ry,
    NEW.rz,
    NEW.rotation_uom_auth_name,
    NEW.rotation_uom_code,
    NEW.scale_difference,
    NEW.scale_difference_uom_auth_name,
    NEW.scale_difference_uom_code,
    NEW.rate_tx,
    NEW.rate_ty,
    NEW.rate_tz,
    NEW.rate_translation_uom_auth_name,
    NEW.rate_translation_uom_code,
    NEW.rate_rx,
    NEW.rate_ry,
    NEW.rate_rz,
    NEW.rate_rotation_uom_auth_name,
    NEW.rate_rotation_uom_code,
    NEW.rate_scale_difference,
    NEW.rate_scale_difference_uom_auth_name,
    NEW.rate_scale_difference_uom_code,
    NEW.epoch,
    NEW.epoch_uom_auth_name,
    NEW.epoch_uom_code,
    NEW.px,
    NEW.py,
    NEW.pz,
    NEW.pivot_uom_auth_name,
    NEW.pivot_uom_code,

    NEW.operation_version,

    NEW.deprecated
);
END;

CREATE TABLE grid_transformation(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    description TEXT,

    method_auth_name TEXT NOT NULL CHECK (length(method_auth_name) >= 1),
    method_code INTEGER_OR_TEXT NOT NULL CHECK (length(method_code) >= 1),
    method_name TEXT NOT NULL CHECK (length(method_name) >= 2),

    source_crs_auth_name TEXT NOT NULL,
    source_crs_code INTEGER_OR_TEXT NOT NULL,
    target_crs_auth_name TEXT NOT NULL,
    target_crs_code INTEGER_OR_TEXT NOT NULL,

    accuracy FLOAT CHECK (accuracy >= 0),

    grid_param_auth_name TEXT NOT NULL,
    grid_param_code INTEGER_OR_TEXT NOT NULL,
    grid_param_name TEXT NOT NULL,
    grid_name TEXT NOT NULL,

    grid2_param_auth_name TEXT,
    grid2_param_code INTEGER_OR_TEXT,
    grid2_param_name TEXT,
    grid2_name TEXT,

    interpolation_crs_auth_name TEXT,
    interpolation_crs_code INTEGER_OR_TEXT,

    operation_version TEXT, -- normally mandatory in OGC Topic 2 but optional here

    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),

    CONSTRAINT pk_grid_transformation PRIMARY KEY (auth_name, code)
    --CONSTRAINT fk_grid_transformation_coordinate_operation FOREIGN KEY (auth_name, code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_grid_transformation_source_crs FOREIGN KEY (source_crs_auth_name, source_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_grid_transformation_target_crs FOREIGN KEY (target_crs_auth_name, target_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
    -- CONSTRAINT fk_grid_transformation_interpolation_crs FOREIGN KEY (interpolation_crs_auth_name, interpolation_crs_code) REFERENCES crs_view(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;

-- Table that describe packages/archives that contain several grids
CREATE TABLE grid_packages(
    package_name TEXT NOT NULL NULL PRIMARY KEY,    -- package name that contains the file
    description TEXT,
    url TEXT,                                       -- optional URL where to download the PROJ grid
    direct_download BOOLEAN CHECK (direct_download IN (0, 1)), -- whether the URL can be used directly (if 0, authentication etc mightbe needed)
    open_license BOOLEAN CHECK (open_license IN (0, 1))
) WITHOUT ROWID;

-- Table that contain alternative names for original grid names coming from the authority
CREATE TABLE grid_alternatives(
    original_grid_name TEXT NOT NULL PRIMARY KEY,   -- original grid name (e.g. Und_min2.5x2.5_egm2008_isw=82_WGS84_TideFree.gz). For LOS/LAS format, the .las files
    proj_grid_name TEXT NOT NULL,                   -- PROJ >= 7 grid name (e.g us_nga_egm08_25.tif)
    old_proj_grid_name TEXT,                        -- PROJ < 7 grid name (e.g egm08_25.gtx)
    proj_grid_format TEXT NOT NULL,                 -- 'GTiff', 'GTX', 'NTv2', JSON
    proj_method TEXT NOT NULL,                      -- gridshift, hgridshift, vgridshift, geoid_like, geocentricoffset, tinshift or velocity_grid
    inverse_direction BOOLEAN NOT NULL CHECK (inverse_direction IN (0, 1)), -- whether the PROJ grid direction is reversed w.r.t to the authority one (TRUE in that case)
    package_name TEXT,                              -- no longer used. Must be NULL
    url TEXT,                                       -- optional URL where to download the PROJ grid
    direct_download BOOLEAN CHECK (direct_download IN (0, 1)), -- whether the URL can be used directly (if 0, authentication etc might be needed)
    open_license BOOLEAN CHECK (open_license IN (0, 1)),
    directory TEXT,                                 -- optional directory where the file might be located

    CONSTRAINT fk_grid_alternatives_grid_packages FOREIGN KEY (package_name) REFERENCES grid_packages(package_name) ON DELETE CASCADE,
    CONSTRAINT check_grid_alternatives_grid_fromat CHECK (proj_grid_format IN ('GTiff', 'GTX', 'NTv2', 'JSON')),
    CONSTRAINT check_grid_alternatives_proj_method CHECK (proj_method IN ('gridshift', 'hgridshift', 'vgridshift', 'geoid_like', 'geocentricoffset', 'tinshift', 'velocity_grid', 'defmodel')),
    CONSTRAINT check_grid_alternatives_inverse_direction CHECK (NOT(proj_method = 'geoid_like' AND inverse_direction = 1)),
    CONSTRAINT check_grid_alternatives_package_name CHECK (package_name IS NULL),
    CONSTRAINT check_grid_alternatives_direct_download_url CHECK (NOT(direct_download IS NULL AND url IS NOT NULL)),
    CONSTRAINT check_grid_alternatives_open_license_url CHECK (NOT(open_license IS NULL AND url IS NOT NULL)),
    CONSTRAINT check_grid_alternatives_constraint_cdn CHECK (NOT(url LIKE 'https://cdn.proj.org/%' AND (direct_download = 0 OR open_license = 0 OR url != 'https://cdn.proj.org/' || proj_grid_name))),
    CONSTRAINT check_grid_alternatives_tinshift CHECK ((proj_grid_format != 'JSON' AND proj_method != 'tinshift') OR (proj_grid_format = 'JSON' AND proj_method = 'tinshift'))
) WITHOUT ROWID;

CREATE INDEX idx_grid_alternatives_proj_grid_name ON grid_alternatives(proj_grid_name);
CREATE INDEX idx_grid_alternatives_old_proj_grid_name ON grid_alternatives(old_proj_grid_name);

CREATE TABLE other_transformation(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    description TEXT,

    -- if method_auth_name = 'PROJ', method_code can be 'PROJString' for a
    -- PROJ string and then method_name is a PROJ string (typically a pipeline)
    -- if method_auth_name = 'PROJ', method_code can be 'WKT' for a
    -- PROJ string and then method_name is a WKT string (CoordinateOperation)
    method_auth_name TEXT NOT NULL CHECK (length(method_auth_name) >= 1),
    method_code INTEGER_OR_TEXT NOT NULL CHECK (length(method_code) >= 1),
    method_name TEXT NOT NULL CHECK (length(method_name) >= 2),

    source_crs_auth_name TEXT NOT NULL,
    source_crs_code INTEGER_OR_TEXT NOT NULL,
    target_crs_auth_name TEXT NOT NULL,
    target_crs_code INTEGER_OR_TEXT NOT NULL,

    accuracy FLOAT CHECK (accuracy >= 0),

    param1_auth_name TEXT,
    param1_code INTEGER_OR_TEXT,
    param1_name TEXT,
    param1_value FLOAT,
    param1_uom_auth_name TEXT,
    param1_uom_code INTEGER_OR_TEXT,

    param2_auth_name TEXT,
    param2_code INTEGER_OR_TEXT,
    param2_name TEXT,
    param2_value FLOAT,
    param2_uom_auth_name TEXT,
    param2_uom_code INTEGER_OR_TEXT,

    param3_auth_name TEXT,
    param3_code INTEGER_OR_TEXT,
    param3_name TEXT,
    param3_value FLOAT,
    param3_uom_auth_name TEXT,
    param3_uom_code INTEGER_OR_TEXT,

    param4_auth_name TEXT,
    param4_code INTEGER_OR_TEXT,
    param4_name TEXT,
    param4_value FLOAT,
    param4_uom_auth_name TEXT,
    param4_uom_code INTEGER_OR_TEXT,

    param5_auth_name TEXT,
    param5_code INTEGER_OR_TEXT,
    param5_name TEXT,
    param5_value FLOAT,
    param5_uom_auth_name TEXT,
    param5_uom_code INTEGER_OR_TEXT,

    param6_auth_name TEXT,
    param6_code INTEGER_OR_TEXT,
    param6_name TEXT,
    param6_value FLOAT,
    param6_uom_auth_name TEXT,
    param6_uom_code INTEGER_OR_TEXT,

    param7_auth_name TEXT,
    param7_code INTEGER_OR_TEXT,
    param7_name TEXT,
    param7_value FLOAT,
    param7_uom_auth_name TEXT,
    param7_uom_code INTEGER_OR_TEXT,

    interpolation_crs_auth_name TEXT,
    interpolation_crs_code INTEGER_OR_TEXT,

    operation_version TEXT, -- normally mandatory in OGC Topic 2 but optional here

    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),

    CONSTRAINT pk_other_transformation PRIMARY KEY (auth_name, code),
    --CONSTRAINT fk_other_transformation_coordinate_operation FOREIGN KEY (auth_name, code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_other_transformation_source_crs FOREIGN1 KEY (source_crs_auth_name, source_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_other_transformation_target_crs FOREIGN KEY (target_crs_auth_name, target_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param1_uom FOREIGN KEY (param1_uom_auth_name, param1_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param2_uom FOREIGN KEY (param2_uom_auth_name, param2_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param3_uom FOREIGN KEY (param3_uom_auth_name, param3_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param4_uom FOREIGN KEY (param4_uom_auth_name, param4_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param5_uom FOREIGN KEY (param5_uom_auth_name, param5_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param6_uom FOREIGN KEY (param6_uom_auth_name, param6_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_param7_uom FOREIGN KEY (param7_uom_auth_name, param7_uom_code) REFERENCES unit_of_measure(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT fk_other_transformation_interpolation_crs FOREIGN KEY (interpolation_crs_auth_name, interpolation_crs_code) REFERENCES geodetic_crs(auth_name, code) ON DELETE CASCADE,
    CONSTRAINT check_other_transformation_method CHECK (NOT (method_auth_name = 'PROJ' AND method_code NOT IN ('PROJString', 'WKT')))
) WITHOUT ROWID;

-- Note: in EPSG, the steps might be to be chained in reverse order, so we cannot
-- enforce that source_crs_code == step1.source_crs_code etc
CREATE TABLE concatenated_operation(
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    name TEXT NOT NULL CHECK (length(name) >= 2),

    description TEXT,

    source_crs_auth_name TEXT NOT NULL,
    source_crs_code INTEGER_OR_TEXT NOT NULL,
    target_crs_auth_name TEXT NOT NULL,
    target_crs_code INTEGER_OR_TEXT NOT NULL,

    accuracy FLOAT CHECK (accuracy >= 0),

    operation_version TEXT, -- normally mandatory in OGC Topic 2 but optional here

    deprecated BOOLEAN NOT NULL CHECK (deprecated IN (0, 1)),

    CONSTRAINT pk_concatenated_operation PRIMARY KEY (auth_name, code)
    --CONSTRAINT fk_concatenated_operation_coordinate_operation FOREIGN KEY (auth_name, code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_concatenated_operation_source_crs FOREIGN KEY (source_crs_auth_name, source_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
    --CONSTRAINT fk_concatenated_operation_target_crs FOREIGN KEY (target_crs_auth_name, target_crs_code) REFERENCES crs(auth_name, code) ON DELETE CASCADE,
) WITHOUT ROWID;

CREATE TABLE concatenated_operation_step(
    operation_auth_name TEXT NOT NULL CHECK (length(operation_auth_name) >= 1),
    operation_code INTEGER_OR_TEXT NOT NULL CHECK (length(operation_code) >= 1),
    step_number INTEGER NOT NULL CHECK (step_number >= 1),
    step_auth_name TEXT NOT NULL CHECK (length(step_auth_name) >= 1),
    step_code INTEGER_OR_TEXT NOT NULL CHECK (length(step_code) >= 1),
    step_direction TEXT DEFAULT NULL CHECK (step_direction IS NULL OR step_direction IN ('forward', 'reverse')), -- much needed extension to OGC Topic 2 ! If setting the direction on one step, it must be set on all steps.

    CONSTRAINT pk_concatenated_operation_step PRIMARY KEY (operation_auth_name, operation_code, step_number)
    --CONSTRAINT fk_concatenated_operation_step_to_operation FOREIGN KEY (step_auth_name, step_code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;


CREATE TABLE geoid_model(
    name TEXT NOT NULL,
    operation_auth_name TEXT NOT NULL,
    operation_code INTEGER_OR_TEXT NOT NULL,
    CONSTRAINT pk_geoid_model PRIMARY KEY (name, operation_auth_name, operation_code)
    -- CONSTRAINT fk_geoid_model_operation FOREIGN KEY (operation_auth_name, operation_code) REFERENCES coordinate_operation(auth_name, code) ON DELETE CASCADE
) WITHOUT ROWID;


CREATE TABLE alias_name(
    table_name TEXT NOT NULL CHECK (table_name IN (
        'unit_of_measure', 'celestial_body', 'ellipsoid',
        'extent', 'prime_meridian',
        'geodetic_datum', 'vertical_datum', 'engineering_datum',
        'geodetic_crs', 'projected_crs', 'vertical_crs', 'compound_crs',
        'engineering_crs',
        'conversion', 'grid_transformation',
        'helmert_transformation', 'other_transformation', 'concatenated_operation')),
    auth_name TEXT NOT NULL CHECK (length(auth_name) >= 1),
    code INTEGER_OR_TEXT NOT NULL CHECK (length(code) >= 1),
    alt_name TEXT NOT NULL CHECK (length(alt_name) >= 2),
    source TEXT
);

CREATE INDEX idx_alias_name_code ON alias_name(code);

-- For EPSG, used to track superseded coordinate operations.
CREATE TABLE supersession(
    superseded_table_name TEXT NOT NULL CHECK (superseded_table_name IN (
        'unit_of_measure', 'celestial_body', 'ellipsoid',
        'extent', 'prime_meridian',
        'geodetic_datum', 'vertical_datum', 'engineering_datum',
        'geodetic_crs', 'projected_crs', 'vertical_crs', 'compound_crs',
        'engineering_crs',
        'conversion', 'grid_transformation',
        'helmert_transformation', 'other_transformation', 'concatenated_operation')),
    superseded_auth_name TEXT NOT NULL,
    superseded_code INTEGER_OR_TEXT NOT NULL,
    replacement_table_name TEXT NOT NULL CHECK (replacement_table_name IN (
        'unit_of_measure', 'celestial_body', 'ellipsoid',
        'extent', 'prime_meridian',
        'geodetic_datum', 'vertical_datum', 'engineering_datum',
        'geodetic_crs', 'projected_crs', 'vertical_crs', 'compound_crs',
        'engineering_crs',
        'conversion', 'grid_transformation',
        'helmert_transformation', 'other_transformation', 'concatenated_operation')),
    replacement_auth_name TEXT NOT NULL,
    replacement_code INTEGER_OR_TEXT NOT NULL,
    source TEXT,
    same_source_target_crs BOOLEAN NOT NULL CHECK (same_source_target_crs IN (0, 1)) -- for transformations, whether the (source_crs, target_crs) of the replacement transfrm is the same as the superseded one
);

CREATE INDEX idx_supersession ON supersession(superseded_table_name, superseded_auth_name, superseded_code);


CREATE TABLE deprecation(
    table_name TEXT NOT NULL CHECK (table_name IN (
        'unit_of_measure', 'celestial_body', 'ellipsoid',
        'extent', 'prime_meridian',
        'geodetic_datum', 'vertical_datum', 'engineering_datum',
        'geodetic_crs', 'projected_crs', 'vertical_crs', 'compound_crs',
        'engineering_crs',
        'conversion', 'grid_transformation',
        'helmert_transformation', 'other_transformation', 'concatenated_operation')),
    deprecated_auth_name TEXT NOT NULL,
    deprecated_code INTEGER_OR_TEXT NOT NULL,
    replacement_auth_name TEXT NOT NULL,
    replacement_code INTEGER_OR_TEXT NOT NULL,
    source TEXT
);



CREATE VIEW coordinate_operation_view AS
    SELECT CAST('grid_transformation' AS TEXT) AS table_name, auth_name, code, name,
           description,
           method_auth_name, method_code, method_name, source_crs_auth_name,
           source_crs_code, target_crs_auth_name, target_crs_code,
           accuracy, deprecated FROM grid_transformation
    UNION ALL
    SELECT CAST('helmert_transformation' AS TEXT) AS table_name, auth_name, code, name,
           description,
           method_auth_name, method_code, method_name, source_crs_auth_name,
           source_crs_code, target_crs_auth_name, target_crs_code,
           accuracy, deprecated FROM helmert_transformation
    UNION ALL
    SELECT CAST('other_transformation' AS TEXT) AS table_name, auth_name, code, name,
           description,
           method_auth_name, method_code, method_name, source_crs_auth_name,
           source_crs_code, target_crs_auth_name, target_crs_code,
           accuracy, deprecated FROM other_transformation
    UNION ALL
    SELECT CAST('concatenated_operation' AS TEXT) AS table_name, auth_name, code, name,
           description,
           CAST(NULL AS TEXT) as method_auth_name, CAST(NULL AS INTEGER_OR_TEXT) as method_code, CAST(NULL AS TEXT) as method_name, source_crs_auth_name,
           source_crs_code, target_crs_auth_name, target_crs_code,
           accuracy, deprecated FROM concatenated_operation
;

CREATE VIEW coordinate_operation_with_conversion_view AS
    SELECT auth_name, code, name, description, table_name AS type, deprecated FROM coordinate_operation_view UNION ALL
    SELECT auth_name, code, name, description, CAST('conversion' AS TEXT) AS type, deprecated FROM conversion_table;

CREATE VIEW crs_view AS
    SELECT CAST('geodetic_crs' AS TEXT) AS table_name, auth_name, code, name, type,
           description,
           deprecated FROM geodetic_crs
    UNION ALL
    SELECT CAST('projected_crs' AS TEXT) AS table_name, auth_name, code, name, CAST('projected' AS TEXT),
           description,
           deprecated FROM projected_crs
    UNION ALL
    SELECT CAST('vertical_crs' AS TEXT) AS table_name, auth_name, code, name, CAST('vertical' AS TEXT),
           description,
           deprecated FROM vertical_crs
    UNION ALL
    SELECT CAST('compound_crs' AS TEXT) AS table_name, auth_name, code, name, CAST('compound' AS TEXT),
           description,
           deprecated FROM compound_crs
    UNION ALL
    SELECT CAST('engineering_crs' AS TEXT) AS table_name, auth_name, code, name, CAST('engineering' AS TEXT),
           description,
           deprecated FROM engineering_crs
;

CREATE VIEW object_view AS
    SELECT CAST('unit_of_measure' AS TEXT) AS table_name, auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM unit_of_measure
    UNION ALL
    SELECT CAST('celestial_body' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, CAST(0 AS BOOLEAN) AS deprecated FROM celestial_body
    UNION ALL
    SELECT CAST('ellipsoid' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM ellipsoid
    UNION ALL
    SELECT CAST('extent' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM extent
    UNION ALL
    SELECT CAST('prime_meridian' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM prime_meridian
    UNION ALL
    SELECT CAST('geodetic_datum' AS TEXT), auth_name, code, name, CAST(CASE WHEN ensemble_accuracy IS NOT NULL THEN 'ensemble' ELSE 'datum' END AS TEXT), deprecated FROM geodetic_datum
    UNION ALL
    SELECT CAST('vertical_datum' AS TEXT), auth_name, code, name, CAST(CASE WHEN ensemble_accuracy IS NOT NULL THEN 'ensemble' ELSE 'datum' END AS TEXT), deprecated FROM vertical_datum
    UNION ALL
    SELECT CAST('engineering_datum' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM engineering_datum
    UNION ALL
    SELECT CAST('axis' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, CAST(0 AS BOOLEAN) AS deprecated FROM axis
    UNION ALL
    SELECT table_name, auth_name, code, name, type, deprecated FROM crs_view
    UNION ALL
    SELECT CAST('conversion' AS TEXT), auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM conversion_table
    UNION ALL
    SELECT table_name, auth_name, code, name, CAST(NULL AS TEXT) as type, deprecated FROM coordinate_operation_view
;

CREATE VIEW authority_list AS
    SELECT DISTINCT auth_name FROM unit_of_measure
    UNION
    SELECT DISTINCT auth_name FROM celestial_body
    UNION
    SELECT DISTINCT auth_name FROM ellipsoid
    UNION
    SELECT DISTINCT auth_name FROM extent
    UNION
    SELECT DISTINCT auth_name FROM scope
    UNION
    SELECT DISTINCT auth_name FROM usage WHERE auth_name IS NOT NULL
    UNION
    SELECT DISTINCT auth_name FROM prime_meridian
    UNION
    SELECT DISTINCT auth_name FROM geodetic_datum
    UNION
    SELECT DISTINCT auth_name FROM vertical_datum
    UNION
    SELECT DISTINCT auth_name FROM engineering_datum
    UNION
    SELECT DISTINCT auth_name FROM axis
    UNION
    SELECT DISTINCT auth_name FROM crs_view
    UNION
    SELECT DISTINCT auth_name FROM coordinate_operation_view
;

-- Define the allowed authorities, and their precedence, when researching a
-- coordinate operation
CREATE TABLE authority_to_authority_preference(
    source_auth_name TEXT NOT NULL, -- 'any' for any source
    target_auth_name TEXT NOT NULL, -- 'any' for any target
    allowed_authorities TEXT NOT NULL,  -- for example 'PROJ,EPSG,any'
    CONSTRAINT unique_authority_to_authority_preference UNIQUE (source_auth_name, target_auth_name)
);

-- Map 'IAU_2015' to auth_name=IAU and version=2015
CREATE TABLE versioned_auth_name_mapping(
    versioned_auth_name    TEXT NOT NULL PRIMARY KEY,
    auth_name              TEXT NOT NULL,
    version                TEXT NOT NULL,
    priority               INTEGER NOT NULL,
    CONSTRAINT unique_auth_name_version UNIQUE (auth_name, version),
    CONSTRAINT unique_auth_name_priority UNIQUE (auth_name, priority)
);
