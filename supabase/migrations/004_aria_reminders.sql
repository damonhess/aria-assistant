-- ARIA Reminders System
-- Adds reminder functionality with recurring support
-- Created: January 14, 2026

-- Reminders table
CREATE TABLE IF NOT EXISTS aria_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT DEFAULT 'damon',
  reminder_text TEXT NOT NULL,
  remind_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  snoozed_until TIMESTAMPTZ,
  snooze_count INTEGER DEFAULT 0,
  recurrence TEXT CHECK (recurrence IN ('daily', 'weekly', 'monthly', 'yearly', NULL)),
  recurrence_end_date TIMESTAMPTZ,
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  category TEXT,
  metadata JSONB DEFAULT '{}',
  source TEXT DEFAULT 'aria' -- 'aria', 'calendar', 'task', 'manual'
);

-- Index for querying active reminders by time
CREATE INDEX idx_reminders_remind_at ON aria_reminders(remind_at)
  WHERE NOT completed AND (snoozed_until IS NULL OR snoozed_until < NOW());

-- Index for user's reminders
CREATE INDEX idx_reminders_user ON aria_reminders(user_id, remind_at)
  WHERE NOT completed;

-- Index for overdue reminders
CREATE INDEX idx_reminders_overdue ON aria_reminders(remind_at)
  WHERE NOT completed AND remind_at < NOW();

-- Index for recurring reminders
CREATE INDEX idx_reminders_recurring ON aria_reminders(recurrence, remind_at)
  WHERE recurrence IS NOT NULL AND NOT completed;

-- Function to get upcoming reminders
CREATE OR REPLACE FUNCTION get_upcoming_reminders(
  p_user_id TEXT DEFAULT 'damon',
  p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  id UUID,
  reminder_text TEXT,
  remind_at TIMESTAMPTZ,
  priority TEXT,
  category TEXT,
  time_until INTERVAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.reminder_text,
    r.remind_at,
    r.priority,
    r.category,
    r.remind_at - NOW() as time_until
  FROM aria_reminders r
  WHERE r.user_id = p_user_id
    AND NOT r.completed
    AND (r.snoozed_until IS NULL OR r.snoozed_until < NOW())
    AND r.remind_at BETWEEN NOW() AND NOW() + (p_hours || ' hours')::INTERVAL
  ORDER BY r.remind_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get overdue reminders
CREATE OR REPLACE FUNCTION get_overdue_reminders(
  p_user_id TEXT DEFAULT 'damon'
)
RETURNS TABLE (
  id UUID,
  reminder_text TEXT,
  remind_at TIMESTAMPTZ,
  priority TEXT,
  category TEXT,
  overdue_by INTERVAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.reminder_text,
    r.remind_at,
    r.priority,
    r.category,
    NOW() - r.remind_at as overdue_by
  FROM aria_reminders r
  WHERE r.user_id = p_user_id
    AND NOT r.completed
    AND (r.snoozed_until IS NULL OR r.snoozed_until < NOW())
    AND r.remind_at < NOW()
  ORDER BY r.remind_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to complete a reminder (and handle recurrence)
CREATE OR REPLACE FUNCTION complete_reminder(
  p_reminder_id UUID
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  next_reminder_id UUID
) AS $$
DECLARE
  v_reminder aria_reminders%ROWTYPE;
  v_next_id UUID;
  v_next_remind_at TIMESTAMPTZ;
BEGIN
  -- Get the reminder
  SELECT * INTO v_reminder FROM aria_reminders WHERE id = p_reminder_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Reminder not found'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF v_reminder.completed THEN
    RETURN QUERY SELECT FALSE, 'Reminder already completed'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  -- Mark as completed
  UPDATE aria_reminders
  SET completed = TRUE, completed_at = NOW()
  WHERE id = p_reminder_id;

  -- Handle recurrence
  IF v_reminder.recurrence IS NOT NULL THEN
    -- Calculate next reminder time
    v_next_remind_at := CASE v_reminder.recurrence
      WHEN 'daily' THEN v_reminder.remind_at + INTERVAL '1 day'
      WHEN 'weekly' THEN v_reminder.remind_at + INTERVAL '1 week'
      WHEN 'monthly' THEN v_reminder.remind_at + INTERVAL '1 month'
      WHEN 'yearly' THEN v_reminder.remind_at + INTERVAL '1 year'
    END;

    -- Only create next if before end date
    IF v_reminder.recurrence_end_date IS NULL OR v_next_remind_at <= v_reminder.recurrence_end_date THEN
      INSERT INTO aria_reminders (
        user_id, reminder_text, remind_at, recurrence,
        recurrence_end_date, priority, category, metadata, source
      )
      VALUES (
        v_reminder.user_id, v_reminder.reminder_text, v_next_remind_at,
        v_reminder.recurrence, v_reminder.recurrence_end_date,
        v_reminder.priority, v_reminder.category, v_reminder.metadata, v_reminder.source
      )
      RETURNING id INTO v_next_id;

      RETURN QUERY SELECT TRUE, 'Completed. Next reminder created.'::TEXT, v_next_id;
      RETURN;
    END IF;
  END IF;

  RETURN QUERY SELECT TRUE, 'Reminder completed'::TEXT, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

-- Function to snooze a reminder
CREATE OR REPLACE FUNCTION snooze_reminder(
  p_reminder_id UUID,
  p_snooze_minutes INTEGER DEFAULT 30
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE aria_reminders
  SET
    snoozed_until = NOW() + (p_snooze_minutes || ' minutes')::INTERVAL,
    snooze_count = snooze_count + 1
  WHERE id = p_reminder_id AND NOT completed;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- View for reminder summary
CREATE OR REPLACE VIEW aria_reminder_summary AS
SELECT
  user_id,
  COUNT(*) FILTER (WHERE NOT completed AND remind_at < NOW()) as overdue_count,
  COUNT(*) FILTER (WHERE NOT completed AND remind_at BETWEEN NOW() AND NOW() + INTERVAL '2 hours') as upcoming_soon,
  COUNT(*) FILTER (WHERE NOT completed AND remind_at BETWEEN NOW() AND NOW() + INTERVAL '24 hours') as upcoming_today,
  COUNT(*) FILTER (WHERE NOT completed) as total_active,
  COUNT(*) FILTER (WHERE completed AND completed_at > NOW() - INTERVAL '7 days') as completed_this_week
FROM aria_reminders
GROUP BY user_id;

COMMENT ON TABLE aria_reminders IS 'User reminders with recurrence support';
COMMENT ON FUNCTION get_upcoming_reminders IS 'Get reminders due in the next N hours';
COMMENT ON FUNCTION get_overdue_reminders IS 'Get reminders that are past due';
COMMENT ON FUNCTION complete_reminder IS 'Complete a reminder and handle recurrence';
COMMENT ON FUNCTION snooze_reminder IS 'Snooze a reminder for N minutes';
