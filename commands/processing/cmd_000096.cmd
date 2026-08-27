{
  "version": "0.1",
  "id": "cmd_000096",
  "title": "Escaneo del place actual y del repo (demo formato .cmd)",
  "created_by": "notion-agent",
  "created_at": "2026-08-27T17:05:00Z",
  "request": "Escanear el workspace actual de Roblox Studio y el repo completo. Resultados en snapshots/.",
  "options": { "atomic": false, "dry_run": false, "create_waypoint": false },
  "operations": [
    { "op": "scan_workspace", "id": "op_1", "max_depth": 6, "max_nodes": 3000, "include_source": true },
    { "op": "scan_repo", "id": "op_2", "max_files": 500 },
    { "op": "lint_scripts", "id": "op_3", "max_findings": 50 }
  ]
}
