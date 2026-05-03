import re
import json

with open('/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/docs/06_Prompty do raportów.md', 'r') as f:
    text = f.read()

# We'll extract sections separated by `- ` or `**` (e.g. `- Uniwersalny`, `- Poznawczo-Behawioralny (CBT)`)
# Actually, the file is relatively small. I can just write the migration manually or with a simple regex.

sections = text.split('\n- ')
# first element might be empty or prelude
modalities = []

for section in sections[1:]:
    # first line is the name
    lines = section.split('\n')
    name_line = lines[0].replace('**', '').strip()
    
    # Extract python code block
    py_match = re.search(r'```python\n(.*?)\n```', section, re.DOTALL)
    if py_match:
        code = py_match.group(1)
        # We can evaluate the dict and the string since it's simple python
        local_vars = {}
        try:
            exec(code, {}, local_vars)
            gen_inst = local_vars.get('GENERAL_INSTRUCTIONS', '')
            cat_prompts = local_vars.get('CATEGORY_PROMPTS', {})
            
            # build the prompt
            combined = gen_inst + "\n\nKATEGORIE RAPORTU I ICH SZCZEGÓŁOWE WYTYCZNE:\n"
            for k, v in cat_prompts.items():
                combined += f"- {k}:\n  {v}\n"
            
            modalities.append((name_line, combined))
        except Exception as e:
            print(f"Error parsing {name_line}: {e}")

# Map to system_code
sys_codes = {
    'Uniwersalny / Integracyjny': 'UNIV',
    'Poznawczo-Behawioralny (CBT)': 'CBT',
    'Psychodynamiczny': 'PSYCHO',
    'Pozytywny (PPT)': 'PPT',
    'Terapia Schematów (ST)': 'ST',
    'Systemowa (dla par i rodzin)': 'SYS',
    'Skoncentrowana na Emocjach (EFT)': 'EFT',
    'Coaching (ICF/GROW)': 'COACH'
}

with open('/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/superwizor-backend/migrations/000008_modality_prompts_pl.up.sql', 'w') as f:
    f.write("-- Dodanie polskich promptów do tabeli modalities\n\n")
    for name, prompt in modalities:
        code = sys_codes.get(name, "UNKNOWN")
        if code == "UNKNOWN":
            print(f"Unknown code for {name}")
            continue
            
        json_val = json.dumps({"system": prompt})
        
        # update query using ON CONFLICT if we add a unique constraint, but we don't have one on system_code.
        # we can just delete and insert or update.
        # In 000006, it was just INSERT. We can do an UPDATE by system_code if it exists, else INSERT
        escaped_json = json_val.replace("'", "''")
        
        f.write(f"INSERT INTO modalities (system_code, display_name, therapist_ai_general_prompt, is_supported)\n")
        f.write(f"VALUES ('{code}', '{name}', '{escaped_json}', TRUE)\n")
        f.write(f"ON CONFLICT (system_code) DO UPDATE \n")
        f.write(f"SET display_name = EXCLUDED.display_name,\n")
        f.write(f"    therapist_ai_general_prompt = EXCLUDED.therapist_ai_general_prompt;\n\n")

print("Migration generated.")
