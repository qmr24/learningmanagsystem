-- V1: core schema (MySQL 8, InnoDB, utf8mb4). Assignments are added in a later migration.
-- Academic year of a student/exam/material is derived through subject -> academic_year,
-- so year data lives in exactly one place and history is never overwritten.

-- ---------- Identity & access ----------
CREATE TABLE roles (
  id TINYINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL UNIQUE            -- SUPER_ADMIN, ADMIN, TEACHER, STUDENT
);
CREATE TABLE permissions (
  id SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(80) NOT NULL UNIQUE,
  description VARCHAR(255)
);
CREATE TABLE role_permissions (
  role_id TINYINT UNSIGNED NOT NULL,
  permission_id SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  FOREIGN KEY (role_id) REFERENCES roles(id),
  FOREIGN KEY (permission_id) REFERENCES permissions(id)
);
CREATE TABLE users (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(60) NOT NULL UNIQUE,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NULL,            -- NULL until account setup completed
  role_id TINYINT UNSIGNED NOT NULL,
  status ENUM('PENDING','ACTIVE','INACTIVE','SUSPENDED') NOT NULL DEFAULT 'PENDING',
  failed_login_attempts INT NOT NULL DEFAULT 0,
  locked_until DATETIME NULL,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES roles(id),
  INDEX idx_users_role_status (role_id, status)
);
CREATE TABLE password_tokens (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,        -- SHA-256 of the emailed token
  purpose ENUM('SET_PASSWORD','RESET_PASSWORD') NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_pwtok_user (user_id)
);

-- ---------- Academic structure ----------
CREATE TABLE academic_years (
  id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  year_number SMALLINT UNSIGNED NOT NULL UNIQUE,   -- 2027
  label VARCHAR(40) NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE subjects (
  id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  academic_year_id INT UNSIGNED NOT NULL,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(120) NOT NULL,
  description TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
  UNIQUE KEY uq_subject_year_code (academic_year_id, code),
  UNIQUE KEY uq_subject_year_name (academic_year_id, name)
);
CREATE TABLE teachers (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE TABLE teacher_subjects (
  teacher_id BIGINT UNSIGNED NOT NULL,
  subject_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (teacher_id, subject_id),
  FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id)
);

-- ---------- Applications & students ----------
CREATE TABLE student_applications (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  full_name VARCHAR(150) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender ENUM('MALE','FEMALE','OTHER') NOT NULL,
  email VARCHAR(190) NOT NULL,
  mobile VARCHAR(30) NOT NULL,
  home_address VARCHAR(300) NOT NULL,
  school_name VARCHAR(150) NOT NULL,
  academic_year_id INT UNSIGNED NOT NULL,
  guardian_name VARCHAR(150) NOT NULL,
  guardian_phone VARCHAR(30) NOT NULL,
  guardian_email VARCHAR(190) NULL,
  status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  reject_reason VARCHAR(500) NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- duplicate guard: one non-rejected application per email per year
  open_email_key VARCHAR(190) AS (CASE WHEN status = 'REJECTED' THEN NULL ELSE LOWER(email) END) STORED,
  FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
  FOREIGN KEY (reviewed_by) REFERENCES users(id),
  UNIQUE KEY uq_app_year_email (academic_year_id, open_email_key),
  INDEX idx_app_status (status, created_at)
);
CREATE TABLE application_subjects (
  application_id BIGINT UNSIGNED NOT NULL,
  subject_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (application_id, subject_id),
  FOREIGN KEY (application_id) REFERENCES student_applications(id) ON DELETE CASCADE,
  FOREIGN KEY (subject_id) REFERENCES subjects(id)
);
CREATE TABLE student_id_sequences (
  year_number SMALLINT UNSIGNED PRIMARY KEY,
  last_no INT UNSIGNED NOT NULL DEFAULT 0      -- row-locked (FOR UPDATE) on approval
);
CREATE TABLE students (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  student_code VARCHAR(20) NOT NULL UNIQUE,    -- 2027STU001
  application_id BIGINT UNSIGNED NULL UNIQUE,
  full_name VARCHAR(150) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender ENUM('MALE','FEMALE','OTHER') NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  mobile VARCHAR(30) NOT NULL,
  home_address VARCHAR(300) NOT NULL,
  school_name VARCHAR(150) NOT NULL,
  status ENUM('ACTIVE','INACTIVE','SUSPENDED','GRADUATED') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (application_id) REFERENCES student_applications(id),
  INDEX idx_students_name (full_name),
  INDEX idx_students_status (status)
);
CREATE TABLE student_guardians (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(190) NULL,
  relationship VARCHAR(40) NULL,
  FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
);
CREATE TABLE student_enrollments (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  subject_id INT UNSIGNED NOT NULL,            -- subject belongs to one academic year
  status ENUM('ACTIVE','WITHDRAWN') NOT NULL DEFAULT 'ACTIVE',
  enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  UNIQUE KEY uq_enrollment (student_id, subject_id),
  INDEX idx_enroll_subject (subject_id, status)
);

-- ---------- Learning materials ----------
CREATE TABLE material_categories (
  id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  subject_id INT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  UNIQUE KEY uq_cat_subject_name (subject_id, name)
);
CREATE TABLE learning_materials (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  subject_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  access_mode ENUM('VIEW_ONLY','DOWNLOAD_ONLY','VIEW_AND_DOWNLOAD') NOT NULL DEFAULT 'VIEW_ONLY',
  visibility ENUM('DRAFT','PUBLISHED','HIDDEN') NOT NULL DEFAULT 'DRAFT',
  publish_at DATETIME NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  FOREIGN KEY (category_id) REFERENCES material_categories(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  INDEX idx_mat_subject (subject_id, visibility, publish_at),
  FULLTEXT KEY ft_mat_title (title, description)
);
CREATE TABLE material_files (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  material_id BIGINT UNSIGNED NOT NULL,
  kind ENUM('FILE','EXTERNAL_LINK') NOT NULL,
  original_name VARCHAR(255) NULL,
  stored_name CHAR(36) NULL UNIQUE,            -- random UUID; real path never exposed
  mime_type VARCHAR(100) NULL,
  size_bytes BIGINT UNSIGNED NULL,
  sha256 CHAR(64) NULL,
  external_url VARCHAR(500) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  FOREIGN KEY (material_id) REFERENCES learning_materials(id) ON DELETE CASCADE,
  CHECK ((kind = 'FILE' AND stored_name IS NOT NULL) OR (kind = 'EXTERNAL_LINK' AND external_url IS NOT NULL))
);

-- ---------- Examinations, slots, bookings, attendance ----------
CREATE TABLE examinations (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  subject_id INT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  exam_type ENUM('MCQ','STRUCTURED') NOT NULL,
  duration_minutes INT UNSIGNED NOT NULL,
  total_marks DECIMAL(6,2) NOT NULL,
  passing_marks DECIMAL(6,2) NOT NULL,
  instructions TEXT NULL,
  status ENUM('DRAFT','PUBLISHED','BOOKING_OPEN','BOOKING_CLOSED','ONGOING','COMPLETED','RESULTS_PUBLISHED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  booking_opens_at DATETIME NULL,
  booking_closes_at DATETIME NULL,
  published_at DATETIME NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  CHECK (total_marks > 0 AND passing_marks >= 0 AND passing_marks <= total_marks),
  INDEX idx_exam_subject_status (subject_id, status),
  INDEX idx_exam_title (title)
);
CREATE TABLE exam_slots (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  examination_id BIGINT UNSIGNED NOT NULL,
  slot_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  capacity SMALLINT UNSIGNED NOT NULL DEFAULT 20,
  booked_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- changed only under row lock
  status ENUM('OPEN','CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  FOREIGN KEY (examination_id) REFERENCES examinations(id) ON DELETE CASCADE,
  UNIQUE KEY uq_slot (examination_id, slot_date, start_time),
  CHECK (end_time > start_time),
  CHECK (booked_count <= capacity)                       -- last line of defence
);
CREATE TABLE exam_bookings (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  examination_id BIGINT UNSIGNED NOT NULL,
  slot_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  status ENUM('CONFIRMED','CANCELLED_BY_ADMIN') NOT NULL DEFAULT 'CONFIRMED',
  booked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cancelled_by BIGINT UNSIGNED NULL,
  cancelled_at DATETIME NULL,
  cancel_reason VARCHAR(300) NULL,
  -- one CONFIRMED booking per student per exam; cancelled rows kept as history
  active_key TINYINT AS (CASE WHEN status = 'CONFIRMED' THEN 1 ELSE NULL END) STORED,
  FOREIGN KEY (examination_id) REFERENCES examinations(id),
  FOREIGN KEY (slot_id) REFERENCES exam_slots(id),
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (cancelled_by) REFERENCES users(id),
  UNIQUE KEY uq_one_active_booking (examination_id, student_id, active_key),
  INDEX idx_booking_slot (slot_id, status),
  INDEX idx_booking_student (student_id)
);
CREATE TABLE attendance_qr_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  slot_id BIGINT UNSIGNED NOT NULL,
  signing_secret VARCHAR(64) NOT NULL,         -- per-session HMAC key
  valid_from DATETIME NOT NULL,
  valid_until DATETIME NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (slot_id) REFERENCES exam_slots(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  INDEX idx_qr_slot (slot_id)
);
CREATE TABLE exam_attendance (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL UNIQUE,  -- prevents duplicate attendance
  student_id BIGINT UNSIGNED NOT NULL,
  examination_id BIGINT UNSIGNED NOT NULL,
  slot_id BIGINT UNSIGNED NOT NULL,
  status ENUM('PRESENT','ABSENT') NOT NULL,
  method ENUM('MANUAL','QR') NOT NULL,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  recorded_by BIGINT UNSIGNED NULL,            -- staff for MANUAL; NULL for QR self-scan
  FOREIGN KEY (booking_id) REFERENCES exam_bookings(id),
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (examination_id) REFERENCES examinations(id),
  FOREIGN KEY (slot_id) REFERENCES exam_slots(id),
  FOREIGN KEY (recorded_by) REFERENCES users(id),
  INDEX idx_att_exam (examination_id, status)
);

-- ---------- Grades, results, feedback ----------
CREATE TABLE grade_configurations (
  id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  effective_from DATE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE grade_boundaries (
  id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  configuration_id INT UNSIGNED NOT NULL,
  grade VARCHAR(5) NOT NULL,
  min_percent DECIMAL(5,2) NOT NULL,
  max_percent DECIMAL(5,2) NOT NULL,
  FOREIGN KEY (configuration_id) REFERENCES grade_configurations(id) ON DELETE CASCADE,
  UNIQUE KEY uq_grade (configuration_id, grade),
  CHECK (min_percent <= max_percent)
);
CREATE TABLE exam_results (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  examination_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  is_absent BOOLEAN NOT NULL DEFAULT FALSE,
  marks_obtained DECIMAL(6,2) NULL,
  total_marks DECIMAL(6,2) NOT NULL,
  percentage DECIMAL(5,2) NULL,
  grade VARCHAR(5) NULL,                       -- stored at publish time so history is stable
  grade_configuration_id INT UNSIGNED NULL,
  teacher_feedback TEXT NULL,
  status ENUM('DRAFT','PUBLISHED') NOT NULL DEFAULT 'DRAFT',
  entered_by BIGINT UNSIGNED NOT NULL,
  published_by BIGINT UNSIGNED NULL,
  published_at DATETIME NULL,
  version INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (examination_id) REFERENCES examinations(id),
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (grade_configuration_id) REFERENCES grade_configurations(id),
  FOREIGN KEY (entered_by) REFERENCES users(id),
  FOREIGN KEY (published_by) REFERENCES users(id),
  UNIQUE KEY uq_result (examination_id, student_id),
  INDEX idx_result_student (student_id, status),
  CHECK (marks_obtained IS NULL OR (marks_obtained >= 0 AND marks_obtained <= total_marks))
);
CREATE TABLE exam_result_history (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  result_id BIGINT UNSIGNED NOT NULL,
  old_marks DECIMAL(6,2) NULL,
  new_marks DECIMAL(6,2) NULL,
  old_grade VARCHAR(5) NULL,
  new_grade VARCHAR(5) NULL,
  reason VARCHAR(300) NULL,
  changed_by BIGINT UNSIGNED NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (result_id) REFERENCES exam_results(id),
  FOREIGN KEY (changed_by) REFERENCES users(id),
  INDEX idx_hist_result (result_id)
);
CREATE TABLE academic_feedback (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  subject_id INT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NULL,
  given_by BIGINT UNSIGNED NOT NULL,
  strengths TEXT NULL,
  improvements TEXT NULL,
  recommendations TEXT NULL,
  comments TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  FOREIGN KEY (teacher_id) REFERENCES teachers(id),
  FOREIGN KEY (given_by) REFERENCES users(id),
  INDEX idx_fb_student_subject (student_id, subject_id)
);

-- ---------- Communication & audit ----------
CREATE TABLE announcements (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  subject_id INT UNSIGNED NULL,                -- NULL = academy-wide
  created_by BIGINT UNSIGNED NOT NULL,
  published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (subject_id) REFERENCES subjects(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  INDEX idx_ann_subject (subject_id, published_at)
);
CREATE TABLE notifications (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(200) NOT NULL,
  message VARCHAR(500) NOT NULL,
  link VARCHAR(255) NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notif_user (user_id, is_read, created_at)
);
CREATE TABLE email_outbox (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  to_email VARCHAR(190) NOT NULL,
  subject VARCHAR(250) NOT NULL,
  body MEDIUMTEXT NOT NULL,
  status ENUM('PENDING','SENT','FAILED') NOT NULL DEFAULT 'PENDING',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  last_error VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at DATETIME NULL,
  INDEX idx_outbox_status (status, created_at)
);
CREATE TABLE audit_logs (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  entity_type VARCHAR(60) NOT NULL,
  entity_id VARCHAR(40) NULL,
  old_value JSON NULL,
  new_value JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_entity (entity_type, entity_id),
  INDEX idx_audit_user (user_id, created_at)
);

-- ---------- Seed data ----------
INSERT INTO roles (name) VALUES ('SUPER_ADMIN'),('ADMIN'),('TEACHER'),('STUDENT');

-- Default grading scale (editable by admins; boundaries are data, not code)
INSERT INTO grade_configurations (name, effective_from, is_active) VALUES ('Default scale', '2020-01-01', TRUE);
INSERT INTO grade_boundaries (configuration_id, grade, min_percent, max_percent) VALUES
 (1,'A',75.00,100.00),(1,'B',65.00,74.99),(1,'C',50.00,64.99),(1,'S',35.00,49.99),(1,'W',0.00,34.99);
