# REST API plan (all under `/api/v1`, JSON, OpenAPI at `/swagger-ui`)

Errors use one shape: `{ "timestamp", "status", "error", "message", "path", "fieldErrors": [] }`.

| Domain | Endpoints | Roles |
|---|---|---|
| Auth | `POST /auth/login`, `/auth/logout`, `/auth/set-password`, `/auth/forgot-password`, `/auth/reset-password`, `GET /auth/me` | public / any |
| Applications | `POST /applications` (public); `GET /applications`, `GET /applications/{id}`, `POST /applications/{id}/approve`, `/reject` | public; ADMIN+ |
| Students | `GET /students` (search, year, subject, paging), `GET/PUT /students/{id}`, `PATCH /students/{id}/status`, `GET /students/{id}/history` | ADMIN+; STUDENT self via `/me` |
| Teachers | `POST/GET/PUT /teachers`, `PATCH /teachers/{id}/status`, `PUT /teachers/{id}/subjects` | ADMIN+ |
| Academic years | `POST/GET/PUT /academic-years`, `PATCH /academic-years/{id}/active` | ADMIN+ |
| Subjects | `POST/GET/PUT /subjects`, `GET /subjects/{id}/students` | ADMIN+; TEACHER (own) |
| Enrollments | `POST /students/{id}/enrollments`, `DELETE /enrollments/{id}` (withdraw) | ADMIN+ |
| Materials | `POST/GET/PUT/DELETE /materials`, `POST /materials/{id}/files`, `GET /materials/files/{id}/view`, `/download`, `/categories` | ADMIN, TEACHER (own); STUDENT (enrolled, read) |
| Examinations | `POST/GET/PUT /exams`, `POST /exams/{id}/publish`, `/close-booking`, `/cancel` | ADMIN, TEACHER (own); STUDENT (enrolled, read) |
| Slots | `POST/PUT/DELETE /exams/{id}/slots`, `GET /exams/{id}/slots` | ADMIN, TEACHER (own) |
| Bookings | `POST /exams/{id}/bookings` (student, slot in body), `GET /bookings/me`, `GET /exams/{id}/bookings`, `POST /bookings/{id}/cancel`, `PUT /bookings/{id}/slot` | STUDENT book/view; ADMIN cancel/move |
| Attendance | `GET /slots/{id}/attendance`, `PUT /bookings/{id}/attendance`, `POST /slots/{id}/qr`, `POST /attendance/qr-scan` | ADMIN, TEACHER (own); STUDENT scan |
| Results | `PUT /exams/{id}/results` (bulk marks), `POST /exams/{id}/results/import`, `POST /exams/{id}/results/publish`, `GET /results/me`, `GET /exams/{id}/results` | ADMIN, TEACHER (own); STUDENT own published |
| Grades | `GET/POST /grade-configurations`, `PUT /grade-configurations/{id}/activate` | ADMIN+ |
| Progress | `GET /progress/me`, `GET /progress/me/subjects/{id}`, `GET /students/{id}/progress` | STUDENT self; ADMIN, TEACHER (own) |
| Feedback | `POST /feedback`, `GET /feedback/me`, `GET /students/{id}/feedback` | TEACHER (own), ADMIN; STUDENT own |
| Notifications | `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/{id}/read`, `/read-all` | any |
| Announcements | `POST/GET/DELETE /announcements` | ADMIN (academy-wide), TEACHER (own subjects); STUDENT read |
| Dashboards | `GET /dashboard/student`, `/dashboard/teacher`, `/dashboard/admin` | by role |
| Reports | `GET /reports/{type}?format=pdf|xlsx&year=&subject=&student=&exam=&from=&to=` | ADMIN+, TEACHER (own) |
| Audit | `GET /audit-logs` | SUPER_ADMIN |
| Admin users | `POST/GET/PUT /admin-users`, `PATCH /admin-users/{id}/status`, `GET/PUT /roles/{id}/permissions` | SUPER_ADMIN |
