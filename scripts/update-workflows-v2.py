#!/usr/bin/env python3
"""Update n8n workflows with new system prompt and normalize input code."""

import json
import subprocess
import tempfile
import os

def get_workflow(workflow_id):
    """Get workflow from database."""
    cmd = f"""docker exec n8n-postgres psql -U n8n -d n8n -t -c "SELECT nodes FROM workflow_entity WHERE id = '{workflow_id}'" """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting workflow: {result.stderr}")
        return None
    return result.stdout.strip()

def update_workflow_via_file(workflow_id, nodes_json):
    """Update workflow using a SQL file."""
    # Escape single quotes for SQL
    escaped = nodes_json.replace("'", "''")

    sql = f"""UPDATE workflow_entity SET nodes = '{escaped}', "updatedAt" = NOW() WHERE id = '{workflow_id}';"""

    # Write SQL to a temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False) as f:
        f.write(sql)
        sql_file = f.name

    try:
        # Copy file to container
        subprocess.run(f"docker cp {sql_file} n8n-postgres:/tmp/update.sql", shell=True, check=True)

        # Execute SQL file
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
    # Read the new system prompt
    with open('/home/damon/aria-assistant/n8n-workflows/system-prompt-update.txt', 'r') as f:
        new_system_prompt = f.read()

    # Read the new normalize input code
    with open('/home/damon/aria-assistant/n8n-workflows/normalize-input-update.js', 'r') as f:
        new_normalize_code = f.read()

    # Update AI Agent Main workflow
    print("=" * 60)
    print("Updating AI Agent Main workflow...")
    print("=" * 60)
    nodes_json = get_workflow('aX8d9zWniCYaIDwc')
    if nodes_json:
        try:
            nodes = json.loads(nodes_json)
            for node in nodes:
                if node.get('name') == 'AI Agent':
                    if 'parameters' in node and 'options' in node['parameters']:
                        node['parameters']['options']['systemMessage'] = new_system_prompt
                        print("  Found and updated AI Agent system prompt")

            updated_json = json.dumps(nodes)
            if update_workflow_via_file('aX8d9zWniCYaIDwc', updated_json):
                print("  SUCCESS: AI Agent Main workflow updated!")
            else:
                print("  FAILED: Could not update AI Agent Main workflow")
        except json.JSONDecodeError as e:
            print(f"  Error parsing nodes JSON: {e}")

    # Update Calendar Read workflow
    print("\n" + "=" * 60)
    print("Updating Calendar Read workflow...")
    print("=" * 60)
    nodes_json = get_workflow('PGD0swPc7EDaWiZp')
    if nodes_json:
        try:
            nodes = json.loads(nodes_json)
            for node in nodes:
                if node.get('name') == 'Normalize Input':
                    if 'parameters' in node:
                        node['parameters']['jsCode'] = new_normalize_code
                        print("  Found and updated Normalize Input code")

            updated_json = json.dumps(nodes)
            if update_workflow_via_file('PGD0swPc7EDaWiZp', updated_json):
                print("  SUCCESS: Calendar Read workflow updated!")
            else:
                print("  FAILED: Could not update Calendar Read workflow")
        except json.JSONDecodeError as e:
            print(f"  Error parsing nodes JSON: {e}")

    print("\n" + "=" * 60)
    print("DONE! Changes applied to database.")
    print("Note: n8n should pick up changes automatically.")
    print("=" * 60)

if __name__ == '__main__':
    main()
