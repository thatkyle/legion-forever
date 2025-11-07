import csv

# Read the original CSV
with open('builder_units.csv', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Process the data
output_rows = []
header_row = lines[1].strip()  # Keep the header
output_rows.append(header_row)

i = 2  # Start after header
while i < len(lines):
    line = lines[i].strip()

    # Skip empty lines
    if not line or line == ',,,,,,,,,,,':
        i += 1
        continue

    # Check if this is a unit row (starts with comma followed by a name)
    if line.startswith(',') and not line.startswith(',,'):
        # This is a unit row
        unit_row = line

        # Get the next 3 rows (properties)
        if i + 3 < len(lines):
            attack_type = lines[i + 1].strip().split(',')[0] if i + 1 < len(lines) else ''
            armor_type = lines[i + 2].strip().split(',')[0] if i + 2 < len(lines) else ''
            abilities = lines[i + 3].strip().split(',')[0] if i + 3 < len(lines) else ''

            # Combine into one row
            combined_row = unit_row.rstrip(',') + f',{attack_type},{armor_type},{abilities}'
            output_rows.append(combined_row)

            # Skip the 3 property rows
            i += 4
        else:
            output_rows.append(unit_row)
            i += 1
    else:
        # Handle tier markers and other special rows
        if line and not line.startswith(',,,'):
            output_rows.append(line)
        i += 1

# Write the output
with open('builder_units_fixed.csv', 'w', encoding='utf-8', newline='') as f:
    for row in output_rows:
        f.write(row + '\n')

print("CSV file has been fixed and saved as 'builder_units_fixed.csv'")
