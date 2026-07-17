# 🏗️ มาตรฐานสถาปัตยกรรมและการแยกโค้ด (NexHR Architecture & Code Separation Standards)

เอกสารนี้ระบุมาตรฐานในการจัดเก็บไฟล์และการแยกเลเยอร์การทำงาน (Separation of Concerns) ของระบบ NexHR เพื่อให้โค้ดมีความเป็นระเบียบ อ่านง่าย ขยายระบบง่าย และเป็นไปตามมาตรฐานการพัฒนาซอฟต์แวร์ที่ดี

---

## 📱 1. โครงสร้างและการแยกโค้ดฝั่งแอปมือถือ (Flutter Frontend)

ฝั่ง Flutter ใช้โครงสร้างสถาปัตยกรรมแบบ **Layered Architecture** แยกออกเป็น 5 โฟลเดอร์หลักใน `lib/`:

```
lib/
├── config/       # การโหลดและตั้งค่าตัวแปรระดับแอป
├── models/       # โครงสร้างข้อมูล (Data Model Class)
├── services/     # ตรรกะการประมวลผลและการเรียก API (Business Logic Layer)
├── screens/      # หน้าจอแสดงผลหลักและการจัดการสถานะ (Page/Screen Layer)
└── widgets/      # ส่วนประกอบย่อยหน้าจอสำหรับนำกลับมาใช้ซ้ำ (Reusable UI Components)
```

### 📋 กฎเหล็กของการแยกโค้ด (Rules of Separation)
1. **Model Layer (`lib/models/`)**:
   * มีหน้าที่แค่กำหนดคุณสมบัติ (Properties) และการแปลงค่าจาก JSON (`fromJson`) เท่านั้น
   * **ห้าม** มีโค้ดเรียกใช้งาน API หรือ logic ซับซ้อนภายในโมเดล
2. **Service Layer (`lib/services/`)**:
   * มีหน้าที่เรียกใช้งาน HTTP (Dio), จัดเก็บข้อมูลถาวร (Secure Storage) หรือประมวลผล AI/ML (Face Recognition)
   * **ห้าม** อ้างอิงโค้ดประเภท UI เด็ดขาด (ห้าม `import 'package:flutter/material.dart'` และห้ามอ้างอิง `BuildContext`)
   * หากเกิดความล้มเหลว ให้โยนเป็น `Exception` ขึ้นไปให้ฝั่ง UI จัดการ
3. **Screen Layer (`lib/screens/`)**:
   * มีหน้าที่ประสานงานระหว่าง UI และข้อมูลที่ดึงมาจาก Services
   * **ห้าม** เขียนโค้ดเชื่อมต่อ HTTP หรือส่งข้อมูลเข้าเซิร์ฟเวอร์โดยไม่ผ่าน Service Layer
4. **Widget Layer (`lib/widgets/`)**:
   * เป็น Component ย่อยที่ควรเป็น `StatelessWidget` เพื่อนำไปใช้งานซ้ำในหน้าจอต่างๆ เช่น ปุ่มกดที่ทำขึ้นมาเอง, การ์ดแสดงข้อมูล
   * การส่งค่ากลับไปหน้าหลักให้ใช้ระบบ Callback (`VoidCallback` หรือ `ValueChanged<T>`)

---

## ⚙️ 2. โครงสร้างและการแยกโค้ดฝั่งระบบหลังบ้าน (Go Backend)

ฝั่งระบบหลังบ้านใช้มาตรฐานการทำงานแบบ **Handler-Service-Repository** เพื่อแบ่งหน้าที่การคุยกับฐานข้อมูลและตรรกะทางธุรกิจออกจากกันอย่างสิ้นเชิง:

```
backend/
├── cmd/
│   └── api/                # จุดเริ่มต้นแอปพลิเคชัน (main.go)
└── internal/
    ├── config/             # การประมวลผลตัวแปรระบบ (.env)
    ├── handler/            # ส่วนรับส่ง HTTP Requests & JSON Response (Gin Gonic)
    ├── service/            # ส่วนประมวลผลตรรกะทางธุรกิจหลัก (Business Logic)
    └── repository/         # ส่วนประมวลผลฐานข้อมูลและคิวรี SQL (Data Access Layer)
```

### 📋 กฎเหล็กของการแยกโค้ด (Rules of Separation)
1. **Repository Layer**:
   * มีหน้าที่ส่ง SQL Queries ไปทำงานบน PostgreSQL และดึงข้อมูลดิบกลับมาแปลงเป็น Entity ในภาษา Go เท่านั้น
   * **ห้าม** เขียนตรรกะประเมินผล หรือการตัดสินใจที่เกี่ยวข้องกับนโยบายบริษัทในเลเยอร์นี้
2. **Service Layer**:
   * คอยคำนวณและประมวลผลต่างๆ เช่น การคำนวณหารัศมี GPS ว่าพนักงานอยู่ในระยะ Geofence หรือไม่
   * **ห้าม** ยุ่งเกี่ยวกับ Request Object หรือ Response Object ของเฟรมเวิร์กเว็บ (Gin Context)
3. **Handler Layer**:
   * มีหน้าที่ตรวจสอบสิทธิ์ (Middleware/JWT), แกะตัวแปรจาก JSON, ส่งตัวแปรไปให้เลเยอร์ Service ทำงาน และคืนค่า JSON Response ที่จัดรูปแบบแล้วกลับไปยังฝั่งคลอนต์
   * **ห้าม** เขียนคำสั่งติดต่อฐานข้อมูล SQL โดยตรง

---

## 💻 3. โครงสร้างและการแยกโค้ดฝั่งระบบผู้ดูแลเว็บบอร์ด (React Admin Frontend)

ฝั่ง React Web Admin ใน `frontend-admin/src/` จะถูกแยกส่วนอย่างเป็นระบบเพื่อประสิทธิภาพและความสะอาดของโค้ด:

```
src/
├── components/   # เลย์เอาต์หลักและคอมโพเนนต์ย่อยที่ใช้ซ้ำ (Sidebar, RightPanel)
├── pages/        # หน้าหลักที่อิงตามระบบ Routes (Dashboard, Requests, Employees)
├── services/     # ตัวช่วยเชื่อมต่อคุยกับ Go API
├── types/        # การประกาศโครงสร้างตัวแปรใน TypeScript
└── utils/        # ฟังก์ชันผู้ช่วยย่อยๆ (Helper Functions)
```

### 📋 กฎเหล็กของการแยกโค้ด (Rules of Separation)
* **Services**: แยกฟังก์ชันเรียก API ทั้งหมดออกเป็นไฟล์เดี่ยว (เช่น `adminApi.ts`) เพื่อไม่ให้หน้าจอหลักต้องจัดการการยิง Fetch/Axios ด้วยตนเอง
* **Types**: รวบรวมคำประกาศชนิดตัวแปร (Type Interface) ทั้งหมดไว้ที่ศูนย์กลางเพื่อความสะดวกในการเรียกใช้และหลีกเลี่ยงการสับสนของข้อมูล
