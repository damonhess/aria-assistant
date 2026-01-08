// Normalize Input for Calendar Read - v3 with date range support
// Handles: events query, list_deletions (trash), date ranges

const input = $input.first().json;
let rawInput = input.query && typeof input.query === 'object' ? input.query : input.query && typeof input.query === 'string' ? { text: input.query } : input;

// Check for list_deletions operation (show trash)
const text = (rawInput.text || rawInput.query || '').toLowerCase();
if (rawInput.operation === 'list_deletions' ||
    text.includes('trash') ||
    text.includes('deleted') ||
    text.includes('show trash') ||
    text.includes('view deleted')) {
  return [{
    json: {
      operation: 'list_deletions',
      user_id: rawInput.user_id || '50850e59-bea0-4076-83e0-85d5c7004004'
    }
  }];
}

// If explicit start/end provided, use them
if (rawInput.start && rawInput.end) {
  return [{ json: { operation: 'get_events', start: rawInput.start, end: rawInput.end, requested_date: rawInput.start.split('T')[0] } }];
}

const queryText = rawInput.text || rawInput.query || JSON.stringify(rawInput);
const lowerText = queryText.toLowerCase();

// PST timezone handling
const pstOffset = -8 * 60 * 60 * 1000;
const now = new Date(Date.now() + pstOffset + new Date().getTimezoneOffset() * 60 * 1000);

// Helper: Get day of week (0=Sunday, 1=Monday, etc.)
const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const monthNames = ['january','february','march','april','may','june','july','august','september','october','november','december'];

// Helper: Parse a single date reference
function parseDate(text, referenceDate) {
  const lower = text.toLowerCase().trim();
  const ref = referenceDate || now;

  // Relative days
  if (lower === 'today') return new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  if (lower === 'tomorrow') return new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() + 1);
  if (lower === 'yesterday') return new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - 1);

  // Day of week (e.g., "friday", "next monday")
  for (let i = 0; i < dayNames.length; i++) {
    if (lower.includes(dayNames[i])) {
      const currentDay = ref.getDay();
      let daysUntil = i - currentDay;
      if (daysUntil <= 0) daysUntil += 7; // Next occurrence
      if (lower.includes('next')) daysUntil += 7;
      return new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() + daysUntil);
    }
  }

  // Month + day (e.g., "January 15")
  for (let i = 0; i < monthNames.length; i++) {
    const match = text.match(new RegExp(monthNames[i] + '\\s+(\\d{1,2})(?:[,\\s]+(\\d{4}))?', 'i'));
    if (match) {
      return new Date(match[2] ? parseInt(match[2]) : ref.getFullYear(), i, parseInt(match[1]));
    }
  }

  return null;
}

// Helper: Parse time of day
function parseTimeOfDay(text) {
  const lower = text.toLowerCase();
  if (lower.includes('morning')) return { startHour: 6, endHour: 12 };
  if (lower.includes('afternoon')) return { startHour: 12, endHour: 17 };
  if (lower.includes('evening')) return { startHour: 17, endHour: 23 };
  if (lower.includes('night')) return { startHour: 20, endHour: 23 };
  return null; // Full day
}

let startDate = null;
let endDate = null;
let timeFilter = parseTimeOfDay(lowerText);

// Check for date ranges
// Pattern: "today through Friday", "today to Friday", "from today to Friday"
const rangePatterns = [
  /(?:from\s+)?(\w+)\s+(?:through|thru|to|until|-)\s+(\w+)/i,
  /(\w+)\s*-\s*(\w+)/i
];

let isRange = false;
for (const pattern of rangePatterns) {
  const match = lowerText.match(pattern);
  if (match) {
    const start = parseDate(match[1], now);
    const end = parseDate(match[2], now);
    if (start && end) {
      startDate = start;
      endDate = end;
      isRange = true;
      break;
    }
  }
}

// Check for "this week"
if (!isRange && lowerText.includes('this week')) {
  const currentDay = now.getDay();
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - currentDay + 1);
  const sunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - currentDay + 7);
  startDate = monday;
  endDate = sunday;
  isRange = true;
}

// Check for "next week"
if (!isRange && lowerText.includes('next week')) {
  const currentDay = now.getDay();
  const nextMonday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - currentDay + 8);
  const nextSunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - currentDay + 14);
  startDate = nextMonday;
  endDate = nextSunday;
  isRange = true;
}

// Single date parsing if not a range
if (!isRange) {
  // Try to parse single date
  if (lowerText.includes('today')) {
    startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    endDate = startDate;
  } else if (lowerText.includes('tomorrow')) {
    startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    endDate = startDate;
  } else if (lowerText.includes('yesterday')) {
    startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    endDate = startDate;
  } else {
    // Try month + day
    for (let i = 0; i < monthNames.length; i++) {
      const match = queryText.match(new RegExp(monthNames[i] + '\\s+(\\d{1,2})(?:[,\\s]+(\\d{4}))?', 'i'));
      if (match) {
        startDate = new Date(match[2] ? parseInt(match[2]) : now.getFullYear(), i, parseInt(match[1]));
        endDate = startDate;
        break;
      }
    }

    // Try day of week
    if (!startDate) {
      for (let i = 0; i < dayNames.length; i++) {
        if (lowerText.includes(dayNames[i])) {
          const currentDay = now.getDay();
          let daysUntil = i - currentDay;
          if (daysUntil <= 0) daysUntil += 7;
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysUntil);
          endDate = startDate;
          break;
        }
      }
    }
  }
}

// Default to today if no date found
if (!startDate) {
  startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  endDate = startDate;
}

// Apply time of day filter
let startHour = 0;
let startMinute = 0;
let endHour = 23;
let endMinute = 59;

if (timeFilter) {
  startHour = timeFilter.startHour;
  endHour = timeFilter.endHour;
  endMinute = 59;
}

// Format dates
const formatDate = (d, hour, minute) => {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const h = String(hour).padStart(2, '0');
  const min = String(minute).padStart(2, '0');
  return `${y}-${m}-${day}T${h}:${min}:00-08:00`;
};

const startY = startDate.getFullYear();
const startM = String(startDate.getMonth() + 1).padStart(2, '0');
const startD = String(startDate.getDate()).padStart(2, '0');

const endY = endDate.getFullYear();
const endM = String(endDate.getMonth() + 1).padStart(2, '0');
const endD = String(endDate.getDate()).padStart(2, '0');

return [{
  json: {
    operation: 'get_events',
    start: formatDate(startDate, startHour, startMinute),
    end: formatDate(endDate, endHour, endMinute),
    requested_date: `${startY}-${startM}-${startD}`,
    end_date: isRange ? `${endY}-${endM}-${endD}` : null,
    is_range: isRange,
    query: queryText
  }
}];
