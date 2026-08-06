CREATE TABLE IF NOT EXISTS notes (
  id SERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO notes (content) VALUES
  ('First test note from seed script'),
  ('Second note - checking read API'),
  ('Third note - kiem tra order by id desc'),
  ('Fourth note for pagination test'),
  ('Fifth note - final seed row');