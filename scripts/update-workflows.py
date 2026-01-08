#!/usr/bin/env python3
"""Update n8n workflows with new system prompt and normalize input code."""

import json
import subprocess
import sys

def get_workflow(workflow_id):
    """Get workflow from database."""
    cmd = f"""docker exec n8n-postgres psql -U n8n -d n8n -t -c "SELECT nodes FROM workflow_entity WHERE id = '{workflow_id}'" """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting workflow: {result.stderr}")
        return None
    return result.stdout.strip()

def update_workflow(workflow_id, nodes_json):
    """Update workflow in database."""
    # Escape for SQL
    escaped = nodes_json.replace("'", "''")
    cmd = f"""docker exec n8n-postgres psql -U n8n -d n8n -c "UPDATE workflow_entity SET nodes = '{escaped}', \"updatedAt\" = NOW() WHERE id = '{workflow_id}'" """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error updating workflow: {result.stderr}")
        return False
    print(f"Updated workflow {workflow_id}")
    return True

def main():
    # Read the new system prompt
    with open('/home/damon/aria-assistant/n8n-workflows/system-prompt-update.txt', 'r') as f:
        new_system_prompt = f.read()

    # Read the new normalize input code
    with open('/home/damon/aria-assistant/n8n-workflows/normalize-input-update.js', 'r') as f:
        new_normalize_code = f.read()

    # Update AI Agent Main workflow
    print("Updating AI Agent Main workflow...")
    nodes_json = get_workflow('aX8d9zWniCYaIDwc')
    if nodes_json:
        try:
            nodes = json.loads(nodes_json)
            for node in nodes:
                if node.get('name') == 'AI Agent':
                    if 'parameters' in node and 'options' in node['parameters']:
                        node['parameters']['options']['systemMessage'] = new_system_prompt
                        print("  Updated AI Agent system prompt")

            updated_json = json.dumps(nodes)
            if update_workflow('aX8d9zWniCYaIDwc', updated_json):
                print("  AI Agent Main workflow updated successfully!")
            else:
                print("  Failed to update AI Agent Main workflow")
        except json.JSONDecodeError as e:
            print(f"  Error parsing nodes JSON: {e}")

    # Update Calendar Read workflow
    print("\nUpdating Calendar Read workflow...")
    nodes_json = get_workflow('PGD0swPc7EDaWiZp')
    if nodes_json:
        try:
            nodes = json.loads(nodes_json)
            for node in nodes:
                if node.get('name') == 'Normalize Input':
                    if 'parameters' in node:
                        node['parameters']['jsCode'] = new_normalize_code
                        print("  Updated Normalize Input code")

            updated_json = json.dumps(nodes)
            if update_workflow('PGD0swPc7EDaWiZp', updated_json):
                print("  Calendar Read workflow updated successfully!")
            else:
                print("  Failed to update Calendar Read workflow")
        except json.JSONDecodeError as e:
            print(f"  Error parsing nodes JSON: {e}")

    print("\nDone! Restart n8n to apply changes.")

if __name__ == '__main__':
    main()
