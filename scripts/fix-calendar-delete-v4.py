#!/usr/bin/env python3
"""Fix calendar_write: Update Normalize Input to extract title from more fields."""

import json
import subprocess
import tempfile
import os

def get_workflow_nodes(workflow_id):
    """Get workflow nodes from database."""
    cmd = f"""docker exec n8n-postgres psql -U n8n -d n8n -t -A -c "SELECT nodes FROM workflow_entity WHERE id = '{workflow_id}'" """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting nodes: {result.stderr}")
        return None
    return json.loads(result.stdout.strip())

def update_workflow(workflow_id, nodes):
    """Update workflow in database."""
    nodes_json = json.dumps(nodes).replace("'", "''")

    sql = f"""UPDATE workflow_entity
SET nodes = '{nodes_json}',
    "updatedAt" = NOW()
WHERE id = '{workflow_id}';

UPDATE workflow_history
SET nodes = '{nodes_json}',
    "updatedAt" = NOW()
WHERE "workflowId" = '{workflow_id}'
AND "versionId" = (SELECT "activeVersionId" FROM workflow_entity WHERE id = '{workflow_id}');"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False) as f:
        f.write(sql)
        sql_file = f.name

    try:
        subprocess.run(f"docker cp {sql_file} n8n-postgres:/tmp/update.sql", shell=True, check=True)
        result = subprocess.run(
            "docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/update.sql",
            shell=True, capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"Error: {result.stderr}")
            return False
        print(f"Result: {result.stdout}")
        return "UPDATE" in result.stdout
    finally:
        os.unlink(sql_file)

def main():
    workflow_id = 'qhsZJgb6SCYUfApM'

    print("=" * 70)
    print("Fixing Calendar Write: Update Normalize Input for better title extraction")
    print("=" * 70)

    # New Normalize Input code with better title extraction for delete
    new_normalize_code = '''// Normalize Input - v6 with improved delete title extraction
let input = $json;
if ($json.query && typeof $json.query === 'object' && $json.query.operation) {
  input = $json.query;
}

// Handle undo/restore operation
if (input.operation === 'undo' || input.operation === 'restore') {
  return [{
    json: {
      operation: 'restore',
      user_id: input.user_id || '50850e59-bea0-4076-83e0-85d5c7004004',
      search_title: input.title || input.event_name || input.name || input.summary || null,
      deletion_id: input.deletion_id || null,
      restore_last: !input.title && !input.event_name && !input.name && !input.summary && !input.deletion_id
    }
  }];
}

// Handle empty_trash operation
if (input.operation === 'empty_trash') {
  return [{
    json: {
      operation: 'empty_trash',
      user_id: input.user_id || '50850e59-bea0-4076-83e0-85d5c7004004',
      confirm: input.confirm || false
    }
  }];
}

// Handle delete operation - extract title from multiple possible fields
if (input.operation === 'delete') {
  // Try to extract title from various possible field names
  // IMPORTANT: AI agent often puts the event title in 'query' field
  const title = input.title || input.summary || input.event_name || input.name || input.event_title || input.query || null;

  return [{
    json: {
      operation: 'delete',
      event_id: input.event_id || null,
      title: title,
      query: input.query || null,
      date: input.date || null,
      calendar_id: input.calendar_id || 'primary',
      user_id: input.user_id || '50850e59-bea0-4076-83e0-85d5c7004004'
    }
  }];
}

// Handle create operation
if (input.operation === 'create') {
  return [{
    json: {
      operation: 'create',
      title: input.title || input.summary || 'Untitled Event',
      start: input.start,
      end: input.end || (() => {
        if (input.start) {
          const startDate = new Date(input.start);
          startDate.setHours(startDate.getHours() + 1);
          return startDate.toISOString();
        }
        return null;
      })(),
      description: input.description || '',
      location: input.location || '',
      calendar_id: input.calendar_id || 'primary',
      attendees: input.attendees || [],
      user_id: input.user_id || '50850e59-bea0-4076-83e0-85d5c7004004'
    }
  }];
}

// Handle update operation
if (input.operation === 'update') {
  return [{
    json: {
      operation: 'update',
      event_id: input.event_id,
      title: input.title || input.summary,
      start: input.start,
      end: input.end,
      description: input.description,
      location: input.location,
      calendar_id: input.calendar_id || 'primary',
      user_id: input.user_id || '50850e59-bea0-4076-83e0-85d5c7004004'
    }
  }];
}

throw new Error('Invalid input: operation must be create, update, delete, restore, or empty_trash');
'''

    print("\n1. Getting current workflow...")
    nodes = get_workflow_nodes(workflow_id)
    if not nodes:
        print("Failed to get workflow")
        return

    print(f"   Found {len(nodes)} nodes")

    # Update Normalize Input node
    print("\n2. Updating Normalize Input code...")
    for node in nodes:
        if node.get('name') == 'Normalize Input':
            old_code = node['parameters'].get('jsCode', '')
            node['parameters']['jsCode'] = new_normalize_code
            print(f"   Updated Normalize Input (was v5, now v6)")
            break
    else:
        print("   ERROR: Could not find Normalize Input node")
        return

    # Update workflow
    print("\n3. Saving updated workflow to database and workflow_history...")
    if update_workflow(workflow_id, nodes):
        print("   SUCCESS: Workflow updated!")
    else:
        print("   FAILED: Could not update workflow")
        return

    print("\n" + "=" * 70)
    print("FIX APPLIED: Normalize Input now extracts title from more fields")
    print("Fields checked: title, summary, event_name, name, event_title")
    print("=" * 70)

if __name__ == '__main__':
    main()
