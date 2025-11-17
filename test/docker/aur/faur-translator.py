#!/usr/bin/env python3
"""
Faur API to AUR RPC v5 translator for aura support.

Translates Faur's query format to aurweb's RPC v5 format:
- Faur: GET /packages?names=foo,bar&by=desc
- RPC:  GET /rpc?v=5&type=search&by=name-desc&arg[]=foo&arg[]=bar
"""
import os
import sys
import urllib.parse
import urllib.request

def main():
    # Parse Faur query string
    query_string = os.environ.get('QUERY_STRING', '')
    query = urllib.parse.parse_qs(query_string)

    names_param = query.get('names', [''])[0]
    names = [n.strip() for n in names_param.split(',') if n.strip()]
    by = query.get('by', [None])[0]

    # Build AUR RPC v5 query based on operation type
    if not by:
        # Info query: /packages?names=foo,bar
        # -> /rpc?v=5&type=info&arg[]=foo&arg[]=bar
        rpc_query = 'v=5&type=info&' + '&'.join(f'arg[]={urllib.parse.quote(n)}' for n in names)
    elif by == 'prov':
        # Provides search: /packages?names=foo&by=prov
        # -> /rpc?v=5&type=search&by=provides&arg=foo
        rpc_query = f'v=5&type=search&by=provides&arg={urllib.parse.quote(names[0])}'
    elif by == 'desc':
        # Description search: /packages?names=foo,bar&by=desc
        # -> /rpc?v=5&type=search&by=name-desc&arg[]=foo&arg[]=bar
        rpc_query = 'v=5&type=search&by=name-desc&' + '&'.join(f'arg[]={urllib.parse.quote(n)}' for n in names)
    else:
        # Unknown operation
        sys.stdout.buffer.write(b'Status: 400 Bad Request\r\n')
        sys.stdout.buffer.write(b'Content-Type: application/json\r\n\r\n')
        sys.stdout.buffer.write(b'{"error":"Unknown operation type"}\n')
        return

    # Query aurweb RPC
    try:
        import json
        rpc_url = f'http://127.0.0.1:8000/rpc?{rpc_query}'
        resp = urllib.request.urlopen(rpc_url, timeout=30)
        body = resp.read()

        # AUR RPC v5 returns: {"version": 5, "type": "...", "resultcount": N, "results": [...]}
        # Faur returns: just the results array directly
        # Extract the "results" array from AUR RPC v5 response
        rpc_response = json.loads(body)
        faur_response = rpc_response.get('results', [])

        # Return response in Faur format (just the array)
        sys.stdout.buffer.write(b'Content-Type: application/json\r\n\r\n')
        sys.stdout.buffer.write(json.dumps(faur_response).encode('utf-8'))
    except Exception as e:
        # Return error as empty list (Faur convention)
        sys.stderr.write(f'Error querying aurweb: {e}\n')
        sys.stdout.buffer.write(b'Content-Type: application/json\r\n\r\n')
        sys.stdout.buffer.write(b'[]\n')

if __name__ == '__main__':
    main()
