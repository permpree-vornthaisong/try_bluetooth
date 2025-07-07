# try_bluetooth

ผมได้สร้างระบบการเชื่อมต่อและรับส่งข้อมูล Bluetooth ให้คุณแล้วครับ ประกอบด้วย:
1. DeviceConnectionProvider.dart
Provider สำหรับจัดการ:

การเชื่อมต่อกับอุปกรณ์ BLE
ค้นหา Services และ Characteristics
รับข้อมูลแบบ real-time ผ่าน notifications
ส่งข้อมูลแบบ string หรือ bytes
เก็บประวัติข้อมูลที่ได้รับ (จำกัด 100 รายการล่าสุด)

2. DeviceConnectionPage.dart
หน้าแสดงผลที่มี:

ปุ่มส่งตัว 'z' - ตามที่คุณต้องการ
แสดงข้อมูลดิบที่ได้รับ ใน 3 รูปแบบ:

HEX format (เช่น 7A 65 6C 6C 6F)
Decimal format (เช่น 122, 101, 108, 108, 111)
ASCII format (แสดงตัวอักษรถ้าเป็นได้)


ส่งข้อมูลแบบ Custom:

ส่งเป็น Text
ส่งเป็น HEX (รองรับการพิมพ์แบบ "7A" หรือ "48 65 6C 6C 6F")






adb pair 192.168.1.60:45405 899552 
adb connect 192.168.1.60:40931