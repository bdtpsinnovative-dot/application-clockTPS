---
name: flutter-dart-code-review
description: ウィジェットのベストプラクティス、状態管理パターン（BLoC、Riverpod、Provider、GetX、MobX、Signals）、Dartのイディオム、パフォーマンス、アクセシビリティ、セキュリティ、クリーンアーキテクチャをカバーするライブラリに依存しないFlutter/Dartのコードレビューチェックリスト。
---

# Flutter/Dart コードレビューベストプラクティス (Flutter/Dart Code Review Checklist)

แนวทางการตรวจสอบโค้ด (Code Review) สำหรับแอปพลิเคชัน Flutter และ Dart เพื่อช่วยให้โค้ดมีประสิทธิภาพ ปลอดภัย และเป็นไปตามหลักมาตรฐานอุตสาหกรรม

---

## 1. โครงสร้างและการจัดระเบียบโปรเจกต์ (Project Health)
* โครงสร้างโฟลเดอร์มีความสอดคล้องและเป็นระบบ (Feature-first หรือ Layer-first)
* แบ่งแยกหน้าหน้าที่ชัดเจน: UI, Business Logic, และ Data Layers
* Widget ไม่มีโค้ดประมวลผลทางธุรกิจ (Business Logic) จะต้องทำหน้าที่แสดงผลอย่างเดียวเท่านั้น
* `pubspec.yaml` จัดการเป็นระเบียบ ไม่มี dependency ที่ไม่ได้ใช้งานและระบุเวอร์ชันชัดเจน
* `analysis_options.yaml` เปิดใช้งานกฎการวิเคราะห์ลินต์อย่างเคร่งครัด
* ไม่มีประโยค `print()` ในโค้ดเวอร์ชัน Production ให้ใช้ `log()` จาก `dart:developer` หรือแพ็คเกจロギングแทน
* ไฟล์ที่ถูกเจนขึ้นมาอัตโนมัติ (เช่น `.g.dart`, `.freezed.dart`) อัปเดตและถูกเพิ่มใน `.gitignore`

---

## 2. ภาษา Dart และข้อห้าม (Dart Pitfalls)
* หลีกเลี่ยงการใช้ `dynamic` โดยไม่ระบุชนิดข้อมูล (Implicit dynamic) ให้ตั้งค่า `strict-casts`, `strict-inference` และ `strict-raw-types` ในลินต์
* ตรวจสอบความปลอดภัยค่าว่าง (Null safety): หลีกเลี่ยงการใช้ `!` (bang operator) พร่ำเพรื่อ ให้ใช้การเช็ค null หรือ pattern matching ของ Dart 3 แทน (`if (value case var v?)`)
* ไม่ดึงค่า Exception โดยระบุประเภทกว้างเกินไป เช่น `catch (e)` โดยไม่มีบล็อก `on` (ควรระบุประเภท Exception เสมอ)
* หลีกเลี่ยงการใช้ `late` พร่ำเพรื่อถ้าสามารถเปลี่ยนไปใช้ Nullable หรือกำหนดค่าใน Constructor ได้ เพื่อหลีกเลี่ยงข้อผิดพลาดในขณะรันไทม์
* การต่อข้อความในลูปควรใช้ `StringBuffer` แทนการใช้เครื่องหมายบวก `+`
* หากตัวแปรภายในคลาสสามารถเปลี่ยนแปลงค่าได้ ไม่ควรประกาศ Constructor เป็น `const`
* ใช้ `final` แทน `var` ในจุดที่ตัวแปรไม่มีการเปลี่ยนแปลง และใช้ `const` สำหรับค่าคงที่
* ป้องกันการแก้ไขข้อมูลภายนอก (Read-only view) สำหรับโมเดลข้อมูลระดับสาธารณะ

---

## 3. แนวทางการพัฒนา Widget (Widget Best Practices)
* **การแบ่งย่อย Widget:**
  * เมธอด `build()` ในตัว Widget ไม่ควรมีความยาวเกิน 80-100 บรรทัด
  * แยก Widget ออกเป็นคลาสย่อยแทนการใช้ฟังก์ชันรีเทิร์นช่วย (`_build*()`) เพื่อประโยชน์ด้านประสิทธิภาพในการสร้าง Widget ใหม่ (Rebuild boundary)
  * ใช้ StatelessWidget เป็นหลักเมื่อไม่มีการเก็บสถานะในตัว
* **การใช้ Const:**
  * ใช้ `const` นำหน้าการสร้างวัตถุ (Constructor) เพื่อลดการ Rebuild และลดการประมวลผลของเฟรมเวิร์ก
* **การใช้ Key:**
  * ใช้ `ValueKey` ใน List/Grid เสมอเมื่อมีการขยับหรือเรียงลำดับข้อมูลใหม่ เพื่อคงสถานะดั้งเดิมไว้
  * ใช้ `GlobalKey` เฉพาะที่จำเป็นจริงๆ (เนื่องจากอาจทำให้ประสิทธิภาพลดลง)
* **การใช้ Theme และ Design System:**
  * อ้างอิงสีผ่าน `Theme.of(context).colorScheme` เท่านั้น ไม่ลงโค้ดสี Hex หรือ `Colors.*` แบบดิบๆ
  * อ้างอิงรูปแบบตัวอักษรผ่าน `Theme.of(context).textTheme`
  * รองรับ Dark Mode และทดสอบความสว่างสีที่ตัดกัน

---

## 4. การจัดการสถานะ (State Management Best Practices)
* แยกโค้ดควบคุมสถานะการทำงาน (เช่น BLoC, Notifier, Controller) ออกนอกหน้าจอ UI
* ห้ามดึงข้อมูลผ่าน API หรือฐานข้อมูลจากหน้าระดับ Widget หรือ State Manager โดยตรง ให้ใช้ผ่าน Repositories เสมอ
* สถานะข้อมูล (State Objects) ควรถูกกำหนดให้ไม่สามารถเปลี่ยนแปลงได้ (Immutable) ให้ใช้การทำ `copyWith()` แทนเมื่อต้องการแก้ไขค่า
* หลีกเลี่ยงการกำหนดสถานะขัดแย้งกันเอง (เช่น มี Boolean Flag ซ้ำซ้อนกัน `isLoading`, `isError`, `hasData`) ให้หันมาใช้ `sealed class` หรือสถานะที่เป็นรูปธรรมตัวเดียวแทน เช่น:
  ```dart
  sealed class UserState {}
  class UserInitial extends UserState {}
  class UserLoading extends UserState {}
  class UserLoaded extends UserState { final User user; UserLoaded(this.user); }
  class UserError extends UserState { final String message; UserError(this.message); }
  ```
* ตรวจสอบว่าได้ปิดการทำงานของตัวสังเกตการ (Disposing / Closing) เช่น `StreamController`, `Timer`, `Reaction` เสมอหลังการใช้งานเพื่อป้องกันเมมโมรี่รั่วไหล
* **การใช้งาน BuildContext หลังจบ Async:** ห้ามใช้ `BuildContext` ข้ามช่วง Async (Async Gaps) โดยไม่เช็ค `context.mounted` เสียก่อน เพื่อเลี่ยงแอปพลิเคชันล่มจากการวาดหน้าจอบน UI ที่ไม่มีตัวตนแล้ว

---

## 5. ประสิทธิภาพ (Performance)
* อย่าเรียกใช้งาน `setState()` ในระดับ Root Widget (พยายามแยกคลาสลูกออกมาเรียก setState แทน)
* ใส่ `RepaintBoundary` ครอบหน้าจอที่มีองค์ประกอบอนิメชั่นซับซ้อน เพื่อป้องกันการรีโหลดหน้าจอหลัก
* หลีกเลี่ยงการรันงานหนัก เช่น การสลับสับเปลี่ยนตำแหน่งข้อมูลในลิสต์ขนาดใหญ่หรือการคอมไพล์ Regex ภายในเมธอด `build()`
* ใช้ `ListView.builder` หรือ `GridView.builder` เสมอกับรายการข้อมูลขนาดใหญ่หรือไดนามิก
* หลีกเลี่ยงการใช้ `Opacity` ในการทำอนิเมชั่น ให้หันไปใช้ `FadeTransition` หรือ `AnimatedOpacity` แทน

---

## 6. ความปลอดภัย (Security)
* จัดเก็บข้อมูลที่เป็นความลับ (Tokens, Credentials) บน Secure Storage เท่านั้น (เช่น Keychain หรือ EncryptedSharedPreferences)
* ห้ามเขียนคีย์ API หรือ Secret Key ลงในโค้ดดิบ ให้ใช้ระบบคอมไพล์ตอนบิวด์ผ่าน `--dart-define`
* ดำเนินการตรวจสอบความถูกต้องและกรองข้อมูลผู้ใช้ (Input Validation) เสมอก่อนส่งออกไปเรียกใช้ปลายทาง
* บังคับให้เรียกใช้เฉพาะลิงก์ระบบเครือข่ายปลอดภัย (HTTPS)
