/**
 * 生成日历并自动高亮每个月份
 * @param {string} calendarStart - 日历开始，必须为周日 (格式: YYYY-MM-DD)
 * @param {string} calendarEnd   - 日历结束，必须为周六 (格式: YYYY-MM-DD)
 * @param {string} semesterStart - 学期开始日期 (格式: YYYY-MM-DD)
 * @param {string} semesterEnd   - 学期结束日期 (格式: YYYY-MM-DD)
 * @param {boolean} autoHighlight - 是否自动高亮每个月份 (默认: true)
 * @param {string} academicYear - 学年度标题 (默认: "2025-2026学年度校历")
 * @param {string} semesterInfo - 学期信息 (默认: "（第一学期）")
 */
function generateCalendar(
  calendarStart,
  calendarEnd,
  semesterStart,
  semesterEnd,
  autoHighlight = true,
  academicYear = "2025-2026学年度校历",
  semesterInfo = "（第一学期）"
) {
  // 设置标题
  document.getElementById("academic-year").textContent = academicYear;
  document.getElementById("semester-info").textContent = semesterInfo;
  const startDate = new Date(calendarStart + "T00:00:00");
  const endDate = new Date(calendarEnd + "T00:00:00");
  const semesterStartDate = new Date(semesterStart + "T00:00:00");
  const semesterEndDate = new Date(semesterEnd + "T00:00:00");
  const calendarBody = document.getElementById("calendar-body");

  if (
    startDate.getDay() !== 0 ||
    endDate.getDay() !== 6 ||
    endDate <= startDate
  ) {
    alert(
      "日历开始日期需为周日，日历结束日期需为周六，且结束日期需晚于开始日期"
    );
    return;
  }

  if (semesterEndDate <= semesterStartDate) {
    alert("学期结束日期需晚于学期开始日期");
    return;
  }

  calendarBody.innerHTML = "";

  // 计算学期开始日期所在的周的周日
  const semesterStartWeekSunday = new Date(semesterStartDate);
  semesterStartWeekSunday.setDate(
    semesterStartDate.getDate() - semesterStartDate.getDay()
  );

  // 计算学期结束日期所在的周的周六
  const semesterEndWeekSaturday = new Date(semesterEndDate);
  semesterEndWeekSaturday.setDate(
    semesterEndDate.getDate() + (6 - semesterEndDate.getDay())
  );

  // --- 1. 生成每周数据，并统计每月行数 ---
  const weeklyData = [];
  let temp = new Date(startDate);
  let weekCount = 1;
  const monthRowSpans = {};
  const monthRanges = new Map(); // 记录每个月的日期范围

  // 月份汉字映射
  const monthNames = {
    1: "元月",
    2: "二月",
    3: "三月",
    4: "四月",
    5: "五月",
    6: "六月",
    7: "七月",
    8: "八月",
    9: "九月",
    10: "十月",
    11: "十一月",
    12: "十二月",
  };

  while (temp <= endDate) {
    const weekInfo = {
      weekNumber: null, // 初始为null，后面根据学期范围计算
      month: temp.getMonth() + 1,
      year: temp.getFullYear(),
      days: [],
    };

    // 判断当前周是否在学期范围内
    const currentWeekSunday = new Date(temp);
    const currentWeekSaturday = new Date(temp);
    currentWeekSaturday.setDate(temp.getDate() + 6);

    // 如果当前周与学期时间有交集，则计算周次
    if (
      currentWeekSaturday >= semesterStartWeekSunday &&
      currentWeekSunday <= semesterEndWeekSaturday
    ) {
      // 计算从学期开始周到当前周的周数差
      const weeksDiff = Math.floor(
        (currentWeekSunday - semesterStartWeekSunday) /
          (7 * 24 * 60 * 60 * 1000)
      );
      weekInfo.weekNumber = weeksDiff + 1;
    }

    for (let i = 0; i < 7; i++) {
      const yyyy = temp.getFullYear();
      const mm = String(temp.getMonth() + 1).padStart(2, "0");
      const dd = String(temp.getDate()).padStart(2, "0");
      const dateStr = `${yyyy}-${mm}-${dd}`;

      weekInfo.days.push({
        day: temp.getDate(),
        isWeekend: i === 0 || i === 6,
        dateStr: dateStr,
      });

      // 记录每个月的日期范围
      const monthKey = `${yyyy}-${mm}`;
      if (!monthRanges.has(monthKey)) {
        monthRanges.set(monthKey, { start: dateStr, end: dateStr });
      } else {
        monthRanges.get(monthKey).end = dateStr;
      }

      temp.setDate(temp.getDate() + 1);
    }
    weeklyData.push(weekInfo);
    monthRowSpans[weekInfo.month] = (monthRowSpans[weekInfo.month] || 0) + 1;
  }

  // --- 2. 渲染表格，并打上 data-week/data-weekday/data-date ---
  const drawnMonths = new Set();
  weeklyData.forEach((weekInfo, weekIdx) => {
    const tr = document.createElement("tr");

    // 周次
    const wc = document.createElement("td");
    wc.textContent = weekInfo.weekNumber || ""; // 如果weekNumber为null则显示空字符串
    wc.className = "week-number week-column";
    tr.appendChild(wc);

    // 月份合并
    if (!drawnMonths.has(weekInfo.month)) {
      const mc = document.createElement("td");
      mc.textContent = monthNames[weekInfo.month];
      mc.className = "month-cell month-column";
      mc.rowSpan = monthRowSpans[weekInfo.month];
      tr.appendChild(mc);
      drawnMonths.add(weekInfo.month);
    }

    // 七天
    weekInfo.days.forEach((dInfo, weekday) => {
      const td = document.createElement("td");
      td.textContent = dInfo.day;
      td.className = "day-column";
      if (dInfo.isWeekend) td.classList.add("weekend-day");

      // 四个关键属性
      td.dataset.week = weekIdx;
      td.dataset.weekday = weekday;
      td.dataset.date = dInfo.dateStr;

      tr.appendChild(td);
    });

    // 备注
    const noteCell = document.createElement("td");
    noteCell.className = "note-column";
    tr.appendChild(noteCell);
    calendarBody.appendChild(tr);
  });

  // --- 3. 自动高亮每个月份 ---
  if (autoHighlight) {
    monthRanges.forEach((range) => {
      highlightRange(range.start, range.end);
    });
  }
}

/**
 * 为指定行添加备注
 * @param {number} rowNumber - 行号（从1开始计数，对应表格中的第几行）
 * @param {string} noteContent - 备注内容
 * @param {boolean} needNumber - 是否需要序号（默认为false）
 * @param {number} sequenceNumber - 序号（当needNumber为true时使用）
 */
function addNote(
  rowNumber,
  noteContent,
  needNumber = false,
  sequenceNumber = null
) {
  const calendarBody = document.getElementById("calendar-body");
  const rows = calendarBody.querySelectorAll("tr");

  // 圆圈序号映射
  const circleNumbers = {
    1: "①",
    2: "②",
    3: "③",
    4: "④",
    5: "⑤",
    6: "⑥",
    7: "⑦",
    8: "⑧",
    9: "⑨",
    10: "⑩",
  };

  // 检查行号是否有效
  if (rowNumber < 1 || rowNumber > rows.length) {
    console.error(`行号 ${rowNumber} 无效。有效范围：1-${rows.length}`);
    return false;
  }

  // 获取指定行（行号从1开始，数组索引从0开始）
  const targetRow = rows[rowNumber - 1];
  const noteCell = targetRow.querySelector(".note-column");

  if (noteCell) {
    let finalContent = noteContent;
    if (needNumber && sequenceNumber !== null) {
      const circleNumber = circleNumbers[sequenceNumber] || sequenceNumber;
      finalContent = `${circleNumber} ${noteContent}`;
    }
    noteCell.textContent = finalContent;
    console.log(`已为第 ${rowNumber} 行添加备注：${finalContent}`);
    return true;
  } else {
    console.error(`第 ${rowNumber} 行未找到备注列`);
    return false;
  }
}

/**
 * 批量添加备注
 * @param {Array} notes - 备注数组，每个元素包含 {row: number, content: string, needNumber?: boolean}
 */
function addMultipleNotes(notes) {
  let successCount = 0;
  let sequenceNumber = 1; // 用于生成序号

  notes.forEach((note) => {
    const { row, content, needNumber = false } = note;
    if (addNote(row, content, needNumber, needNumber ? sequenceNumber : null)) {
      successCount++;
      if (needNumber) {
        sequenceNumber++; // 只有需要序号的备注才增加序号
      }
    }
  });
  console.log(`成功添加 ${successCount}/${notes.length} 条备注`);
  return successCount;
}

/**
 * 手动设置周次并合并显示
 * @param {number} startRow - 起始行（从1开始计数）
 * @param {number} endRow - 结束行（从1开始计数）
 * @param {string} content - 要显示的内容
 */
function setCustomWeekRange(startRow, endRow, content) {
  const calendarBody = document.getElementById("calendar-body");
  const rows = calendarBody.querySelectorAll("tr");

  // 参数验证
  if (
    startRow < 1 ||
    endRow < 1 ||
    startRow > rows.length ||
    endRow > rows.length
  ) {
    console.error(`行号无效。有效范围：1-${rows.length}`);
    return false;
  }

  if (startRow > endRow) {
    console.error("起始行不能大于结束行");
    return false;
  }

  // 计算需要合并的行数
  const rowCount = endRow - startRow + 1;

  // 获取起始行的周次单元格
  const startRowElement = rows[startRow - 1];
  const weekCell = startRowElement.querySelector(".week-number");

  if (!weekCell) {
    console.error(`第 ${startRow} 行未找到周次列`);
    return false;
  }

  // 设置合并的行数和内容
  weekCell.rowSpan = rowCount;
  weekCell.textContent = content;
  weekCell.style.verticalAlign = "middle";
  weekCell.style.fontWeight = "bold";
  // 使用CSS变量或媒体查询兼容的颜色
  weekCell.style.backgroundColor =
    getComputedStyle(document.documentElement).getPropertyValue(
      "--custom-week-bg"
    ) ||
    (window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "#4a4a4a"
      : "#f0f8ff");

  // 隐藏其他行的周次单元格
  for (let i = startRow; i < endRow; i++) {
    const currentRow = rows[i];
    const currentWeekCell = currentRow.querySelector(".week-number");
    if (currentWeekCell) {
      currentWeekCell.style.display = "none";
    }
  }

  console.log(`成功设置第 ${startRow}-${endRow} 行的周次为: ${content}`);
  return true;
}

/**
 * 批量设置自定义周次
 * @param {Array} weekRanges - 周次范围数组，每个元素包含 {startRow: number, endRow: number, content: string}
 */
function setMultipleCustomWeekRanges(weekRanges) {
  let successCount = 0;

  // 按起始行排序，避免合并冲突
  weekRanges.sort((a, b) => a.startRow - b.startRow);

  // 验证是否有重叠的范围
  for (let i = 0; i < weekRanges.length - 1; i++) {
    const current = weekRanges[i];
    const next = weekRanges[i + 1];
    if (current.endRow >= next.startRow) {
      console.error(
        `周次范围重叠：第${current.startRow}-${current.endRow}行 与 第${next.startRow}-${next.endRow}行`
      );
      return successCount;
    }
  }

  weekRanges.forEach((range) => {
    const { startRow, endRow, content } = range;
    if (setCustomWeekRange(startRow, endRow, content)) {
      successCount++;
    }
  });

  console.log(`成功设置 ${successCount}/${weekRanges.length} 个自定义周次范围`);
  return successCount;
}

/**
 * 在已有表格中，高亮（粗边框）选中 start～end 之间的所有单元格
 * @param {string} startDateString - 格式 YYYY-MM-DD
 * @param {string} endDateString   - 格式 YYYY-MM-DD
 */
function highlightRange(startDateString, endDateString) {
  const tbody = document.getElementById("calendar-body");
  // 先收集所有在范围内的 <td>，并建立 map：key = "week-weekday"
  const targets = {};
  Array.from(tbody.querySelectorAll("td[data-date]")).forEach((td) => {
    const d = td.dataset.date;
    if (d >= startDateString && d <= endDateString) {
      const key = `${td.dataset.week}-${td.dataset.weekday}`;
      targets[key] = td;
    }
  });

  // 对每个目标单元格，检查上下左右
  Object.entries(targets).forEach(([key, td]) => {
    const [w, wd] = key.split("-").map((n) => parseInt(n, 10));
    const neigh = {
      top: `${w - 1}-${wd}`,
      bottom: `${w + 1}-${wd}`,
      left: `${w}-${wd - 1}`,
      right: `${w}-${wd + 1}`,
    };
    // 动态选择边框颜色以适应深色模式
    const borderColor = window.matchMedia("(prefers-color-scheme: dark)")
      .matches
      ? "#888"
      : "#333";
    if (!targets[neigh.top]) td.style.borderTop = `3px solid ${borderColor}`;
    if (!targets[neigh.bottom])
      td.style.borderBottom = `3px solid ${borderColor}`;
    if (!targets[neigh.left]) td.style.borderLeft = `3px solid ${borderColor}`;
    if (!targets[neigh.right])
      td.style.borderRight = `3px solid ${borderColor}`;
  });
}

// 从URL查询参数获取配置文件名
function getConfigFileName() {
  const urlParams = new URLSearchParams(window.location.search);
  const fileName = urlParams.get("config");
  // 如果没有指定配置文件，默认使用 2025-2026-1.json
  return fileName ? `${fileName}.json` : "2025-2026-1.json";
}

// 加载配置并生成日历
async function loadAndGenerateCalendar() {
  try {
    const configFileName = getConfigFileName();
    console.log(`正在加载配置文件: ${configFileName}`);

    const response = await fetch(`./calendars/${configFileName}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const config = await response.json();

    // 从配置中提取参数并生成日历
    const { calendar, notes, customWeekRanges } = config;
    generateCalendar(
      calendar.calendarStart,
      calendar.calendarEnd,
      calendar.semesterStart,
      calendar.semesterEnd,
      calendar.autoHighlight,
      calendar.academicYear,
      calendar.semesterInfo
    );

    // 批量添加备注
    if (notes && notes.length > 0) {
      addMultipleNotes(notes);
    }

    // 批量设置自定义周次范围
    if (customWeekRanges && customWeekRanges.length > 0) {
      setMultipleCustomWeekRanges(customWeekRanges);
    }
  } catch (error) {
    console.error("加载配置文件失败:", error);
    const configFileName = getConfigFileName();
    alert(
      `配置文件加载失败，请检查 ${configFileName} 文件是否存在和格式是否正确`
    );
  }
}

// 页面加载完成后执行
window.onload = function () {
  loadAndGenerateCalendar();
};
