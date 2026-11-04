"""Bounded decoder of uploaded archive model byte streams; no visual fallback."""
from pathlib import Path
import argparse,struct,json,hashlib,collections
from extract_ship_registry import Image,DESCRIPTORS
SIZES={0:2,1:8,2:6,3:8,4:10,7:8,8:10,9:8,10:10,11:4,12:4,13:4,15:2,17:14,18:4,19:4,20:4,21:2,22:10,23:6,25:2,29:4,30:2}
class Unsupported(ValueError):pass
def u16(b,p):
 if p<0 or p+2>len(b):raise ValueError('Read outside bounded model stream')
 return struct.unpack_from('<H',b,p)[0]
def decode(blob):
 pending=[0];result=[];visited=set();occupied={}
 while pending:
  p=pending.pop()
  if p in visited:continue
  if not 0<=p<len(blob) or p%2:raise ValueError("Command offset outside bounded model stream")
  if len(visited)>32768:raise ValueError("Source model instruction budget exceeded")
  visited.add(p)
  w=u16(blob,p);op=w&31
  if op in SIZES:size=SIZES[op]
  elif op==5:
   count=u16(blob,p+4)>>8
   if count<2 or count%2:raise ValueError('Invalid polygon byte span')
   size=6+count
  elif op==6:
   mode=w>>13;size=2
   if mode in [1,3]:
    while True:
     v=u16(blob,p+size);size+=2
     if v>>8!=255:break
   elif mode==7 and w>>5 not in [2046,2047]:size=4
  elif op in [14,27]:
   size=4 if op==14 else 8
   if u16(blob,p+2)&0x8000:size+=4
  elif op==24:
   size=6
   while True:
    v=u16(blob,p+size);size+=2
    if (v>>8)==127 or (v&255)==127:break
  elif op==26:size=20 if blob[p+5] else 6
  elif op==28:size=6 if w&0xc000==0xc000 else 4
  else:raise Unsupported(f'Unsupported opcode {op:#x} at byte {p:#x}')
  if p+size>len(blob):raise ValueError(f'Truncated opcode {op:#x} at byte {p:#x}: size{size} remaining{len(blob)-p}')
  words=list(struct.unpack_from('<'+'H'*(size//2),blob,p));row={'offset':p,'opcode':op,'word':w,'words':words}
  if op in [14,27]:row.update(model_id=w>>5,vertex=words[1]&255,orientation=words[1]>>8,external_anchors=words[-2:] if words[1]&0x8000 else [])
  if op in [11,12,19,20,23]:
   delta=w>>5
   if delta:row['jump_target']=p+size+((delta-2048 if delta>=1024 else delta)*2)
   else:row['jump_exits']=True
  row['next_offset']=p+size
  for byte in range(p,p+size):
   if byte in occupied:raise ValueError('Overlapping source model commands')
   occupied[byte]=p
  result.append(row)
  if op!=0:pending.append(p+size)
  if 'jump_target'in row:pending.append(row['jump_target'])
 return sorted(result,key=lambda row:row['offset'])

def asset(index,data,image):
 DATA=data;IMAGE=image
 at=IMAGE.pointer(DESCRIPTORS+index*4,68);f=struct.unpack_from('<17I',DATA,at)
 mesh=IMAGE.offset(f[0],2)
 bounds=[at]
 for field in [1,3,13,14]:
  if f[field]:
   try:v=IMAGE.offset(f[field],1)
   except ValueError:continue
   if v>mesh:bounds.append(v)
 stop=min(x for x in bounds if x>mesh)
 if not 2<=stop-mesh<=65536:raise ValueError('Unbounded model allocation')
 blob=DATA[mesh:stop]
 vo=IMAGE.offset(f[1],f[2]//2*6)
 if f[2]%2 or not 0<=f[2]<=256:raise ValueError('Invalid pair vertex count')
 vertices=[list(DATA[vo+i*6:vo+(i+1)*6]) for i in range(f[2]//2)]
 result={'index':index,'descriptor_offset':at,'descriptor_sha256':hashlib.sha256(DATA[at:at+68]).hexdigest(),'source_mesh_offset':mesh,'mesh_hex':blob.hex(),'mesh_sha256':hashlib.sha256(blob).hexdigest(),'vertex_hex':bytes(v for row in vertices for v in row).hex(),'vertex_count':f[2],'scale':f[5],'scale2':f[6],'phys_scale':f[5]+f[6],'frustum_radius':f[7],'primitives':f[8],'outer_radius_q8':f[11],'inner_radius_q8':f[12],'default_rgb':list(DATA[at+36:at+39]),'normal_count':f[4]}
 if f[3] and f[4]>2:
  no=IMAGE.offset(f[3],(f[4]//2-1)*6)
  result['normal_records']=[list(DATA[no+i*6:no+(i+1)*6]) for i in range(f[4]//2-1)]
 else:result['normal_records']=[]
 commands=decode(blob)
 try:
  offsets={r['offset'] for r in commands}
  for row in commands:
   if 'jump_target'in row and row['jump_target'] not in offsets:raise ValueError(f'Branch target {row["jump_target"]} is not a command boundary at {row["offset"]}')
  result['commands']=commands
  result['submodels']=sorted(set(r['model_id'] for r in commands if r['opcode'] in [14,27]))
  result['opcodes']=dict(sorted(collections.Counter(r['opcode'] for r in commands).items()))
  result['status']='decoded'
 except ValueError as e:
  result['status']='unsupported';result['error']=str(e)
 return result

def extract(executable,roots=range(72,91)):
 data=Path(executable).read_bytes();image=Image(data)
 roots=list(roots);models={};todo=roots.copy()
 while todo:
  index=todo.pop()
  if index in models:continue
  if not 0<=index<=464:raise ValueError('Source model index outside audited archive table')
  row=asset(index,data,image)
  if row.get('status')!='decoded':raise ValueError(f'Model {index}: '+row.get('error','invalid source stream'))
  models[index]=row;todo.extend(row['submodels'])
 return {'schema':1,'revision':'world-model-assets-v1','source_sha256':hashlib.sha256(data).hexdigest(),
         'roots':roots,'scope':'Original paired vertex/normal records and bounded reachable model command streams for world structures. Geometry/command execution, text and materials are separate capabilities; no full model interpreter claim.',
         'models':{str(k):v for k,v in sorted(models.items())}}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('executable',type=Path);p.add_argument('output',type=Path)
 p.add_argument('--roots',default=','.join(map(str,range(72,91))))
 a=p.parse_args();result=extract(a.executable,[int(v,0)for v in a.roots.split(',')])
 a.output.write_text(json.dumps(result,separators=(',',':'))+'\n')
 print('World model source assets:',len(result['models']),'roots:',len(result['roots']))
if __name__=='__main__':main()
