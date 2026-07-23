# แผนงานระบบจัดการงาน (Task Board System) และโครงสร้างฐานข้อมูล

ข้อมูลนี้ระบุรายละเอียดของระบบจัดการงาน (Tasks) และสคีมาฐานข้อมูลทั้งหมดของระบบ เพื่อเป็นข้อมูลอ้างอิงในการพัฒนาซอฟต์แวร์

---

## 1. โครงสร้างฐานข้อมูล (Database Schema)

```sql
-- 1. ตารางผู้ใช้ (Users)
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  auth_id uuid NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  first_name text NOT NULL DEFAULT ''::text,
  last_name text NOT NULL DEFAULT ''::text,
  department text NOT NULL DEFAULT ''::text,
  position text NOT NULL DEFAULT ''::text,
  role text NOT NULL DEFAULT 'employee'::text CHECK (role = ANY (ARRAY['employee'::text, 'admin'::text])),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'disabled'::text])),
  device_id text,
  avatar_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  face_embedding USER-DEFINED,
  fcm_token text,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- 2. ตารางสถานที่ทำงาน (Work Locations)
CREATE TABLE public.work_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  radius_m integer NOT NULL DEFAULT 50,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT work_locations_pkey PRIMARY KEY (id)
);

-- 3. ตารางการลงเวลาทำงาน (Attendance)
CREATE TABLE public.attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  check_in_at timestamp with time zone,
  check_out_at timestamp with time zone,
  status text NOT NULL DEFAULT 'on_time'::text CHECK (status = ANY (ARRAY['on_time'::text, 'late'::text, 'no_record'::text, 'offsite'::text, 'sick_leave_full'::text, 'sick_leave_morning'::text, 'sick_leave_afternoon'::text, 'personal_leave_full'::text, 'personal_leave_morning'::text, 'personal_leave_afternoon'::text, 'annual_leave'::text, 'shift_swap'::text, 'unknown'::text])),
  check_in_lat numeric,
  check_in_lng numeric,
  check_out_lat numeric,
  check_out_lng numeric,
  check_in_photo text,
  check_out_photo text,
  location_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attendance_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT attendance_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.work_locations(id)
);

-- 4. ตารางขออนุมัติลา (Leave Requests)
CREATE TABLE public.leave_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  leave_type text NOT NULL,
  duration text DEFAULT 'เต็มวัน'::text,
  swap_date date,
  reason text DEFAULT ''::text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  medical_cert_url text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT leave_requests_pkey PRIMARY KEY (id),
  CONSTRAINT leave_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT leave_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id)
);

-- 5. ตารางขออนุมัติทำงานนอกสถานที่ (Offsite Requests)
CREATE TABLE public.offsite_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  reason text NOT NULL DEFAULT ''::text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT offsite_requests_pkey PRIMARY KEY (id),
  CONSTRAINT offsite_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT offsite_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id)
);

-- 6. ตารางวันหยุดนักขัตฤกษ์ (Holidays)
CREATE TABLE public.holidays (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  date date NOT NULL,
  name text NOT NULL,
  num_days integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT holidays_pkey PRIMARY KEY (id)
);

-- 7. ตารางโควตาวันลา (Leave Quotas)
CREATE TABLE public.leave_quotas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  year integer NOT NULL,
  sick_leave integer NOT NULL DEFAULT 30,
  personal_leave integer NOT NULL DEFAULT 6,
  annual_leave integer NOT NULL DEFAULT 6,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT leave_quotas_pkey PRIMARY KEY (id),
  CONSTRAINT leave_quotas_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- 8. ตารางงาน/บอร์ดงาน (Tasks)
CREATE TABLE public.tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assigned_to uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  due_date date,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'completed'::text])),
  assigned_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tasks_pkey PRIMARY KEY (id),
  CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.users(id),
  CONSTRAINT tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id)
);

-- 9. ตารางแจ้งเตือน (Notifications) — migration: 004_notifications.sql
-- เก็บประวัติแจ้งเตือนทุกประเภทของแต่ละพนักงาน (in-app + push history)
CREATE TABLE public.notifications (
  id         uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL,
  title      text        NOT NULL,
  body       text        NOT NULL DEFAULT ''::text,
  type       text        NOT NULL DEFAULT 'system'::text, -- 'leave' | 'attendance' | 'system' | 'announcement'
  is_read    boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX idx_notifications_user_id_created
  ON public.notifications (user_id, created_at DESC);
```

---

## 2. แผนงานระบบจัดการงาน (Task Board System Workflow)

การจัดการงานในแอปพลิเคชันจะอิงตามสถานะของตาราง `tasks` ทั้งหมด 3 สถานะดังนี้:

*   **`pending` (To Do):** รายการงานที่ถูกมอบหมาย แต่ยังไม่มีการเริ่มดำเนินงาน
*   **`in_progress` (Doing):** งานที่พนักงานกำลังลงมือทำและกำลังดำเนินการอยู่
*   **`completed` (Done):** งานที่ดำเนินการเสร็จสิ้นเรียบร้อยแล้ว

### การแสดงผลและการควบคุม
1. **สิทธิ์และการสร้างงาน (Multi-User Task Creation):** พนักงานทุกคนสามารถสร้างงานใหม่ และเชิญสมาชิก (Assignees) เข้าร่วมบอร์ดงานได้
2. **การแยกหมวดหมู่ด้วย TabBar 2 แท็บ:**
   - **งานที่เราสร้าง (`assigned_by == currentUserId`):** แสดงงานที่เราเป็นเจ้าของและเป็นผู้สร้าง
   - **งานที่เข้าร่วม (`assigned_by != currentUserId`):** แสดงงานที่เพื่อนร่วมงานสร้างแล้วเชิญเราเข้าร่วม
3. **บอร์ดงานสไตล์ Kanban:** แบ่งแถวแสดงสถานะคอลัมน์และปรับแต่งการ์ดย่อยในรูปแบบมินิบอร์ด
4. **การย้ายสถานะ:** มีฟังก์ชันลากวางการ์ดงาน (Drag & Drop) หรือปุ่มกดเพื่อเปลี่ยนค่าฟิลด์ `status` ในตาราง `tasks` โดยตรง

