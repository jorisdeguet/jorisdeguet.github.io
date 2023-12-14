import svgwrite


def add_text_on_path(dwg, text, path_str, font_size):
    path = dwg.path(d=path_str, fill='none', stroke='none')  # Create the path
    path_len = path.length()

    chars = len(text)
    char_offset = path_len / chars  # Evenly space characters along the path

    for i, char in enumerate(text):
        # Calculate position on the path for each character
        char_pos = path.pointAtLength(i * char_offset)

        # Create text element for each character
        dwg.add(dwg.text(
            char,
            insert=(char_pos[0], char_pos[1]),
            font_size=font_size,
            font_family='Arial',
            text_anchor='middle'  # Adjust text alignment as needed
        ))


def create_svg_with_text_on_path(text, path_str, output_filename):
    dwg = svgwrite.Drawing(output_filename, profile='full')

    # Define the path
    dwg.add(dwg.path(d=path_str, fill='none', stroke='black', stroke_width=1))

    # Add text along the path
    add_text_on_path(dwg, text, path_str, font_size=12)

    dwg.save()


# Example usage: create SVG with text along a multi-line path
text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
path_string = "M 50 50 C 150 50, 150 150, 250 150"  # Example cubic bezier curve path

output_file = "text_on_path.svg"
create_svg_with_text_on_path(text, path_string, output_file)
