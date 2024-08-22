-- Create the database
CREATE DATABASE hawaiian_motif;
\c hawaiian_motif;

-- Create the tables
CREATE TABLE islands (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  area_sq_km DECIMAL(10, 2),
  population INT
);

CREATE TABLE beaches (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  island_id INT NOT NULL,
  description TEXT,
  FOREIGN KEY (island_id) REFERENCES islands(id)
);

CREATE TABLE activities (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT
);

CREATE TABLE beach_activities (
  beach_id INT NOT NULL,
  activity_id INT NOT NULL,
  PRIMARY KEY (beach_id, activity_id),
  FOREIGN KEY (beach_id) REFERENCES beaches(id),
  FOREIGN KEY (activity_id) REFERENCES activities(id)
);

CREATE TABLE resorts (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  island_id INT NOT NULL,
  rating DECIMAL(2, 1),
  FOREIGN KEY (island_id) REFERENCES islands(id)
);


-- Create a table to hold the ASCII art
CREATE TABLE hawaiian_art (
    id SERIAL PRIMARY KEY,
    art TEXT
);

-- Insert a simple Hawaiian-themed ASCII art
INSERT INTO hawaiian_art (art) VALUES
('
    _  _   _  _  _   _   _  _  _   _  _  _  
  (_) (_) (_)(_) (_)(_) (_)(_)(_) (_) (_)(_) 
  (_)  (_)   (_)   (_) (_)   (_)    (_)  (_) 
  (_)  (_)   (_)   (_) (_)   (_)    (_)  (_) 
  (_)  (_)   (_)   (_) (_)   (_)    (_)  (_) 
  (_)  (_)   (_)   (_) (_)   (_)    (_)  (_) 
  (_) (_)   (_) (_)  (_)   (_)    (_)  (_) 
     (_)   (_)   (_)   (_) (_)  (_)   (_) (_) 
');

-- Display the art
SELECT art FROM hawaiian_art;

