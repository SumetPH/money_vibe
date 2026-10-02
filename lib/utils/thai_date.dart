/// ชื่อเดือน/วันภาษาไทย (ใช้ปี ค.ศ. ตามที่แอปแสดงผล)
const List<String> thaiMonthNames = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const List<String> thaiMonthShortNames = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// ชื่อวันแบบย่อ เริ่มจากวันอาทิตย์ (index 0) ตาม [DateTime.weekday] % 7
const List<String> thaiWeekdayShortNames = [
  'อา',
  'จ',
  'อ',
  'พ',
  'พฤ',
  'ศ',
  'ส',
];

/// เช่น `2 ต.ค. 2026`
String formatThaiShortDate(DateTime date) =>
    '${date.day} ${thaiMonthShortNames[date.month - 1]} ${date.year}';
