from PIL import Image

def txt_to_img(txt_file, img_file, width, height):
    with open(txt_file, 'r') as file:
        lines = file.readlines()

    if len(lines) != width * height:
        raise ValueError("The number of lines in the text file does not match the image dimensions")

    img = Image.new('RGB', (width, height))
    pixels = img.load()

    for y in range(height):
        for x in range(width):
            line = lines[y * width + x].strip()
            if len(line) != 4:
                raise ValueError(f"Invalid RGB565 code at line {y * width + x + 1}")

            rgb565 = int(line, 16)
            r = (rgb565 >> 11) & 0x1F
            g = (rgb565 >> 5) & 0x3F
            b = rgb565 & 0x1F

            r = (r << 3) & 0xFF
            g = (g << 2) & 0xFF
            b = (b << 3) & 0xFF

            pixels[x, y] = (r, g, b)

    img.save(img_file)

def remove_first_three_lines(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    with open(file_path, 'w') as file:
        file.writelines(lines[3:])

if __name__ == "__main__":
    txt_file = 'dut_env/dut_output/img_txt.txt'
    img_file = 'output.jpg'
    width = 320  # Set the width of the image
    height = 240  # Set the height of the image

    remove_first_three_lines(txt_file)
    txt_to_img(txt_file, img_file, width, height)
