"""Package the final round-trip rendered frames; no changes to the model."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'build/archer';QA.mkdir(parents=True,exist_ok=True)
try:font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
except OSError:font=ImageFont.load_default()
selected={'run':[0,3,6,9,12,15,18,21],'draw':[0,6,12,18,24,36],'shoot':[0,4,5,7,12,18,24,30]}
for clip,fs in selected.items():
 frames=sorted(QA.glob('motion_'+clip+'_*.png'));assert len(frames)=={'run':24,'draw':37,'shoot':31}[clip]
 sheet=Image.new('RGB',(320*4,432*((len(fs)+3)//4)),(19,26,36));d=ImageDraw.Draw(sheet)
 for i,f in enumerate(fs):
  tile=Image.open(QA/f'motion_{clip}_{f:03}.png').convert('RGB');x=i%4*320;y=i//4*432
  sheet.paste(tile,(x,y+32));d.text((x+12,y+5),f'{clip.upper()}  {f/30:.2f}s',fill=(233,237,241),font=font)
 sheet.save(QA/f'{clip}_contact.png')
 images=[Image.open(p).convert('RGB') for p in frames]
 # A slightly slower review GIF makes finger release and string recoil readable.
 images[0].save(QA/f'{clip}_preview.gif',save_all=True,append_images=images[1:],duration=50,loop=0,disposal=2)
# Three tiled clips play together in the video; one-shots hold on their final frame.
sequence=QA/'video_frames';sequence.mkdir(exist_ok=True)
for f in range(90):
 canvas=Image.new('RGB',(960,448),(19,26,36));d=ImageDraw.Draw(canvas)
 times={'run':f%24,'draw':min(f,36),'shoot':max(0,min(f-36,30))}
 for i,c in enumerate(['run','draw','shoot']):
  canvas.paste(Image.open(QA/f'motion_{c}_{times[c]:03}.png').convert('RGB'),(i*320,48))
  d.text((i*320+12,14),f'{c.upper()}  {times[c]/30:.2f}s',fill=(233,237,241),font=font)
 canvas.save(sequence/f'{f:03}.png')
subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','30','-i',str(sequence/'%03d.png'),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(QA/'animation_preview.mp4')],check=True)
for p in sequence.glob('*.png'):p.unlink()
sequence.rmdir()
print('Packaged final contact sheets, GIFs and MP4.')
