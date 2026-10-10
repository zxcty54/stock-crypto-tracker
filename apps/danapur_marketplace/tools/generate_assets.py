"""Generate the original vector illustrations and matching launcher icons.
Optional regeneration dependency: pillow.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets' / 'illustrations'
ART.mkdir(parents=True, exist_ok=True)

def svg(body, box='0 0 240 200'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{box}" fill="none">{body}</svg>'

art = {
'rice': '''<ellipse cx="122" cy="181" rx="66" ry="8" fill="#C8D6BB"/><path d="M76 25h87l-7 23 20 112q2 14-14 16H76q-17-2-14-16L82 48Z" fill="#E2BD76"/><path d="M82 48h75M83 31h73" stroke="#B59051" stroke-width="5"/><path d="M85 64h65l9 84H75Z" fill="#FFF8E5"/><circle cx="118" cy="109" r="24" fill="#267148"/><path d="M109 128v-41m0 14 11-9m-11 18 11-9m-11 19 11-8m-11-10-9-8m9 19-9-8" stroke="#EBD99E" stroke-width="3" stroke-linecap="round"/><path d="M88 146h62" stroke="#CBAC72" stroke-width="4"/>''',
'earbuds': '''<ellipse cx="120" cy="174" rx="67" ry="9" fill="#D2D4E8"/><rect x="52" y="104" width="137" height="63" rx="27" fill="#E0E2EF"/><rect x="55" y="108" width="131" height="54" rx="24" fill="#FEFEFF"/><path d="M55 113q64 17 129 0" stroke="#CFD2E3" stroke-width="3"/><circle cx="120" cy="144" r="3" fill="#67A787"/><path d="M79 28q-18-2-18 17 0 17 15 18l-1 40q1 9 10 9t9-9l-1-60q-1-14-14-15Z" fill="#FCFCFE" stroke="#D0D3E1" stroke-width="2"/><ellipse cx="77" cy="45" rx="7" ry="10" fill="#697282"/><path d="M160 28q18-2 18 17 0 17-15 18l1 40q-1 9-10 9t-9-9l1-60q1-14 14-15Z" fill="#FCFCFE" stroke="#D0D3E1" stroke-width="2"/><ellipse cx="162" cy="45" rx="7" ry="10" fill="#697282"/>''',
'shirt': '''<ellipse cx="122" cy="180" rx="68" ry="8" fill="#E8D9D0"/><path d="m80 28 24-10h31l26 10 42 37-28 34-21-17v86H86V81L65 98 37 65Z" fill="#E6C2A8"/><path d="m104 18 16 23 15-23 13 10-17 24-11-11-12 11-17-24Z" fill="#CA9B7B"/><path d="M120 42v125" stroke="#D4AE94" stroke-width="4"/><circle cx="122" cy="65" r="2" fill="#A98168"/><circle cx="122" cy="88" r="2" fill="#A98168"/><circle cx="122" cy="111" r="2" fill="#A98168"/><circle cx="122" cy="134" r="2" fill="#A98168"/><path d="M137 65h20v22h-20Z" fill="#D8AF92"/><path d="m39 68 25 26m111-1 25-27" stroke="#CA9B7B" stroke-width="5"/>''',
'pan': '''<ellipse cx="129" cy="174" rx="81" ry="8" fill="#D1DED9"/><path d="m139 99 71-36q10-5 15 4 6 10-4 16l-72 39Z" fill="#A87C50"/><path d="m145 102 16-8 8 15-16 9" fill="#AEB7AC"/><ellipse cx="97" cy="122" rx="62" ry="39" fill="#303F3A"/><ellipse cx="97" cy="111" rx="62" ry="35" fill="#69796F"/><ellipse cx="97" cy="108" rx="57" ry="29" fill="#3F5148"/><ellipse cx="97" cy="108" rx="45" ry="21" stroke="#84948B" stroke-width="2"/><path d="m211 69-57 31" stroke="#C0986D" stroke-width="4" stroke-linecap="round"/>''',
'oil': '''<ellipse cx="121" cy="180" rx="43" ry="8" fill="#D3DDBD"/><rect x="100" y="18" width="43" height="20" rx="5" fill="#317247"/><path d="M105 38h32v15l18 19v92q0 12-13 12h-42q-13 0-13-12V72l18-19Z" fill="#E7B544"/><path d="M96 73h50v83H96Z" fill="#FBE8AC"/><path d="M99 98h43v42H99Z" fill="#337847"/><path d="M120 131v-25m0 5 8-5m-8 14 8-5m-8 7-8-5" stroke="#EAD887" stroke-width="3" stroke-linecap="round"/><path d="M96 77h50" stroke="#ECD28D" stroke-width="4"/>''',
'watch': '''<ellipse cx="121" cy="184" rx="48" ry="7" fill="#D6D8E7"/><path d="M95 10h50l5 49-9 80-1 43h-40l-1-43-9-80Z" fill="#39554C"/><rect x="78" y="51" width="83" height="96" rx="25" fill="#9BA9A0"/><rect x="84" y="56" width="71" height="84" rx="21" fill="#172F29"/><rect x="159" y="82" width="7" height="18" rx="3" fill="#84978B"/><circle cx="120" cy="98" r="23" stroke="#E9BC5D" stroke-width="5"/><path d="M120 98V80m0 18 13 8" stroke="#F2ECD8" stroke-width="4" stroke-linecap="round"/><path d="M109 155h24m-24 8h24m-24 8h24" stroke="#263F36" stroke-width="3"/>''',
'sweets': '''<ellipse cx="120" cy="178" rx="83" ry="8" fill="#E5D4B3"/><path d="m45 69 133-7 27 45-21 62H47l-17-62Z" fill="#A46C39"/><path d="m45 69 133-7 18 29-157 7Z" fill="#EDC387"/><path d="M43 98h142v48H43Z" fill="#F5D8A3"/><circle cx="64" cy="115" r="15" fill="#D98F3C"/><circle cx="100" cy="116" r="15" fill="#CF7E33"/><circle cx="139" cy="116" r="15" fill="#D98F3C"/><circle cx="65" cy="145" r="14" fill="#E4A247"/><circle cx="102" cy="145" r="14" fill="#D8943A"/><circle cx="140" cy="145" r="14" fill="#E4A247"/><path d="m44 48 127-9 16 24-147 12Z" fill="#236044"/><path d="m57 53 99-7" stroke="#D6B260" stroke-width="4"/><path d="m31 107 15 63h138l21-63" stroke="#C98D50" stroke-width="5"/>''',
'milk': '''<ellipse cx="121" cy="180" rx="43" ry="8" fill="#D0DECC"/><path d="m88 39 22-23h30l17 23v135H88Z" fill="#F4F5E8"/><path d="m88 39 22-23v23m0-23h30l17 23h-47Z" fill="#A8C1AB"/><path d="M110 39h47v135h-47Z" fill="#DFE8D7"/><path d="M88 79h69v68H88Z" fill="#377851"/><path d="M114 121q-12-13 0-31 13 18 0 31Z" fill="#F6F7EF"/><path d="M93 58h56m-56 102h55" stroke="#B1C9B0" stroke-width="4"/>''',
'bag': '''<ellipse cx="120" cy="177" rx="63" ry="9" fill="#C8D9C2"/><path d="M66 62h110l-8 105H76Z" fill="#DAB985"/><path d="M88 74V49q0-26 32-26t32 26v25" stroke="#2B7250" stroke-width="9" stroke-linecap="round"/><path d="M102 96h38v40h-38Z" fill="#F4E5C7"/><path d="M111 116h20m-10-10v20" stroke="#27744E" stroke-width="5" stroke-linecap="round"/><path d="m76 152 88 0" stroke="#BD9663" stroke-width="4"/>''',
'market': '''<ellipse cx="247" cy="270" rx="208" ry="14" fill="#D4DFC8"/><path d="M45 235q-18-46-7-84 30 5 38 34 6-50 39-61 15 43-15 75 29-17 41-12-6 29-44 45Z" fill="#89AE7A"/><path d="M90 262 62 180m-3 24 30 13m-8-8 19-58" stroke="#648A59" stroke-width="4"/><rect x="138" y="94" width="217" height="159" rx="10" fill="#FBF4DF"/><path d="M126 81h241v22H126Z" fill="#30734F"/><path d="m142 47 205 0 20 34H126Z" fill="#397C55"/><path d="m154 48 15 33m27-33 7 33m29-33v33m33-33-6 33m39-33-14 33m36-33-19 33" stroke="#D5E3BF" stroke-width="20"/><path d="M126 103q0 21 20 21t20-21q0 21 20 21t20-21q0 21 20 21t20-21q0 21 20 21t20-21q0 21 20 21t20-21q0 21 20 21t21-21" fill="#30734F"/><rect x="155" y="140" width="106" height="79" rx="5" fill="#D5E4CA"/><path d="M208 141v76m-50-39h100" stroke="#F6F3DD" stroke-width="6"/><rect x="277" y="139" width="57" height="111" rx="5" fill="#397455"/><rect x="284" y="148" width="43" height="63" rx="3" fill="#C0D4B5"/><circle cx="323" cy="224" r="3" fill="#EED58C"/><rect x="128" y="250" width="238" height="12" rx="5" fill="#B4C29F"/><rect x="143" y="223" width="126" height="14" rx="4" fill="#AF8051"/><path d="M152 237v25m108-25v25" stroke="#946640" stroke-width="7"/><path d="M155 202h35v21h-35Z" fill="#E8BF63"/><path d="M194 197h30v26h-30Z" fill="#C69458"/><path d="m169 209-4-26 13-15 15 16-10 25" fill="#69A066"/><circle cx="237" cy="212" r="11" fill="#E9A449"/><circle cx="253" cy="213" r="10" fill="#E0B34F"/><path d="M363 186h49l-5 73h-41Z" fill="#D5B789"/><path d="M375 192v-20q0-17 15-17t15 17v20" stroke="#397754" stroke-width="6"/><path d="M372 226h28" stroke="#ECD9B5" stroke-width="6"/><path d="M391 102q-26-40 0-52 26 12 0 52Z" fill="#DCAE4A"/><circle cx="391" cy="67" r="7" fill="#F8F1D5"/><path d="M111 92h-9m5-5v10m316 126h-9m5-5v10" stroke="#A8BA91" stroke-width="3" stroke-linecap="round"/>''',
}
for name, body in art.items():
    (ART / f'{name}.svg').write_text(svg(body, '0 0 480 300' if name == 'market' else '0 0 240 200'))
brand = svg('''<rect width="512" height="512" rx="114" fill="#19764E"/><path d="M127 174h258v37H127Z" fill="#F4EDD4"/><path d="m146 119 219 0 20 55H127Z" fill="#F4EDD4"/><path d="m180 119 6 55m35-55 2 55m37-55-2 55m36-55-5 55m38-55-10 55" stroke="#19764E" stroke-width="24"/><path d="M144 215v167h224V215" stroke="#F4EDD4" stroke-width="23" stroke-linejoin="round"/><path d="M234 382V270h71v112" stroke="#F4EDD4" stroke-width="19"/><path d="M171 270h36v51h-36Z" fill="#F0B64D"/>''', '0 0 512 512')
(ROOT / 'assets' / 'brand.svg').write_text(brand)
def write_icon(path, size):
    scale = 4
    image = Image.new('RGBA', (512*scale,512*scale))
    draw = ImageDraw.Draw(image)
    def poly(points, fill):
        draw.polygon([(x*scale,y*scale) for x,y in points], fill=fill)
    green, cream = '#19764E', '#F4EDD4'
    draw.rounded_rectangle((0,0,512*scale,512*scale), radius=114*scale, fill=green)
    poly([(146,119),(365,119),(385,174),(127,174)],cream)
    for x, end in [(180,186),(221,223),(260,258),(294,289),(327,317)]:
        draw.line([(x*scale,119*scale),(end*scale,174*scale)],fill=green,width=24*scale)
    draw.rectangle((127*scale,174*scale,385*scale,211*scale),fill=cream)
    poly([(132,215),(156,215),(156,370),(356,370),(356,215),(380,215),(380,394),(132,394)],cream)
    draw.rectangle((224*scale,260*scale,315*scale,382*scale),fill=cream)
    draw.rectangle((243*scale,279*scale,296*scale,370*scale),fill=green)
    draw.rectangle((171*scale,270*scale,207*scale,321*scale),fill='#F0B64D')
    path.parent.mkdir(parents=True,exist_ok=True)
    image.resize((size,size),Image.Resampling.LANCZOS).save(path)

for size in (192, 512):
    for suffix in ('', '-maskable'):
        write_icon(ROOT/'web'/'icons'/f'Icon{suffix}-{size}.png',size)
write_icon(ROOT/'web'/'favicon.png',32)
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    write_icon(ROOT/'android'/'app'/'src'/'main'/'res'/f'mipmap-{density}'/'ic_launcher.png',size)
