#!/usr/bin/env python3
"""
Reminders Module for ARIA
CRUD operations for the aria_reminders table
"""

import os
import json
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, asdict
import psycopg2
from psycopg2.extras import RealDictCursor

from time_context import TimeContext


@dataclass
class Reminder:
    """Reminder data structure"""
    id: Optional[str] = None
    user_id: str = "damon"
    reminder_text: str = ""
    remind_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    completed: bool = False
    completed_at: Optional[datetime] = None
    snoozed_until: Optional[datetime] = None
    snooze_count: int = 0
    recurrence: Optional[str] = None  # daily, weekly, monthly, yearly
    recurrence_end_date: Optional[datetime] = None
    priority: str = "normal"  # low, normal, high, urgent
    category: Optional[str] = None
    metadata: Dict[str, Any] = None
    source: str = "aria"

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        # Convert datetimes to ISO format strings
        for key in ['remind_at', 'created_at', 'completed_at', 'snoozed_until', 'recurrence_end_date']:
            if d[key] is not None and isinstance(d[key], datetime):
                d[key] = d[key].isoformat()
        return d


class ReminderManager:
    """Manages ARIA reminders"""

    def __init__(self, db_config: Optional[Dict[str, str]] = None):
        """
        Initialize reminder manager.

        Args:
            db_config: Database configuration dict with host, port, user, password, database
                      If None, reads from environment or uses Docker defaults
        """
        self.db_config = db_config or self._get_db_config()
        self.time_context = TimeContext()

    def _get_db_config(self) -> Dict[str, str]:
        """Get database configuration from environment or defaults"""
        return {
            "host": os.environ.get("POSTGRES_HOST", "localhost"),
            "port": os.environ.get("POSTGRES_PORT", "5432"),
            "user": os.environ.get("POSTGRES_USER", "postgres"),
            "password": os.environ.get("POSTGRES_PASSWORD", "postgres"),
            "database": os.environ.get("POSTGRES_DB", "postgres")
        }

    def _get_connection(self):
        """Get database connection"""
        return psycopg2.connect(
            host=self.db_config["host"],
            port=self.db_config["port"],
            user=self.db_config["user"],
            password=self.db_config["password"],
            database=self.db_config["database"]
        )

    def set_reminder(
        self,
        text: str,
        remind_at: datetime | str,
        recurrence: Optional[str] = None,
        priority: str = "normal",
        category: Optional[str] = None,
        user_id: str = "damon"
    ) -> Reminder:
        """
        Create a new reminder.

        Args:
            text: Reminder text
            remind_at: When to remind (datetime or natural language string)
            recurrence: 'daily', 'weekly', 'monthly', 'yearly', or None
            priority: 'low', 'normal', 'high', 'urgent'
            category: Optional category
            user_id: User ID

        Returns:
            Created Reminder object
        """
        # Parse natural language time if string
        if isinstance(remind_at, str):
            parsed = self.time_context.parse_natural_time(remind_at)
            if parsed is None:
                raise ValueError(f"Could not parse time: {remind_at}")
            remind_at = parsed

        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO aria_reminders (
                        user_id, reminder_text, remind_at, recurrence, priority, category
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING *
                """, (user_id, text, remind_at, recurrence, priority, category))

                row = cur.fetchone()
                conn.commit()

                return self._row_to_reminder(row)

    def get_upcoming_reminders(
        self,
        hours: int = 24,
        user_id: str = "damon"
    ) -> List[Dict[str, Any]]:
        """
        Get reminders coming up in the next N hours.

        Args:
            hours: Hours to look ahead
            user_id: User ID

        Returns:
            List of upcoming reminders with time_until info
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM get_upcoming_reminders(%s, %s)
                """, (user_id, hours))

                rows = cur.fetchall()
                return [dict(row) for row in rows]

    def get_overdue_reminders(self, user_id: str = "damon") -> List[Dict[str, Any]]:
        """
        Get reminders that are past due.

        Args:
            user_id: User ID

        Returns:
            List of overdue reminders with overdue_by info
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM get_overdue_reminders(%s)
                """, (user_id,))

                rows = cur.fetchall()
                return [dict(row) for row in rows]

    def complete_reminder(self, reminder_id: str) -> Dict[str, Any]:
        """
        Mark a reminder as completed.

        Args:
            reminder_id: UUID of the reminder

        Returns:
            Result dict with success, message, and next_reminder_id (for recurring)
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM complete_reminder(%s)
                """, (reminder_id,))

                row = cur.fetchone()
                conn.commit()

                return dict(row) if row else {"success": False, "message": "Unknown error"}

    def snooze_reminder(self, reminder_id: str, minutes: int = 30) -> bool:
        """
        Snooze a reminder.

        Args:
            reminder_id: UUID of the reminder
            minutes: Minutes to snooze

        Returns:
            True if successful
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT snooze_reminder(%s, %s)
                """, (reminder_id, minutes))

                result = cur.fetchone()[0]
                conn.commit()

                return result

    def delete_reminder(self, reminder_id: str) -> bool:
        """
        Delete a reminder.

        Args:
            reminder_id: UUID of the reminder

        Returns:
            True if successful
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    DELETE FROM aria_reminders WHERE id = %s
                """, (reminder_id,))

                deleted = cur.rowcount > 0
                conn.commit()

                return deleted

    def get_reminder_summary(self, user_id: str = "damon") -> Dict[str, int]:
        """
        Get reminder summary statistics.

        Args:
            user_id: User ID

        Returns:
            Dict with counts of overdue, upcoming, active reminders
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM aria_reminder_summary WHERE user_id = %s
                """, (user_id,))

                row = cur.fetchone()
                if row:
                    return dict(row)
                return {
                    "overdue_count": 0,
                    "upcoming_soon": 0,
                    "upcoming_today": 0,
                    "total_active": 0,
                    "completed_this_week": 0
                }

    def get_proactive_message(self, user_id: str = "damon") -> Optional[str]:
        """
        Generate proactive reminder message for conversation start.

        Args:
            user_id: User ID

        Returns:
            Natural language message about reminders, or None
        """
        overdue = self.get_overdue_reminders(user_id)
        upcoming = self.get_upcoming_reminders(hours=2, user_id=user_id)

        messages = []

        if overdue:
            if len(overdue) == 1:
                r = overdue[0]
                messages.append(f"You have an overdue reminder: \"{r['reminder_text']}\"")
            else:
                messages.append(f"You have {len(overdue)} overdue reminders:")
                for r in overdue[:3]:  # Show max 3
                    messages.append(f"  - {r['reminder_text']}")
                if len(overdue) > 3:
                    messages.append(f"  ... and {len(overdue) - 3} more")

        if upcoming:
            for r in upcoming[:2]:  # Show max 2
                time_until = r['time_until']
                if isinstance(time_until, timedelta):
                    minutes = int(time_until.total_seconds() / 60)
                    if minutes < 60:
                        time_str = f"in {minutes} minutes"
                    else:
                        hours = minutes // 60
                        time_str = f"in {hours} hour{'s' if hours > 1 else ''}"
                else:
                    time_str = "soon"
                messages.append(f"Reminder coming up {time_str}: \"{r['reminder_text']}\"")

        if messages:
            return "\n".join(messages)
        return None

    def _row_to_reminder(self, row: Dict) -> Reminder:
        """Convert database row to Reminder object"""
        return Reminder(
            id=str(row['id']),
            user_id=row['user_id'],
            reminder_text=row['reminder_text'],
            remind_at=row['remind_at'],
            created_at=row['created_at'],
            completed=row['completed'],
            completed_at=row['completed_at'],
            snoozed_until=row.get('snoozed_until'),
            snooze_count=row.get('snooze_count', 0),
            recurrence=row.get('recurrence'),
            recurrence_end_date=row.get('recurrence_end_date'),
            priority=row.get('priority', 'normal'),
            category=row.get('category'),
            metadata=row.get('metadata', {}),
            source=row.get('source', 'aria')
        )


# Convenience functions for n8n code nodes
def set_reminder(text: str, remind_at: str, recurrence: str = None) -> Dict:
    """Create a reminder (for n8n)"""
    manager = ReminderManager()
    reminder = manager.set_reminder(text, remind_at, recurrence)
    return reminder.to_dict()


def get_upcoming(hours: int = 24) -> List[Dict]:
    """Get upcoming reminders (for n8n)"""
    manager = ReminderManager()
    return manager.get_upcoming_reminders(hours)


def get_overdue() -> List[Dict]:
    """Get overdue reminders (for n8n)"""
    manager = ReminderManager()
    return manager.get_overdue_reminders()


def complete(reminder_id: str) -> Dict:
    """Complete a reminder (for n8n)"""
    manager = ReminderManager()
    return manager.complete_reminder(reminder_id)


def get_proactive_message() -> Optional[str]:
    """Get proactive reminder message (for n8n)"""
    manager = ReminderManager()
    return manager.get_proactive_message()


if __name__ == "__main__":
    import sys

    # Test with Docker connection
    manager = ReminderManager({
        "host": "localhost",
        "port": "5432",
        "user": "postgres",
        "password": "postgres",
        "database": "postgres"
    })

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "test":
            # Create a test reminder
            reminder = manager.set_reminder(
                "Test reminder from Python",
                "in 1 hour",
                priority="normal"
            )
            print(f"Created reminder: {reminder.id}")
            print(json.dumps(reminder.to_dict(), indent=2, default=str))

        elif command == "upcoming":
            hours = int(sys.argv[2]) if len(sys.argv) > 2 else 24
            reminders = manager.get_upcoming_reminders(hours)
            print(f"Upcoming reminders ({hours}h):")
            print(json.dumps(reminders, indent=2, default=str))

        elif command == "overdue":
            reminders = manager.get_overdue_reminders()
            print("Overdue reminders:")
            print(json.dumps(reminders, indent=2, default=str))

        elif command == "summary":
            summary = manager.get_reminder_summary()
            print("Reminder summary:")
            print(json.dumps(summary, indent=2, default=str))

        elif command == "proactive":
            msg = manager.get_proactive_message()
            if msg:
                print(msg)
            else:
                print("No reminders to surface")

        elif command == "complete" and len(sys.argv) > 2:
            result = manager.complete_reminder(sys.argv[2])
            print(json.dumps(result, indent=2, default=str))

    else:
        print("Usage: python reminders.py <command> [args]")
        print("Commands: test, upcoming [hours], overdue, summary, proactive, complete <id>")
