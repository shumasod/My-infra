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
