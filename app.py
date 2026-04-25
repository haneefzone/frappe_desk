"""
Frappe Desk - Entry point.
Run with: python app.py  (or use the `frappe-desk start` CLI)
"""
import os
from control_panel import create_app
from control_panel.services.worker import start_worker

app = create_app()

# Start the background worker thread exactly once, even under Flask's reloader.
if not app.debug or os.environ.get("WERKZEUG_RUN_MAIN") == "true":
    start_worker(app)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    host = os.environ.get("HOST", "127.0.0.1")
    app.run(host=host, port=port, debug=os.environ.get("FLASK_DEBUG") == "1")
