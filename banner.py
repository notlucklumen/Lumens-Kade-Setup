import os
import shutil
import urllib.parse
import urllib.request

API_URL = 'https://asciified.thelicato.io/api/v2/ascii'


def enable_ansi():
    if os.name != 'nt':
        return

    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_uint()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        pass


def get_ascii_art(text):
    params = urllib.parse.urlencode({'text': text, 'font': 'Banner3'})
    request = urllib.request.Request(
        f'{API_URL}?{params}',
        headers={'User-Agent': 'KadeTool/1.0'},
    )

    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            art = response.read().decode('utf-8', errors='replace').strip('\r\n')
            if response.status == 200 and art.strip():
                return art
    except Exception:
        pass

    return text


def rgb(r, g, b):
    return f'\x1b[38;2;{r};{g};{b}m'


def blend(start, end, amount):
    return tuple(round(a + (b - a) * amount) for a, b in zip(start, end))


def print_gradient_art(art, start, end, width):
    lines = art.splitlines() or [art]
    max_width = max((len(line) for line in lines), default=0)
    row_count = max(len(lines), 1)
    left_pad = max(0, (width - max_width) // 2)

    print()
    for row_index, line in enumerate(lines):
        output = [' ' * left_pad]
        line_width = max(len(line), 1)

        for column, char in enumerate(line):
            if char == ' ':
                output.append(' ')
                continue

            amount = ((column / line_width) + (row_index / row_count)) / 2
            red, green, blue = blend(start, end, amount)
            output.append(f'{rgb(red, green, blue)}{char}')

        output.append('\x1b[0m')
        print(''.join(output))

    print()


def main():
    enable_ansi()
    title = os.environ.get('BW', 'MAIN')
    colors = os.environ.get('BC', '200,255,40,170,120,220').split(',')
    try:
        values = [int(value.strip()) for value in colors]
        if len(values) != 6:
            raise ValueError
        start = (values[0], values[2], values[4])
        end = (values[1], values[3], values[5])
    except ValueError:
        start = (200, 40, 120)
        end = (255, 170, 220)

    width = shutil.get_terminal_size((120, 30)).columns
    art = get_ascii_art(title)
    print_gradient_art(art, start, end, width)

    items = os.environ.get('BF', '').split(';')
    items = [item for item in items if item]
    text_width = max((len(item) for item in items), default=0)
    padding = max(0, (width - text_width) // 2)
    bright_color = f'\x1b[1;38;2;{end[0]};{end[1]};{end[2]}m'

    for item in items:
        print(' ' * padding + bright_color + item + '\x1b[0m')
    print()


if __name__ == '__main__':
    main()
