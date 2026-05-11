import sys
import re

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    out = ""
    for i, line in enumerate(lines):
        if line == " \n":
            out += " "
        elif line == "\n":
            out += "\n\n"
        else:
            # strip newline
            l = line.rstrip('\n')
            # If line ends with a space, keep the space
            if line.endswith(' \n'):
                l += ' '
            out += l

    # cleanup multiple spaces
    out = re.sub(r' {2,}', ' ', out)
    # cleanup spaces before newlines
    out = re.sub(r' \n', '\n', out)
    # double newlines for sections
    out = re.sub(r'§', r'\n\n§', out)
    out = re.sub(r'(?m)^(\d+\.)', r'\n\n\1', out)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(out)

fix_file('assets/legal/terms.md')
fix_file('assets/legal/privacy_policy.md')
fix_file('assets/legal/dpa.md')
print("Done")
