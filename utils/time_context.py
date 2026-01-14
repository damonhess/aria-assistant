#!/usr/bin/env python3
"""
Time Context Module for ARIA
Provides time awareness for system prompts and responses
"""

from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import pytz


class TimeContext:
    """Generates time context strings for ARIA"""

    def __init__(self, timezone: str = "America/Los_Angeles"):
        self.timezone = pytz.timezone(timezone)

    def get_current_time(self) -> datetime:
        """Get current time in configured timezone"""
        return datetime.now(self.timezone)

    def get_time_context(self) -> str:
        """
        Generate a natural language time context string.

        Returns:
            String like "It's Wednesday, January 14, 2026 at 10:15 AM PST"
        """
        now = self.get_current_time()

        # Format components
        day_name = now.strftime("%A")  # Wednesday
        month_name = now.strftime("%B")  # January
        day = now.day  # 14
        year = now.year  # 2026
        time_str = now.strftime("%I:%M %p").lstrip("0")  # 10:15 AM
        tz_abbrev = now.strftime("%Z")  # PST

        return f"It's {day_name}, {month_name} {day}, {year} at {time_str} {tz_abbrev}"

    def get_time_of_day(self) -> str:
        """Get time of day category"""
        hour = self.get_current_time().hour

        if 5 <= hour < 12:
            return "morning"
        elif 12 <= hour < 17:
            return "afternoon"
        elif 17 <= hour < 21:
            return "evening"
        else:
            return "night"

    def get_greeting(self) -> str:
        """Get appropriate greeting based on time"""
        time_of_day = self.get_time_of_day()
        return f"Good {time_of_day}"

    def get_full_context(self) -> Dict[str, Any]:
        """
        Get full time context as a dictionary.

        Returns:
            Dict with all time-related information
        """
        now = self.get_current_time()

        return {
            "datetime": now.isoformat(),
            "date": now.strftime("%Y-%m-%d"),
            "time": now.strftime("%H:%M:%S"),
            "time_12h": now.strftime("%I:%M %p").lstrip("0"),
            "day_name": now.strftime("%A"),
            "day_of_week": now.isoweekday(),  # 1=Monday, 7=Sunday
            "month_name": now.strftime("%B"),
            "month": now.month,
            "day": now.day,
            "year": now.year,
            "hour": now.hour,
            "minute": now.minute,
            "timezone": str(self.timezone),
            "timezone_abbrev": now.strftime("%Z"),
            "utc_offset": now.strftime("%z"),
            "time_of_day": self.get_time_of_day(),
            "greeting": self.get_greeting(),
            "is_weekend": now.isoweekday() >= 6,
            "is_business_hours": 9 <= now.hour < 17 and now.isoweekday() < 6,
            "natural_string": self.get_time_context()
        }

    def get_system_prompt_block(self) -> str:
        """
        Generate a time context block for system prompts.

        Returns:
            Formatted block for inclusion in system prompts
        """
        ctx = self.get_full_context()

        lines = [
            "## Current Time Context",
            f"**{ctx['natural_string']}**",
            f"- Day: {ctx['day_name']} (Day {ctx['day_of_week']} of the week)",
            f"- Date: {ctx['month_name']} {ctx['day']}, {ctx['year']}",
            f"- Time: {ctx['time_12h']} {ctx['timezone_abbrev']}",
        ]

        if ctx['is_weekend']:
            lines.append("- It's the weekend")
        elif ctx['is_business_hours']:
            lines.append("- During business hours")
        else:
            lines.append(f"- It's {ctx['time_of_day']} time")

        return "\n".join(lines)

    def parse_natural_time(self, text: str) -> Optional[datetime]:
        """
        Parse natural language time references.

        Args:
            text: Natural language like "tomorrow at 3pm", "in 2 hours", "next Monday"

        Returns:
            Datetime object or None if unparseable
        """
        now = self.get_current_time()
        text = text.lower().strip()

        # Handle relative times
        if text.startswith("in "):
            return self._parse_relative_time(text[3:], now)

        # Handle specific references
        if text == "now":
            return now
        elif text == "today":
            return now.replace(hour=9, minute=0, second=0, microsecond=0)
        elif text == "tonight":
            return now.replace(hour=20, minute=0, second=0, microsecond=0)
        elif text == "tomorrow":
            return (now + timedelta(days=1)).replace(hour=9, minute=0, second=0, microsecond=0)
        elif "tomorrow at" in text:
            time_part = text.replace("tomorrow at", "").strip()
            base = now + timedelta(days=1)
            return self._parse_time_into_date(base, time_part)

        # Handle day references
        days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for i, day in enumerate(days):
            if f"next {day}" in text or text == day:
                target_weekday = i
                current_weekday = now.weekday()
                days_ahead = target_weekday - current_weekday
                if days_ahead <= 0:
                    days_ahead += 7
                target_date = now + timedelta(days=days_ahead)
                target_date = target_date.replace(hour=9, minute=0, second=0, microsecond=0)

                # Check for time specification
                if " at " in text:
                    time_part = text.split(" at ")[-1]
                    return self._parse_time_into_date(target_date, time_part)
                return target_date

        return None

    def _parse_relative_time(self, text: str, base: datetime) -> Optional[datetime]:
        """Parse relative time like '2 hours', '30 minutes', '1 day'"""
        parts = text.split()
        if len(parts) < 2:
            return None

        try:
            amount = int(parts[0])
        except ValueError:
            return None

        unit = parts[1].rstrip("s")  # Remove plural

        if unit == "minute":
            return base + timedelta(minutes=amount)
        elif unit == "hour":
            return base + timedelta(hours=amount)
        elif unit == "day":
            return base + timedelta(days=amount)
        elif unit == "week":
            return base + timedelta(weeks=amount)

        return None

    def _parse_time_into_date(self, base: datetime, time_str: str) -> datetime:
        """Parse a time string and apply it to a base date"""
        time_str = time_str.strip().lower()

        # Handle 12-hour format with am/pm
        hour = None
        minute = 0

        if "am" in time_str or "pm" in time_str:
            is_pm = "pm" in time_str
            time_str = time_str.replace("am", "").replace("pm", "").strip()

            if ":" in time_str:
                parts = time_str.split(":")
                hour = int(parts[0])
                minute = int(parts[1])
            else:
                hour = int(time_str)

            if is_pm and hour != 12:
                hour += 12
            elif not is_pm and hour == 12:
                hour = 0
        elif ":" in time_str:
            parts = time_str.split(":")
            hour = int(parts[0])
            minute = int(parts[1])
        else:
            try:
                hour = int(time_str)
            except ValueError:
                hour = 9  # Default

        if hour is not None:
            return base.replace(hour=hour, minute=minute, second=0, microsecond=0)
        return base


def get_time_context_string(timezone: str = "America/Los_Angeles") -> str:
    """Convenience function to get time context string"""
    return TimeContext(timezone).get_time_context()


def get_system_prompt_time_block(timezone: str = "America/Los_Angeles") -> str:
    """Convenience function to get system prompt block"""
    return TimeContext(timezone).get_system_prompt_block()


if __name__ == "__main__":
    # Test the module
    tc = TimeContext()
    print("Time Context String:")
    print(tc.get_time_context())
    print("\nSystem Prompt Block:")
    print(tc.get_system_prompt_block())
    print("\nFull Context:")
    import json
    ctx = tc.get_full_context()
    # Remove non-serializable datetime
    ctx['datetime'] = str(ctx['datetime'])
    print(json.dumps(ctx, indent=2))
