# Permissions (seeded in V1)

Permissions are *capabilities*. "Scoped" rules (teacher: own subjects via `teacher_subjects`; student: enrolled subjects and own records) are enforced in the service layer on top of these. Notifications need no permission (any logged-in user). Assignment permissions arrive with the Assignments migration.
Super Admin has every permission except the student-self and teacher-dashboard ones, which have no meaning for that role. Super Admin can change the Admin/Teacher mappings through `ROLE_PERMISSION_MANAGE`.

| Permission | Description | Super Admin | Admin | Teacher | Student |
|---|---|:-:|:-:|:-:|:-:|
| `USER_ADMIN_MANAGE` | Create, update, deactivate admin accounts | ✓ |  |  |  |
| `ROLE_PERMISSION_MANAGE` | View and edit role permissions | ✓ |  |  |  |
| `AUDIT_LOG_VIEW` | View audit logs | ✓ |  |  |  |
| `SYSTEM_CONFIG_MANAGE` | Manage system configuration | ✓ |  |  |  |
| `APPLICATION_VIEW` | View student applications | ✓ | ✓ |  |  |
| `APPLICATION_REVIEW` | Approve or reject applications | ✓ | ✓ |  |  |
| `STUDENT_VIEW` | View student profiles (teachers: own subjects only) | ✓ | ✓ | ✓ |  |
| `STUDENT_MANAGE` | Edit student profiles and status | ✓ | ✓ |  |  |
| `STUDENT_PROFILE_VIEW_OWN` | View own profile and enrolments |  |  |  | ✓ |
| `TEACHER_VIEW` | View teachers | ✓ | ✓ |  |  |
| `TEACHER_MANAGE` | Create/edit teachers, assign subjects | ✓ | ✓ |  |  |
| `ACADEMIC_YEAR_MANAGE` | Create/edit/activate academic years | ✓ | ✓ |  |  |
| `SUBJECT_VIEW` | View subjects (teachers/students: scoped) | ✓ | ✓ | ✓ | ✓ |
| `SUBJECT_MANAGE` | Create/edit subjects | ✓ | ✓ |  |  |
| `ENROLLMENT_MANAGE` | Manage student subject enrolments | ✓ | ✓ |  |  |
| `MATERIAL_VIEW` | View learning materials (scoped) | ✓ | ✓ | ✓ | ✓ |
| `MATERIAL_MANAGE` | Upload/edit/delete materials (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `EXAM_VIEW` | View examinations (scoped) | ✓ | ✓ | ✓ | ✓ |
| `EXAM_MANAGE` | Create/edit examinations (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `EXAM_PUBLISH` | Publish, close booking, cancel examinations | ✓ | ✓ | ✓ |  |
| `SLOT_MANAGE` | Create/edit examination slots | ✓ | ✓ | ✓ |  |
| `BOOKING_CREATE` | Book an examination slot (student self) |  |  |  | ✓ |
| `BOOKING_VIEW_OWN` | View own bookings |  |  |  | ✓ |
| `BOOKING_VIEW_ALL` | View booking lists (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `BOOKING_MANAGE` | Cancel or move bookings | ✓ | ✓ |  |  |
| `ATTENDANCE_MANAGE` | Mark/correct attendance manually | ✓ | ✓ | ✓ |  |
| `ATTENDANCE_QR_GENERATE` | Generate QR attendance sessions | ✓ | ✓ | ✓ |  |
| `ATTENDANCE_QR_SCAN` | Scan QR to record own attendance |  |  |  | ✓ |
| `RESULT_ENTER` | Enter/update draft marks | ✓ | ✓ | ✓ |  |
| `RESULT_PUBLISH` | Publish examination results | ✓ | ✓ |  |  |
| `RESULT_EDIT_PUBLISHED` | Change published results (audited) | ✓ | ✓ |  |  |
| `RESULT_VIEW_ALL` | View all results (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `RESULT_VIEW_OWN` | View own published results |  |  |  | ✓ |
| `GRADE_CONFIG_MANAGE` | Manage grading scales | ✓ | ✓ |  |  |
| `PROGRESS_VIEW_OWN` | View own academic progress |  |  |  | ✓ |
| `PROGRESS_VIEW_ALL` | View student progress (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `FEEDBACK_MANAGE` | Write student feedback | ✓ | ✓ | ✓ |  |
| `FEEDBACK_VIEW_OWN` | View own feedback |  |  |  | ✓ |
| `ANNOUNCEMENT_PUBLISH_ALL` | Publish academy-wide announcements | ✓ | ✓ |  |  |
| `ANNOUNCEMENT_PUBLISH_SUBJECT` | Publish subject announcements (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `ANNOUNCEMENT_VIEW` | View relevant announcements | ✓ | ✓ | ✓ | ✓ |
| `REPORT_VIEW` | View reports (teachers: own subjects) | ✓ | ✓ | ✓ |  |
| `REPORT_EXPORT` | Export reports to PDF/Excel | ✓ | ✓ | ✓ |  |
| `DASHBOARD_ADMIN` | Admin dashboard | ✓ | ✓ |  |  |
| `DASHBOARD_TEACHER` | Teacher dashboard |  |  | ✓ |  |
| `DASHBOARD_STUDENT` | Student dashboard |  |  |  | ✓ |
