CREATE TABLE subject (
	id INTEGER PRIMARY KEY,
	characters TEXT,
	level INTEGER NOT NULL,
	object TEXT NOT NULL CHECK (object IN ('radical', 'kanji', 'vocabulary', 'kana_vocabulary')),
	slug TEXT NOT NULL,
	url TEXT NOT NULL,
	mnemonic_meaning TEXT,
	mnemonic_reading TEXT,
	hidden_at TEXT
);

CREATE TABLE components (
	id_component INTEGER NOT NULL,
	id_product INTEGER NOT NULL,
	FOREIGN KEY (id_component) REFERENCES subject(id) ON DELETE CASCADE,
	FOREIGN KEY (id_product) REFERENCES subject(id) ON DELETE CASCADE,
	PRIMARY KEY (id_component, id_product)
);

CREATE TABLE subject_reading (
	id INTEGER NOT NULL,
	reading TEXT NOT NULL,
	"primary" BOOLEAN NOT NULL,
	accepted BOOLEAN NOT NULL,
	type TEXT,
	FOREIGN KEY (id) REFERENCES subject(id) ON DELETE CASCADE,
	PRIMARY KEY (id, reading)
);

CREATE TABLE subject_meaning (
	id INTEGER NOT NULL,
	meaning TEXT NOT NULL,
	"primary" BOOLEAN NOT NULL,
	accepted BOOLEAN NOT NULL,
	FOREIGN KEY (id) REFERENCES subject(id) ON DELETE CASCADE,
	PRIMARY KEY (id, meaning)
);

CREATE TABLE assignment (
	assignment_id INTEGER PRIMARY KEY,
	subject_id INTEGER NOT NULL,
	srs INTEGER NOT NULL CHECK (srs BETWEEN 0 AND 9),
	hidden BOOLEAN NOT NULL,
	available_at TIMESTAMP,
	started_at TIMESTAMP,
	unlocked_at TIMESTAMP,
	FOREIGN KEY (subject_id) REFERENCES subject(id) ON DELETE RESTRICT
);
CREATE INDEX idx_assignment_subject_id ON assignment(subject_id);

CREATE TABLE review (
	assignment_id INTEGER PRIMARY KEY,
	incorrect_meaning_answers INTEGER,
	incorrect_reading_answers INTEGER,
	created_at TIMESTAMP,
	meaning_passed BOOLEAN,
	reading_passed BOOLEAN,
	FOREIGN KEY (assignment_id) REFERENCES assignment(assignment_id) ON DELETE CASCADE
);

CREATE TABLE lesson (
	assignment_id INTEGER PRIMARY KEY,
	started_at TIMESTAMP,
	FOREIGN KEY (assignment_id) REFERENCES assignment(assignment_id) ON DELETE CASCADE
);

/*
-- Consider enforcing mutual exclusivity of subtypes!

CREATE TRIGGER prevent_review_if_lesson
BEFORE INSERT ON review
WHEN EXISTS (SELECT 1 FROM lesson WHERE assignment_id = NEW.assignment_id )
BEGIN
    SELECT RAISE(FAIL, 'Cannot insert assignment into review, if its already present in lesson!');
END;

CREATE TRIGGER prevent_lesson_if_review
BEFORE INSERT ON lesson
WHEN EXISTS (SELECT 1 FROM review WHERE assignment_id = NEW.assignment_id )
BEGIN
    SELECT RAISE(FAIL, 'Cannot insert assignment into lesson, if its already present in review!');
END;

-- If implemented, dont forget to update the drop script!
*/

CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT
)
