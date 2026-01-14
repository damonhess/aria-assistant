#!/bin/bash
# ARIA Reminder CLI Utility
# Usage: ./reminder-cli.sh <command> [args]

CONTAINER="supabase-db"
DB_USER="postgres"
DB_NAME="postgres"

psql_cmd() {
    docker exec $CONTAINER psql -U $DB_USER -d $DB_NAME -t -A -c "$1"
}

psql_query() {
    docker exec $CONTAINER psql -U $DB_USER -d $DB_NAME -c "$1"
}

case "$1" in
    set)
        # Usage: ./reminder-cli.sh set "reminder text" "time expression" [recurrence] [priority]
        TEXT="$2"
        TIME="$3"
        RECURRENCE="${4:-NULL}"
        PRIORITY="${5:-normal}"

        if [ -z "$TEXT" ] || [ -z "$TIME" ]; then
            echo "Usage: $0 set \"text\" \"time\" [recurrence] [priority]"
            echo "Time examples: 'NOW() + INTERVAL 1 hour', '2026-01-15 09:00:00'"
            exit 1
        fi

        # Handle recurrence NULL
        if [ "$RECURRENCE" = "NULL" ]; then
            RECURRENCE_SQL="NULL"
        else
            RECURRENCE_SQL="'$RECURRENCE'"
        fi

        SQL="INSERT INTO aria_reminders (reminder_text, remind_at, recurrence, priority)
             VALUES ('$TEXT', $TIME, $RECURRENCE_SQL, '$PRIORITY')
             RETURNING id, reminder_text, remind_at, priority;"
        psql_query "$SQL"
        ;;

    upcoming)
        # Usage: ./reminder-cli.sh upcoming [hours]
        HOURS="${2:-24}"
        psql_query "SELECT * FROM get_upcoming_reminders('damon', $HOURS);"
        ;;

    overdue)
        psql_query "SELECT * FROM get_overdue_reminders('damon');"
        ;;

    complete)
        # Usage: ./reminder-cli.sh complete <reminder_id>
        ID="$2"
        if [ -z "$ID" ]; then
            echo "Usage: $0 complete <reminder_id>"
            exit 1
        fi
        psql_query "SELECT * FROM complete_reminder('$ID');"
        ;;

    snooze)
        # Usage: ./reminder-cli.sh snooze <reminder_id> [minutes]
        ID="$2"
        MINUTES="${3:-30}"
        if [ -z "$ID" ]; then
            echo "Usage: $0 snooze <reminder_id> [minutes]"
            exit 1
        fi
        psql_query "SELECT snooze_reminder('$ID', $MINUTES);"
        ;;

    delete)
        # Usage: ./reminder-cli.sh delete <reminder_id>
        ID="$2"
        if [ -z "$ID" ]; then
            echo "Usage: $0 delete <reminder_id>"
            exit 1
        fi
        psql_query "DELETE FROM aria_reminders WHERE id = '$ID' RETURNING id, reminder_text;"
        ;;

    summary)
        psql_query "SELECT * FROM aria_reminder_summary WHERE user_id = 'damon';"
        ;;

    list)
        # List all active reminders
        psql_query "SELECT id, reminder_text, remind_at, priority, recurrence
                    FROM aria_reminders
                    WHERE user_id = 'damon' AND NOT completed
                    ORDER BY remind_at;"
        ;;

    proactive)
        # Get proactive message for conversation start
        echo "=== Overdue Reminders ==="
        psql_query "SELECT reminder_text, remind_at, NOW() - remind_at as overdue_by
                    FROM aria_reminders
                    WHERE user_id = 'damon' AND NOT completed AND remind_at < NOW()
                    ORDER BY remind_at;"
        echo ""
        echo "=== Upcoming (next 2 hours) ==="
        psql_query "SELECT reminder_text, remind_at, remind_at - NOW() as time_until
                    FROM aria_reminders
                    WHERE user_id = 'damon' AND NOT completed
                      AND remind_at BETWEEN NOW() AND NOW() + INTERVAL '2 hours'
                    ORDER BY remind_at;"
        ;;

    time)
        # Show current time context
        echo "Current time: $(date '+%A, %B %d, %Y at %I:%M %p %Z')"
        echo "Timezone: $(cat /etc/timezone 2>/dev/null || echo 'Unknown')"
        ;;

    *)
        echo "ARIA Reminder CLI"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  set \"text\" \"time\" [recurrence] [priority]  Create a reminder"
        echo "  upcoming [hours]                             List upcoming reminders"
        echo "  overdue                                      List overdue reminders"
        echo "  complete <id>                                Mark reminder as done"
        echo "  snooze <id> [minutes]                        Snooze a reminder"
        echo "  delete <id>                                  Delete a reminder"
        echo "  summary                                      Show reminder statistics"
        echo "  list                                         List all active reminders"
        echo "  proactive                                    Get proactive message"
        echo "  time                                         Show current time"
        echo ""
        echo "Time formats for 'set':"
        echo "  NOW() + INTERVAL '1 hour'"
        echo "  NOW() + INTERVAL '30 minutes'"
        echo "  '2026-01-15 09:00:00'"
        echo "  NOW() + INTERVAL '1 day'"
        echo ""
        echo "Recurrence options: daily, weekly, monthly, yearly"
        echo "Priority options: low, normal, high, urgent"
        ;;
esac
