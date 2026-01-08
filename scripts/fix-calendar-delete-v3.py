#!/usr/bin/env python3
"""Fix calendar_write delete: Add event resolution by title when event_id is invalid."""

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

def get_workflow_connections(workflow_id):
    """Get workflow connections from database."""
    cmd = f"""docker exec n8n-postgres psql -U n8n -d n8n -t -A -c "SELECT connections FROM workflow_entity WHERE id = '{workflow_id}'" """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting connections: {result.stderr}")
        return None
    return json.loads(result.stdout.strip())

def update_workflow(workflow_id, nodes, connections):
    """Update workflow in database."""
    nodes_json = json.dumps(nodes).replace("'", "''")
    connections_json = json.dumps(connections).replace("'", "''")

    sql = f"""UPDATE workflow_entity
SET nodes = '{nodes_json}',
    connections = '{connections_json}',
    "updatedAt" = NOW()
WHERE id = '{workflow_id}';"""

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
        return "UPDATE 1" in result.stdout
    finally:
        os.unlink(sql_file)

def main():
    workflow_id = 'qhsZJgb6SCYUfApM'

    print("=" * 70)
    print("Fixing Calendar Write Delete: Add Event Resolution by Title")
    print("=" * 70)

    # Get current workflow
    print("\n1. Getting current workflow...")
    nodes = get_workflow_nodes(workflow_id)
    connections = get_workflow_connections(workflow_id)

    if not nodes or not connections:
        print("Failed to get workflow")
        return

    print(f"   Found {len(nodes)} nodes")

    # Find "Get Event Before Delete" position to place new node before it
    get_event_node = None
    for node in nodes:
        if node.get('name') == 'Get Event Before Delete':
            get_event_node = node
            break

    if not get_event_node:
        print("ERROR: Could not find 'Get Event Before Delete' node")
        return

    print(f"   Found 'Get Event Before Delete' at position {get_event_node['position']}")

    # Create new "Resolve Event for Delete" code node
    # This will search by title if event_id is invalid
    resolve_event_code = '''// Resolve Event for Delete - v1
// If event_id is invalid, search by title
const input = $('Normalize Input').first().json;
const eventId = input.event_id;
const title = input.title;
const calendarId = input.calendar_id || 'primary';

// Check if event_id looks like a valid Google Calendar ID
// Valid IDs are typically alphanumeric strings 20+ chars
const isValidEventId = eventId &&
    typeof eventId === 'string' &&
    eventId.length >= 10 &&
    /^[a-z0-9_]+$/i.test(eventId);

if (isValidEventId) {
    // Use provided event_id directly
    return [{
        json: {
            event_id: eventId,
            calendar_id: calendarId,
            resolved_by: 'direct_id',
            title: title
        }
    }];
}

// If we have a title, we'll need to search - pass it through
// The next node (Google Calendar Get) will try to use the title
if (title) {
    return [{
        json: {
            event_id: null,
            search_title: title,
            calendar_id: calendarId,
            resolved_by: 'need_search',
            title: title
        }
    }];
}

// No valid event_id and no title - error
throw new Error('Delete requires either a valid event_id or title to search for');
'''

    # Create the new node
    new_node = {
        "id": "resolve-event-delete",
        "name": "Resolve Event for Delete",
        "type": "n8n-nodes-base.code",
        "position": [get_event_node['position'][0] - 200, get_event_node['position'][1]],
        "typeVersion": 1,
        "parameters": {
            "jsCode": resolve_event_code
        }
    }

    print("\n2. Adding 'Resolve Event for Delete' node...")

    # Check if node already exists
    existing_resolve = next((n for n in nodes if n.get('name') == 'Resolve Event for Delete'), None)
    if existing_resolve:
        print("   Node already exists - updating...")
        existing_resolve['parameters']['jsCode'] = resolve_event_code
    else:
        print("   Creating new node...")
        nodes.append(new_node)

    # Update connections:
    # Route by Operation (delete output) -> Resolve Event for Delete -> Get Event Before Delete
    print("\n3. Updating connections...")

    # Update Route by Operation to connect to Resolve Event instead of Get Event
    if "Route by Operation" in connections:
        route_outputs = connections["Route by Operation"].get("main", [])
        # Output index 2 is delete (0=create, 1=update, 2=delete, 3=restore, 4=empty_trash)
        if len(route_outputs) > 2:
            print(f"   Old delete output: {route_outputs[2]}")
            route_outputs[2] = [{"node": "Resolve Event for Delete", "type": "main", "index": 0}]
            print(f"   New delete output: {route_outputs[2]}")

    # Add connection from Resolve Event to Get Event Before Delete
    connections["Resolve Event for Delete"] = {
        "main": [
            [{"node": "Search Event by Title", "type": "main", "index": 0}]
        ]
    }

    # Now we need to add a search node since Get Event needs an ID
    # Add a Google Calendar node that searches by title
    search_node = {
        "id": "search-event-title",
        "name": "Search Event by Title",
        "type": "n8n-nodes-base.googleCalendar",
        "position": [get_event_node['position'][0] - 100, get_event_node['position'][1]],
        "typeVersion": 1,
        "parameters": {
            "operation": "getAll",
            "calendar": "={{ $json.calendar_id || 'primary' }}",
            "returnAll": False,
            "limit": 10,
            "options": {
                "query": "={{ $json.search_title || $json.title || '' }}",
                "timeMin": "={{ new Date(Date.now() - 30*24*60*60*1000).toISOString() }}",
                "timeMax": "={{ new Date(Date.now() + 365*24*60*60*1000).toISOString() }}"
            }
        },
        "credentials": {
            "googleCalendarOAuth2Api": {
                "id": "wUsrGLavGaeKAELD",
                "name": "Google Calendar account"
            }
        }
    }

    # Check if search node exists
    existing_search = next((n for n in nodes if n.get('name') == 'Search Event by Title'), None)
    if existing_search:
        print("   Search node already exists - updating...")
        existing_search['parameters'] = search_node['parameters']
    else:
        print("   Creating Search Event by Title node...")
        nodes.append(search_node)

    # Add a code node to select the matching event from search results
    select_event_code = '''// Select Event from Search Results - v1
const input = $('Resolve Event for Delete').first().json;
const searchResults = $input.all();

// If we had a direct event_id, just pass it through
if (input.resolved_by === 'direct_id' && input.event_id) {
    return [{
        json: {
            id: input.event_id,
            summary: input.title || 'Unknown',
            _source: 'direct_id'
        }
    }];
}

// Search for matching event by title
const searchTitle = (input.search_title || input.title || '').toLowerCase();

if (!searchResults || searchResults.length === 0) {
    throw new Error(`No events found matching "${searchTitle}". The event may have already been deleted or doesn't exist.`);
}

// Find exact or close match
let match = null;

// Try exact match first
match = searchResults.find(e =>
    (e.json.summary || '').toLowerCase() === searchTitle
);

// Try contains match
if (!match) {
    match = searchResults.find(e =>
        (e.json.summary || '').toLowerCase().includes(searchTitle) ||
        searchTitle.includes((e.json.summary || '').toLowerCase())
    );
}

if (!match) {
    const available = searchResults.slice(0, 5).map(e => e.json.summary).join(', ');
    throw new Error(`No event matching "${input.search_title}" found. Available events: ${available}`);
}

return [{
    json: {
        ...match.json,
        _source: 'search'
    }
}];
'''

    select_node = {
        "id": "select-event-delete",
        "name": "Select Event to Delete",
        "type": "n8n-nodes-base.code",
        "position": [get_event_node['position'][0], get_event_node['position'][1] - 100],
        "typeVersion": 1,
        "parameters": {
            "jsCode": select_event_code
        }
    }

    existing_select = next((n for n in nodes if n.get('name') == 'Select Event to Delete'), None)
    if existing_select:
        print("   Select Event node already exists - updating...")
        existing_select['parameters']['jsCode'] = select_event_code
    else:
        print("   Creating Select Event to Delete node...")
        nodes.append(select_node)

    # Update connections
    connections["Search Event by Title"] = {
        "main": [
            [{"node": "Select Event to Delete", "type": "main", "index": 0}]
        ]
    }

    # Select Event goes directly to Delete (skip Get Event Before Delete since we already have the event)
    connections["Select Event to Delete"] = {
        "main": [
            [{"node": "Delete After Storing", "type": "main", "index": 0}]
        ]
    }

    # Update Delete After Storing to use the selected event's ID
    print("\n4. Updating Delete After Storing to use resolved event ID...")
    for node in nodes:
        if node.get('name') == 'Delete After Storing':
            node['parameters']['eventId'] = "={{ $('Select Event to Delete').item.json.id }}"
            print(f"   Updated eventId: {node['parameters']['eventId']}")
            break

    # Remove the now-orphaned Get Event Before Delete connection (it's no longer in the delete path)
    # But keep the node for potential future use
    if "Get Event Before Delete" in connections:
        del connections["Get Event Before Delete"]
        print("   Removed orphaned 'Get Event Before Delete' connection")

    # Update workflow
    print("\n5. Saving updated workflow to database...")
    if update_workflow(workflow_id, nodes, connections):
        print("   SUCCESS: Workflow updated!")
    else:
        print("   FAILED: Could not update workflow")
        return

    print("\n" + "=" * 70)
    print("FIX APPLIED: Delete now resolves events by title if event_id is invalid")
    print("New delete path:")
    print("  Route by Operation -> Resolve Event for Delete -> Search Event by Title")
    print("  -> Select Event to Delete -> Delete After Storing -> Format Response")
    print("=" * 70)

if __name__ == '__main__':
    main()
