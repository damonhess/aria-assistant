#!/usr/bin/env python3
"""Fix calendar_write delete operation by bypassing the broken Supabase node."""

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

    print("=" * 60)
    print("Fixing Calendar Write Delete Operation")
    print("=" * 60)

    # Get current workflow
    print("\n1. Getting current workflow...")
    nodes = get_workflow_nodes(workflow_id)
    connections = get_workflow_connections(workflow_id)

    if not nodes or not connections:
        print("Failed to get workflow")
        return

    print(f"   Found {len(nodes)} nodes")
    print(f"   Connections: {list(connections.keys())}")

    # Current delete path:
    # Route by Operation (output 2) -> Get Event Before Delete -> Store Deletion for Undo -> Delete After Storing
    #
    # Fix: Change connections so:
    # Route by Operation (output 2) -> Get Event Before Delete -> Delete After Storing (skip Supabase)

    print("\n2. Modifying connections to bypass Supabase node...")

    if "Get Event Before Delete" in connections:
        old_connection = connections["Get Event Before Delete"]
        print(f"   Old connection from 'Get Event Before Delete':")
        print(f"   {json.dumps(old_connection, indent=4)}")

        # Change destination from "Store Deletion for Undo" to "Delete After Storing"
        connections["Get Event Before Delete"] = {
            "main": [
                [
                    {"node": "Delete After Storing", "type": "main", "index": 0}
                ]
            ]
        }
        print(f"   New connection: Skip Supabase -> Direct to Delete After Storing")
    else:
        print("   WARNING: 'Get Event Before Delete' not found in connections!")
        print(f"   Available: {list(connections.keys())}")

    # Update "Delete After Storing" to reference event_id from Get Event Before Delete
    print("\n3. Updating Delete After Storing node to use correct event_id...")

    for node in nodes:
        if node.get('name') == 'Delete After Storing':
            old_eventId = node['parameters'].get('eventId', 'N/A')
            print(f"   Old eventId: {old_eventId}")

            # The event from Google Calendar has 'id' directly in the response
            node['parameters']['eventId'] = "={{ $('Get Event Before Delete').item.json.id }}"
            print(f"   New eventId: {node['parameters']['eventId']}")
            break
    else:
        print("   WARNING: 'Delete After Storing' node not found!")

    # Update the workflow
    print("\n4. Saving updated workflow to database...")
    if update_workflow(workflow_id, nodes, connections):
        print("   SUCCESS: Workflow updated!")
    else:
        print("   FAILED: Could not update workflow")
        return

    print("\n" + "=" * 60)
    print("FIX APPLIED: Delete now bypasses Supabase trash storage")
    print("=" * 60)

if __name__ == '__main__':
    main()
