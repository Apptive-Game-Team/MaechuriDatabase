-- 1. 기초 테이블 (참조가 없는 테이블부터 생성)
CREATE TABLE IF NOT EXISTS tag (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(31) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS asset (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(31) NOT NULL UNIQUE,
    final_url VARCHAR(255),
    prompt TEXT,
    raw_url VARCHAR(512),
    resized_url VARCHAR(512),
    status VARCHAR(20) DEFAULT 'COMPLETED'::character varying,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    embedding vector(1024)
);

CREATE TABLE IF NOT EXISTS items (
    id BIGSERIAL PRIMARY KEY,
    embedding vector(3)
);

-- 2. 시나리오 관련 기초 (순환 참조 방지를 위해 먼저 생성)
CREATE TABLE IF NOT EXISTS scenario (
    scenario_id BIGSERIAL PRIMARY KEY,
    difficulty VARCHAR(10) NOT NULL CONSTRAINT scenario_difficulty_check CHECK ((difficulty)::text = ANY (ARRAY['easy'::text, 'mid'::text, 'hard'::text])),
    theme VARCHAR(100) NOT NULL,
    tone VARCHAR(100) NOT NULL,
    language VARCHAR(10) DEFAULT 'ko'::character varying NOT NULL,
    incident_type VARCHAR(100) NOT NULL,
    incident_summary TEXT NOT NULL,
    incident_time_start TIME NOT NULL,
    incident_time_end TIME NOT NULL,
    primary_object VARCHAR(100) NOT NULL,
    crime_time_start TIME NOT NULL,
    crime_time_end TIME NOT NULL,
    crime_method TEXT NOT NULL,
    no_supernatural BOOLEAN DEFAULT TRUE NOT NULL,
    no_time_travel BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    incident_location_id BIGINT,
    crime_location_id BIGINT,
    date DATE
);

-- 3. 위치 정보 (시나리오 참조)
CREATE TABLE IF NOT EXISTS location (
    scenario_id BIGINT NOT NULL REFERENCES scenario ON DELETE CASCADE,
    location_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    can_see JSONB DEFAULT '[]'::jsonb,
    cannot_see JSONB DEFAULT '[]'::jsonb,
    access_requires VARCHAR(100),
    type VARCHAR(20) DEFAULT 'room'::character varying NOT NULL CONSTRAINT location_type_check CHECK ((type)::text = ANY (ARRAY['room'::text, 'corridor'::text])),
    x SMALLINT,
    y SMALLINT,
    width SMALLINT,
    height SMALLINT,
    floor_url VARCHAR(512),
    wall_url VARCHAR(512),
    PRIMARY KEY (scenario_id, location_id)
);

-- 4. 시나리오 테이블에 누락된 외래키 추가 (순환 참조 해결)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_scenario_incident_location') THEN
        ALTER TABLE scenario ADD CONSTRAINT fk_scenario_incident_location FOREIGN KEY (scenario_id, incident_location_id) REFERENCES location ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_scenario_crime_location') THEN
        ALTER TABLE scenario ADD CONSTRAINT fk_scenario_crime_location FOREIGN KEY (scenario_id, crime_location_id) REFERENCES location ON DELETE SET NULL;
    END IF;
END $$;

-- 5. 주요 게임 데이터 테이블
CREATE TABLE IF NOT EXISTS asset_tag (
    id BIGSERIAL PRIMARY KEY,
    tag_id BIGINT REFERENCES tag ON DELETE CASCADE,
    asset_id BIGINT REFERENCES asset ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS fact (
    scenario_id BIGINT NOT NULL REFERENCES scenario ON DELETE CASCADE,
    suspect_id BIGINT DEFAULT 0 NOT NULL,
    fact_id BIGINT NOT NULL,
    threshold INTEGER DEFAULT 0 NOT NULL,
    type VARCHAR(50) NOT NULL CONSTRAINT check_fact_type CHECK ((type)::text = ANY (ARRAY['secret'::text, 'hidden'::text, 'timeline'::text, 'heard'::text, 'incident'::text, 'location'::text, 'world'::text])),
    content JSONB NOT NULL,
    embedding vector(1024),
    PRIMARY KEY (scenario_id, fact_id)
);

CREATE TABLE IF NOT EXISTS furniture (
    id BIGSERIAL PRIMARY KEY,
    scenario_id BIGINT NOT NULL,
    location_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    origin_x INTEGER NOT NULL,
    origin_y INTEGER NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    assets_url VARCHAR(500),
    CONSTRAINT fk_furniture_location FOREIGN KEY (scenario_id, location_id) REFERENCES location ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_session (
    session_id VARCHAR(255) NOT NULL,
    scenario_id INTEGER NOT NULL REFERENCES scenario ON DELETE CASCADE,
    current_pressure INTEGER DEFAULT 0,
    suspect_pressures JSONB DEFAULT '{}'::jsonb,
    suspect_interactions JSONB DEFAULT '{}'::jsonb,
    clue_interactions JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    last_activity_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    clue_seen_ids JSONB,
    PRIMARY KEY (session_id, scenario_id)
);

CREATE TABLE IF NOT EXISTS game_session_record (
    id BIGSERIAL PRIMARY KEY,
    game_session_id VARCHAR(255) NOT NULL,
    scenario_id BIGINT NOT NULL,
    record_tag VARCHAR(10) NOT NULL,
    record_id BIGINT NOT NULL,
    interacted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT game_session_record_game_session_id_scenario_id_record_tag__key UNIQUE (game_session_id, scenario_id, record_tag, record_id)
);

CREATE TABLE IF NOT EXISTS suspect (
    scenario_id BIGINT NOT NULL REFERENCES scenario ON DELETE CASCADE,
    suspect_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(100) NOT NULL,
    age INTEGER NOT NULL,
    gender VARCHAR(20) NOT NULL,
    description TEXT NOT NULL,
    is_culprit BOOLEAN DEFAULT FALSE NOT NULL,
    motive TEXT,
    alibi_summary TEXT NOT NULL,
    speech_style VARCHAR(100) NOT NULL,
    emotional_tendency VARCHAR(100) NOT NULL,
    lying_pattern VARCHAR(50) NOT NULL,
    profile_embedding vector(1024),
    x SMALLINT,
    y SMALLINT,
    visual_description TEXT,
    location_id BIGINT,
    asset_id BIGINT,
    PRIMARY KEY (scenario_id, suspect_id),
    CONSTRAINT fk_suspect_location FOREIGN KEY (scenario_id, location_id) REFERENCES location ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS clue (
    scenario_id BIGINT NOT NULL REFERENCES scenario ON DELETE CASCADE,
    clue_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    logic_explanation TEXT NOT NULL,
    is_red_herring BOOLEAN DEFAULT FALSE NOT NULL,
    decoded_answer TEXT,
    description_embedding vector(1024),
    logic_embedding vector(1024),
    location_id BIGINT NOT NULL,
    related_suspect_ids JSONB,
    x SMALLINT,
    y SMALLINT,
    visual_description TEXT,
    asset_id BIGINT,
    PRIMARY KEY (scenario_id, clue_id),
    CONSTRAINT clue_location_fk FOREIGN KEY (scenario_id, location_id) REFERENCES location ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_message_embedding (
    id BIGSERIAL PRIMARY KEY,
    scenario_id BIGINT NOT NULL REFERENCES scenario ON DELETE CASCADE,
    session_id VARCHAR(36) NOT NULL,
    suspect_id BIGINT,
    clue_id BIGINT,
    message_index INTEGER NOT NULL,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1024),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 6. 인덱스 (IF NOT EXISTS 구문으로 반복 실행 가능하게 처리)
CREATE INDEX IF NOT EXISTS idx_asset_name ON asset (name);
CREATE INDEX IF NOT EXISTS idx_asset_embedding ON asset USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_game_session_record_session_id ON game_session_record (game_session_id);
CREATE INDEX IF NOT EXISTS idx_game_session_record_session_scenario ON game_session_record (game_session_id, scenario_id);
CREATE INDEX IF NOT EXISTS idx_chat_message_embedding ON chat_message_embedding USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_chat_message_scenario_session ON chat_message_embedding (scenario_id, session_id);
CREATE INDEX IF NOT EXISTS idx_chat_message_suspect ON chat_message_embedding (scenario_id, suspect_id) WHERE (suspect_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_chat_message_clue ON chat_message_embedding (scenario_id, clue_id) WHERE (clue_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_clue_red_herring ON clue (scenario_id, is_red_herring);
CREATE INDEX IF NOT EXISTS idx_clue_description_embedding ON clue USING hnsw (description_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_clue_logic_embedding ON clue USING hnsw (logic_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_fact_embedding ON fact USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_furniture_scenario ON furniture (scenario_id);
CREATE INDEX IF NOT EXISTS idx_location_type ON location (scenario_id, type);
CREATE INDEX IF NOT EXISTS idx_suspect_profile_embedding ON suspect USING hnsw (profile_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_suspect_culprit ON suspect (scenario_id, is_culprit);
