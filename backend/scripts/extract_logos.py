import os
import re
import base64

p = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "bases_frontend", "aviso_cobranza", "aviso.html"))
with open(p, "r", encoding="utf-8") as f:
    html = f.read()

m_cosmol = re.search(r'class="logo-cosmol"[^>]*src="data:image/png;base64,([^"]+)"', html)
m_aaps = re.search(r'class="logo-aaps"[^>]*src="data:image/png;base64,([^"]+)"', html)

cosmol_b64 = m_cosmol.group(1) if m_cosmol else ""
aaps_b64 = m_aaps.group(1) if m_aaps else ""

print(f"COSMOL b64 len: {len(cosmol_b64)}, decodes: {len(base64.b64decode(cosmol_b64))}")
print(f"AAPS b64 len: {len(aaps_b64)}, decodes: {len(base64.b64decode(aaps_b64))}")

# Write to backend/app/services/logos_aviso.py
out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "app", "services", "logos_aviso.py"))
with open(out_path, "w", encoding="utf-8") as f:
    f.write('"""Logos oficiales extraídos en alta resolución para Aviso de Cobranza."""\n')
    f.write(f'LOGO_COSMOL_B64 = {repr(cosmol_b64)}\n\n')
    f.write(f'LOGO_AAPS_B64 = {repr(aaps_b64)}\n')

print(f"Saved to {out_path}")
