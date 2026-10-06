import re
import os
import base64
import io
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors

def extract_logos():
    html_path = os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "bases_frontend", "aviso_cobranza", "aviso.html")
    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()

    cosmol_match = re.search(r'class="logo-cosmol"[^>]*src="data:image/png;base64,([^"]+)"', content)
    aaps_match = re.search(r'class="logo-aaps"[^>]*src="data:image/png;base64,([^"]+)"', content)

    cosmol_bytes = base64.b64decode(cosmol_match.group(1)) if cosmol_match else None
    aaps_bytes = base64.b64decode(aaps_match.group(1)) if aaps_match else None
    return cosmol_bytes, aaps_bytes

print("Extract logos test...")
c_bytes, a_bytes = extract_logos()
print(f"COSMOL logo bytes: {len(c_bytes) if c_bytes else 0}, AAPS logo bytes: {len(a_bytes) if a_bytes else 0}")
