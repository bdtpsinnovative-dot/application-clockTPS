# Project Style & Design Rules

## UI Iconography
- Do NOT use raw emojis (e.g. 🏡, 🛋️, 📅) in the app UI section headers, titles, or cards.
- Always use official Flutter `Icon` and `Icons` widgets instead for a clean, consistent, and premium feel.

## Layout & Overflow Prevention
- Wrap the contents of all Modal Bottom Sheets (e.g., filter sheets, options sheets) in a `SingleChildScrollView` to prevent keyboard or layout height overflows on short screens.

## Report History & Date Filtering
- Avoid showing date/month indicators as chips below the search bar to prevent visual clutter.
- Always place the active date/month filter context dynamically in the `AppBar` subtitle (e.g., "ประจำวันที่ 17 กรกฎาคม พ.ศ. 2569" or "ประจำเดือน กรกฎาคม พ.ศ. 2569").
- Use mini indicator chips ONLY for status/type filters (e.g. "ตรงเวลา", "สาย", "ลาป่วย").
